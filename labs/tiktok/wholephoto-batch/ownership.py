"""Best-effort lifecycle observer; cleanup and fail-closed evidence are separate."""
import contextlib,importlib.util,json,math,pathlib,threading,time,uuid
spec=importlib.util.spec_from_file_location('wed_network_trace','/trace_lab/trace.py')
network_trace=importlib.util.module_from_spec(spec);spec.loader.exec_module(network_trace)
TraceSink=network_trace.TraceSink
def remaining(deadline):return max(0,deadline-time.monotonic())
class DiagnosticIncomplete(RuntimeError):pass
class FileOps:
    def open(self,path):return path.open('a')
    def write(self,file,text):return file.write(text)
    def flush(self,file):return file.flush()
    def close(self,file):return file.close()
class Trace(TraceSink):
    current=None
    def __init__(self,path,io=None):
        super().__init__(path,total_cap=256,connection_cap=32)
        self.lock=threading.RLock();self.counts={};self.file=None;self.owned_files=[]
        self.io=io or FileOps();self.attempted=0;self.dropped=0
        self.held={};self.groups_held={};self.connections={};self.operation_counts={};self.operation_open={}
    def _capacity(self,add):
        owners=set(self.counts)|set(self.held)|set(add)
        return (not self.incomplete and len(owners)<=64 and self.count+sum(sum(x.values()) for x in self.held.values())+sum(sum(x.values()) for x in add.values())<=256
                and all(self.counts.get(k,0)+sum(self.held.get(k,{}).values())+sum(add.get(k,{}).values())<=32 for k in owners))
    def attach_connection(self,registry,ctx):
        with self.lock:
            if registry in self.connections:return self.connections[registry]==ctx
            if registry==ctx:return False
            # Existing ctx rows are lifecycle snapshots before TCP starts.
            add={registry:{'close':4},ctx:{'lifecycle':max(0,12-self.counts.get(ctx,0))}}
            if not self._capacity(add):return False
            for cid,fields in add.items():
                target=self.held.setdefault(cid,{})
                for kind,n in fields.items():target[kind]=target.get(kind,0)+n
            self.connections[registry]=ctx;return True
    def group_capacity(self,registry,ctx,size):
        with self.lock:
            count=0
            for groups in range(1,5):
                add={registry:{'socket':2*size*groups,'select':2*groups},ctx:{'tcp':2*size*groups}}
                if self._capacity(add):count=groups
                else:break
            return count
    def admit_group(self,registry,ctx,size):
        with self.lock:
            if registry in self.groups_held:return False
            add={registry:{'socket':2*size,'select':2},ctx:{'tcp':2*size}}
            if not self._capacity(add):return False
            for cid,fields in add.items():
                target=self.held.setdefault(cid,{})
                for kind,n in fields.items():target[kind]=target.get(kind,0)+n
            self.groups_held[registry]=ctx;return True
    def release_group(self,registry,ctx):
        with self.lock:
            # Caller only releases after library tasks reaped/losers physically closed.
            for cid,kinds in ((registry,('socket','select')),(ctx,('tcp',))):
                for kind in kinds:self.held.get(cid,{}).pop(kind,None)
            self.groups_held.pop(registry,None)
    @property
    def rows(self):return self.count
    def mark_incomplete(self):
        with self.lock:self.incomplete=True;self.dropped=min(65535,self.dropped+1)
    def emit(self,cid,phase,event,elapsed=0,code='OK',**numbers):
        with self.lock:
            self.attempted=min(65535,self.attempted+1)
            try:
                valid=(event in ('BEGIN','END','ERROR') and phase.isupper() and code.isupper()
                       and type(elapsed) in (int,float) and math.isfinite(elapsed) and elapsed>=0
                       and all(type(v) in (bool,int,float) and (type(v)==bool or math.isfinite(v)) for v in numbers.values()))
                if not valid or self.incomplete or self.count>=self.total_cap or self.counts.get(cid,0)>=self.connection_cap or cid not in self.counts and len(self.counts)>=64:
                    self.mark_incomplete();return False
                from operation_coverage import PAIRED,SNAPSHOTS
                operation=None
                if phase in PAIRED:
                    tcp=phase in ('TCP_CONNECT','FIXTURE_TCP')
                    index=numbers.get('index') if tcp else None
                    if tcp and (type(index) is not int or not 1<=index<=64):self.mark_incomplete();return False
                    key=(cid,phase,index) if tcp else (cid,phase)
                    if event=='BEGIN':
                        if key in self.operation_open:self.mark_incomplete();return False
                        operation=index if tcp else self.operation_counts.get(key,0)+1
                        self.operation_counts[key]=operation;self.operation_open[key]=operation
                    else:
                        operation=self.operation_open.pop(key,None)
                        if operation is None:self.mark_incomplete();return False
                elif phase not in SNAPSHOTS or event!='END':self.mark_incomplete();return False
                kind='socket' if phase=='SOCKET_CREATE' else 'select' if phase=='LIBRARY_SELECT' else 'tcp' if phase in ('TCP_CONNECT','FIXTURE_TCP') else 'close' if phase=='REGISTRY_CLOSE' else 'lifecycle'
                reserved=self.held.get(cid,{}).get(kind,0)
                if reserved:self.held[cid][kind]-=1
                elif self.count+sum(sum(x.values()) for x in self.held.values())>=256 or self.counts.get(cid,0)+sum(self.held.get(cid,{}).values())>=32:
                    self.mark_incomplete();return False
                row={'ownerID':cid,'phase':phase,'event':event,'code':code,'elapsed':elapsed,**numbers}
                if operation is not None:row['operationIndex']=operation
                if self.file is None:self.file=self.io.open(self.path);self.owned_files.append(self.file)
                self.io.write(self.file,json.dumps(row)+'\n');self.io.flush(self.file)
                self.count+=1;self.counts[cid]=self.counts.get(cid,0)+1;return True
            except Exception:self.mark_incomplete();return False
    def observe(self,*a,**k):
        try:return self.emit(*a,**k)
        except BaseException:self.mark_incomplete();return False
    @contextlib.contextmanager
    def phase(self,cid,phase,**numbers):
        started=time.monotonic();self.observe(cid,phase,'BEGIN',code='BEGIN',**numbers)
        try:yield
        except BaseException:self.observe(cid,phase,'ERROR',time.monotonic()-started,code='ERROR');raise
        else:self.observe(cid,phase,'END',time.monotonic()-started,**numbers)
    def summary(self):return {'rows':self.count,'totalCap':256,'connectionCap':32,'owners':len(self.counts),'incomplete':self.incomplete,'attempted':self.attempted,'dropped':self.dropped,'reservedRows':sum(sum(x.values()) for x in self.held.values()),'pendingGroups':len(self.groups_held),'openOperations':len(self.operation_open)}
    def close(self):
        with self.lock:
            if self.groups_held or self.operation_open:self.mark_incomplete()
            self.held.clear()
            if self.file is not None:
                try:self.io.close(self.file)
                except BaseException:self.mark_incomplete()
            for file in self.owned_files:
                try:file.close()
                except BaseException:self.mark_incomplete()
