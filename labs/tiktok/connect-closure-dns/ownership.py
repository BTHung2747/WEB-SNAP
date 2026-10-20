"""Public socketserver lifecycle extensions; bounded numeric receipts only."""
import contextlib,json,pathlib,threading,time,uuid

def remaining(deadline):return max(0,deadline-time.monotonic())

class Trace:
    current=None
    def __init__(self,path):
        self.path=pathlib.Path(path);self.lock=threading.Lock();self.rows=0;self.counts={};self.incomplete=False;self.file=None
    def emit(self,cid,phase,event,elapsed=0,code='OK',**numbers):
        assert event in ('BEGIN','END','ERROR') and phase.isupper() and code.isupper()
        assert all(isinstance(v,(bool,int,float)) for v in numbers.values())
        with self.lock:
            if self.rows>=256 or self.counts.get(cid,0)>=32 or cid not in self.counts and len(self.counts)>=64:
                self.incomplete=True;raise RuntimeError('TRACE_CAP')
            row={'ownerID':cid,'phase':phase,'event':event,'code':code,'elapsed':elapsed,**numbers}
            try:
                if self.file is None:self.file=self.path.open('a')
                self.file.write(json.dumps(row)+'\n');self.file.flush()  # retain failing trace before watchdog, no arbitrary batching.
            except OSError:self.incomplete=True;raise
            self.rows+=1;self.counts[cid]=self.counts.get(cid,0)+1
    @contextlib.contextmanager
    def phase(self,cid,phase,**numbers):
        started=time.monotonic();self.emit(cid,phase,'BEGIN',code='BEGIN',**numbers)
        try:yield
        except BaseException:
            self.emit(cid,phase,'ERROR',time.monotonic()-started,code='ERROR');raise
        else:self.emit(cid,phase,'END',time.monotonic()-started,**numbers)
    def summary(self):return {'rows':self.rows,'totalCap':256,'connectionCap':32,'owners':len(self.counts),'incomplete':self.incomplete}
    def close(self):
        with self.lock:
            if self.file:self.file.close()

class Requests:
    def __init__(self,trace,deadline):
        self.trace=trace;self.deadline=deadline;self.condition=threading.Condition();self.items={};self.ids={};self.errors=0
    def accept(self,request):
        with self.condition:
            if len(self.items)>=64:request.close();raise RuntimeError('REQUEST_CAP')
            cid=uuid.uuid4().hex[:16];self.ids[request]=cid
            self.items[cid]={'socket':request,'closed':False,'returned':False,'thread':None,'finished':False,'shutdown':False}
        self.trace.emit(cid,'REQUEST_ACCEPT','END',socketOpen=request.fileno()!=-1)
    def cid(self,request):return self.ids[request]
    def closed(self,request):
        with self.condition:
            self.items[self.cid(request)]['closed']=request.fileno()==-1;self.condition.notify_all()
    def snapshot(self):
        with self.condition:
            return {'accepted':len(self.items),'closed':sum(v['closed'] for v in self.items.values()),
              'workersReturned':sum(v['returned'] for v in self.items.values()),
              'requestSocketsLeft':sum(v['socket'].fileno()!=-1 for v in self.items.values()),
              'workerThreadsLeft':sum(v['thread'] is not None and v['thread'].is_alive() for v in self.items.values()),'errors':self.errors}
    def wait(self):
        cid=uuid.uuid4().hex[:16];before=self.snapshot();start=time.monotonic()
        self.trace.emit(cid,'CLOSURE_BARRIER','BEGIN',code='BEGIN',**before)
        try:
            budgetBefore=remaining(self.deadline)
            if budgetBefore<=0:raise TimeoutError('CLOSURE_DEADLINE')
            with self.condition:
                complete=self.condition.wait_for(lambda:all(v['closed'] and v['returned'] for v in self.items.values()),remaining(self.deadline))
                workers=[v['thread'] for v in self.items.values() if v['thread']]
            if not complete:raise TimeoutError('CLOSURE_DEADLINE')
            for worker in workers:worker.join(remaining(self.deadline))
            result=self.snapshot()
            if result['requestSocketsLeft'] or result['workerThreadsLeft'] or result['errors']:raise RuntimeError('CLOSURE_FAILED')
            budgetAfter=remaining(self.deadline)
            if budgetAfter<=0:raise TimeoutError('CLOSURE_DEADLINE')
            self.trace.emit(cid,'CLOSURE_BARRIER','END',time.monotonic()-start,**result)
            return {'before':before,'after':result,'elapsed':time.monotonic()-start,'remainingBefore':budgetBefore,'remainingAfter':budgetAfter}
        except BaseException:
            self.trace.emit(cid,'CLOSURE_BARRIER','ERROR',time.monotonic()-start,code='ERROR');raise

def server_class(base,owners,finish_gate=None):
    class OwnedServer(base):
        def get_request(self):
            request,address=super().get_request();owners.accept(request);return request,address
        def process_request(self,request,address):
            # Public extension point: same daemon dispatch policy; no private _threads.
            cid=owners.cid(request)
            worker=threading.Thread(target=self.owned_dispatch,args=(request,address),daemon=self.daemon_threads)
            with owners.condition:owners.items[cid]['thread']=worker
            worker.start()
        def owned_dispatch(self,request,address):
            cid=owners.cid(request)
            try:self.finish_request(request,address)
            except BaseException:
                with owners.condition:owners.errors+=1
                owners.trace.emit(cid,'REQUEST_FINISH','ERROR',code='HANDLER_ERROR')
            finally:
                try:self.shutdown_request(request)
                finally:
                    with owners.condition:
                        owners.items[cid]['returned']=True;owners.condition.notify_all()
        def finish_request(self,request,address):
            cid=owners.cid(request)
            with owners.trace.phase(cid,'REQUEST_FINISH'):
                super().finish_request(request,address)
                # Controlled fixture delay: hold AFTER handle+finish, BEFORE socket close.
                if finish_gate is not None and not finish_gate.wait(remaining(owners.deadline)):
                    raise TimeoutError('FINISH_GATE_DEADLINE')
                with owners.condition:owners.items[cid]['finished']=True
        def shutdown_request(self,request):
            cid=owners.cid(request)
            with owners.trace.phase(cid,'REQUEST_SHUTDOWN'):
                super().shutdown_request(request)
                with owners.condition:owners.items[cid]['shutdown']=True
        def close_request(self,request):
            cid=owners.cid(request)
            with owners.trace.phase(cid,'REQUEST_CLOSE'):
                super().close_request(request)
                owners.closed(request)
                if request.fileno()!=-1:raise RuntimeError('REQUEST_FD_NOT_CLOSED')
        def handle_error(self,*a):
            # No socketserver default traceback/message output.
            with owners.condition:owners.errors+=1
    return OwnedServer

def stop_server(server,serve_thread,trace,deadline):
    cid=uuid.uuid4().hex[:16]
    with trace.phase(cid,'SERVER_SERVE_CLOSE'):
        server.shutdown();server.server_close();serve_thread.join(remaining(deadline))
        if serve_thread.is_alive() or server.socket.fileno()!=-1:raise RuntimeError('SERVER_CLOSE_FAILED')
    return {'serveThreadAlive':serve_thread.is_alive(),'listenerClosed':server.socket.fileno()==-1}