def delegate_cleanup(delegate,cleanup,secondary):
    primary=False
    try:return delegate()
    except BaseException:primary=True;raise
    finally:
        try:cleanup()
        except BaseException as error:
            if not primary:raise
            secondary(error)
class Requests:
    def __init__(self,trace,deadline):
        self.trace=trace;self.deadline=deadline;self.condition=threading.Condition()
        self.items={};self.ids={};self.errors=0;self.rejected=0;self.error_objects={}
    def error(self,cid,error):
        with self.condition:
            self.errors=min(65535,self.errors+1)
            if cid is not None and cid not in self.error_objects:self.error_objects[cid]=error # RAM only; never serialized.
    def accept(self,request):
        with self.condition:
            if len(self.items)>=64:
                self.rejected=min(65535,self.rejected+1);self.trace.mark_incomplete();request.close();raise RuntimeError('REQUEST_CAP')
            cid=uuid.uuid4().hex[:16];self.ids[request]=cid
            self.items[cid]={'socket':request,'closed':False,'returned':False,'thread':None,'finished':False,'shutdown':False,'dispatch':'REGISTERED','started':False}
        self.trace.observe(cid,'REQUEST_ACCEPT','END',socketOpen=request.fileno()!=-1)
    def cid(self,request):return self.ids[request]
    def closed(self,request):
        with self.condition:self.items[self.cid(request)]['closed']=request.fileno()==-1;self.condition.notify_all()
    def abort(self,request,error):
        cid=self.ids.get(request);self.error(cid,error)
        if cid is None:request.close();return
        with self.condition:
            item=self.items[cid]
            if item['started']:return
            item['dispatch']='ABORTED';self.condition.notify_all()
        try:request.close()
        finally:self.closed(request)
        self.trace.observe(cid,'REQUEST_ABORT','END',aborted=True,workerStarted=False,socketClosed=request.fileno()==-1)
    def snapshot(self):
        with self.condition:return {'accepted':len(self.items),'closed':sum(v['closed'] for v in self.items.values()),'workersReturned':sum(v['returned'] for v in self.items.values()),'requestSocketsLeft':sum(v['socket'].fileno()!=-1 for v in self.items.values()),'workerThreadsLeft':sum(v['thread'] is not None and v['thread'].is_alive() for v in self.items.values()),'errors':self.errors,'dispatchAborted':sum(v['dispatch']=='ABORTED' for v in self.items.values()),'workersStarted':sum(v['started'] for v in self.items.values()),'rejected':self.rejected}
    def wait_cleanup(self):
        cid=uuid.uuid4().hex[:16];before=self.snapshot();start=time.monotonic();self.trace.observe(cid,'CLOSURE_BARRIER','BEGIN',code='BEGIN',**before)
        try:
            budgetBefore=remaining(self.deadline)
            if budgetBefore<=0:raise TimeoutError('CLOSURE_DEADLINE')
            with self.condition:
                complete=self.condition.wait_for(lambda:all(v['closed'] and (v['returned'] or v['dispatch']=='ABORTED') for v in self.items.values()),remaining(self.deadline))
                workers=[v['thread'] for v in self.items.values() if v['thread'] and v['started']]
            if not complete:raise TimeoutError('CLOSURE_DEADLINE')
            for worker in workers:worker.join(remaining(self.deadline))
            result=self.snapshot()
            if result['requestSocketsLeft'] or result['workerThreadsLeft']:raise RuntimeError('CLOSURE_FAILED')
            budgetAfter=remaining(self.deadline)
            if budgetAfter<=0:raise TimeoutError('CLOSURE_DEADLINE')
            self.trace.observe(cid,'CLOSURE_BARRIER','END',time.monotonic()-start,**result)
            return {'before':before,'after':result,'elapsed':time.monotonic()-start,'remainingBefore':budgetBefore,'remainingAfter':budgetAfter}
        except BaseException:self.trace.observe(cid,'CLOSURE_BARRIER','ERROR',time.monotonic()-start,code='ERROR');raise
    def wait(self):
        result=self.wait_cleanup()
        if self.trace.incomplete:raise DiagnosticIncomplete('TRACE_INCOMPLETE')
        if self.errors:raise RuntimeError('DELEGATE_FAILED')
        return result
def server_class(base,owners,finish_gate=None,accept_callback=None,worker_factory=None):
    class OwnedServer(base):
        def get_request(self):
            request,address=super().get_request()
            try:
                owners.accept(request)
                if accept_callback:accept_callback(request)
            except BaseException as error:
                try:owners.abort(request,error)
                except BaseException as secondary:owners.error(owners.ids.get(request),secondary)
                raise
            return request,address
        def process_request(self,request,address):
            cid=owners.cid(request)
            try:
                worker=(worker_factory or threading.Thread)(target=self.owned_dispatch,args=(request,address),daemon=self.daemon_threads)
                with owners.condition:owners.items[cid]['thread']=worker
                worker.start()
            except BaseException as error:
                try:owners.abort(request,error)
                except BaseException as secondary:owners.error(cid,secondary)
                raise
        def owned_dispatch(self,request,address):
            cid=owners.cid(request)
            with owners.condition:owners.items[cid]['started']=True;owners.items[cid]['dispatch']='STARTED'
            try:self.finish_request(request,address)
            except BaseException as error:owners.error(cid,error);owners.trace.observe(cid,'REQUEST_FINISH','ERROR',code='HANDLER_ERROR')
            finally:
                try:self.shutdown_request(request)
                except BaseException as error:owners.error(cid,error)
                finally:
                    with owners.condition:owners.items[cid]['returned']=True;owners.items[cid]['dispatch']='RETURNED';owners.condition.notify_all()
                    owners.trace.observe(cid,'WORKER_RETURN','END',workerStarted=True,workerReturned=True)
        def finish_request(self,request,address):
            cid=owners.cid(request)
            with owners.trace.phase(cid,'REQUEST_FINISH'):
                super().finish_request(request,address)
                if finish_gate is not None and not finish_gate.wait(remaining(owners.deadline)):raise TimeoutError('FINISH_GATE_DEADLINE')
                with owners.condition:owners.items[cid]['finished']=True
        def shutdown_request(self,request):
            cid=owners.cid(request)
            def action():
                with owners.trace.phase(cid,'REQUEST_SHUTDOWN'):super(OwnedServer,self).shutdown_request(request)
            def cleanup():
                try:
                    if request.fileno()!=-1:self.close_request(request)
                finally:
                    owners.closed(request)
                    with owners.condition:owners.items[cid]['shutdown']=request.fileno()==-1
            return delegate_cleanup(action,cleanup,lambda error:owners.error(cid,error))
        def close_request(self,request):
            cid=owners.cid(request)
            def action():
                with owners.trace.phase(cid,'REQUEST_CLOSE'):super(OwnedServer,self).close_request(request)
            def cleanup():
                try:
                    if request.fileno()!=-1:request.close()
                finally:owners.closed(request)
            return delegate_cleanup(action,cleanup,lambda error:owners.error(cid,error))
        def handle_error(self,request,*a):owners.error(owners.ids.get(request),RuntimeError('HANDLER_FAILED'))
    return OwnedServer
def stop_server(server,serve_thread,trace,deadline):
    cid=uuid.uuid4().hex[:16]
    def action():
        with trace.phase(cid,'SERVER_SERVE_CLOSE'):server.shutdown()
    def cleanup():
        try:server.server_close()
        finally:serve_thread.join(remaining(deadline))
    delegate_cleanup(action,cleanup,lambda error:trace.mark_incomplete())
    if serve_thread.is_alive() or server.socket.fileno()!=-1:raise RuntimeError('SERVER_CLOSE_FAILED')
    return {'serveThreadAlive':serve_thread.is_alive(),'listenerClosed':server.socket.fileno()==-1}
