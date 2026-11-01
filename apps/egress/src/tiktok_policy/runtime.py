"""Request-scoped WED SNAP admission/ownership glue. No HTTP/TLS implementation."""
import asyncio,collections,contextlib,errno,hashlib,json,os,pathlib,socket,threading,time,uuid
from .candidate import Sockets,connect
from .dns_ipc import resolve
from .dns_diagnostic import validate_receipt
from .ownership import Trace,DiagnosticIncomplete
from .batch_validation import validate

DOMAINS=('tiktok.com','tiktokcdn.com','tiktokv.com','byteoversea.com','ibytedtos.com')
SETUPS=threading.BoundedSemaphore(1)
def enabled(host):return os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1' and any(host==d or host.endswith('.'+d) for d in DOMAINS)

def _tcp_failure_code(error):
    # Public exception/errno only: never stringify a socket exception/address.
    if isinstance(error,asyncio.CancelledError):return 'CANCELLED'
    if isinstance(error,TimeoutError):return 'TIMEOUT'
    if isinstance(error,OSError):
        return {errno.ENETUNREACH:'OS_ENETUNREACH',errno.EHOSTUNREACH:'OS_EHOSTUNREACH',
          errno.ECONNREFUSED:'OS_ECONNREFUSED',errno.ETIMEDOUT:'OS_ETIMEDOUT',
          errno.EACCES:'OS_EACCES',errno.ECONNRESET:'OS_ECONNRESET',
          errno.EADDRNOTAVAIL:'OS_EADDRNOTAVAIL'}.get(error.errno,'OS_OTHER')
    return 'OTHER_ERROR'

class ObservedLoop(asyncio.SelectorEventLoop):
    def __init__(self,ctx):
        super().__init__();self.ctx=ctx;self.calls=0
        self.set_exception_handler(lambda *_:ctx.trace.mark_incomplete())
    async def sock_connect(self,sock,address):
        ctx=self.ctx;self.calls+=1;index=self.calls;start=time.monotonic();group=ctx.registry.group_index
        ctx.registry.worker_tasks.add(asyncio.current_task())
        ctx.trace.observe(ctx.cid,'TCP_CONNECT','BEGIN',code='BEGIN',index=index,groupIndex=group)
        try:
            result=await super().sock_connect(sock,address)
            ctx.trace.observe(ctx.cid,'TCP_CONNECT','END',time.monotonic()-start,index=index,groupIndex=group);return result
        except BaseException as exc:
            ctx.trace.observe(ctx.cid,'TCP_CONNECT','ERROR',time.monotonic()-start,code=_tcp_failure_code(exc),index=index,groupIndex=group);raise

def verify_vendor():
    import aiohappyeyeballs
    if aiohappyeyeballs.__version__!='2.7.1':raise DiagnosticIncomplete('DEPENDENCY_VERSION')
    root=pathlib.Path(aiohappyeyeballs.__file__).resolve().parent.parent
    pins=json.loads((root/'PINNED_HASHES.json').read_text())
    if len(pins)!=10:raise DiagnosticIncomplete('DEPENDENCY_HASH')
    for row in pins:
        if hashlib.sha256((root/row['path']).read_bytes()).hexdigest()!=row['sha256']:raise DiagnosticIncomplete('DEPENDENCY_HASH')

class Request:
    def __init__(self,client,trace=None):
        self.cid=uuid.uuid4().hex[:16];self.trace=trace or Trace();self.client=client
        self.end=None;self.registry=Sockets(self.trace,self.cid);self.cancel=threading.Event()
        self.dns={};self.winner=None;self.tunnel=False;self.failed=False;self.loop_closed=False
        self.trace.observe(self.cid,'REQUEST_ACCEPT','END',socketOpen=client.fileno()!=-1)
        self.trace.observe(self.cid,'REQUEST_FINISH','BEGIN',code='BEGIN')
    def observe_failure(self,stage,direction,error):
        # Failure-only, bounded observation; never stringify an exception/address.
        try:
            if stage not in ('SETUP','HANDOFF','RELAY_READ','RELAY_WRITE','FINISH'):return
            if direction not in ('CLIENT','UPSTREAM','UNKNOWN'):return
            code=('RESET' if isinstance(error,ConnectionResetError) or isinstance(error,OSError) and error.errno==errno.ECONNRESET else
                  'BROKEN_PIPE' if isinstance(error,BrokenPipeError) or isinstance(error,OSError) and error.errno==errno.EPIPE else
                  'TIMEOUT' if isinstance(error,TimeoutError) else 'OTHER')
            print(json.dumps(dict(event='egress_request_failed',stage=stage,direction=direction,
                exceptionCode=code,tunneled=bool(self.tunnel)),separators=(',',':')),flush=True)
        except Exception:pass
    def require_evidence(self):
        if self.trace.incomplete:raise DiagnosticIncomplete('TRACE_INCOMPLETE')
    def connect(self,host):
        # One setup deadline includes vendor, admission wait, DNS and all groups.
        self.end=time.monotonic()+10
        verify_vendor();self.require_evidence()
        if not SETUPS.acquire(timeout=max(0,self.end-1-time.monotonic())):raise TimeoutError('SETUP_DEADLINE')
        loop=None
        try:
            loop=ObservedLoop(self)
            async def setup():
                guarded=await resolve(host,self.end-1,self.dns,trace=self.trace,
                    blocked=({'dev':os.fstat(self.client.fileno()).st_dev,'ino':os.fstat(self.client.fileno()).st_ino,'mode':os.fstat(self.client.fileno()).st_mode},))
                self.trace.observe(self.cid,'DNS_RESULT','END',answers=len(guarded),childReaped=self.dns.get('dnsChildReaped',False),ipv4=sum(a[0]==2 for a in guarded),ipv6=sum(a[0]==10 for a in guarded))
                self.require_evidence()
                return await connect(guarded,self.end-1,self.registry,loop=loop)
            async def supervised():
                task=asyncio.create_task(setup())
                while not task.done():
                    if self.cancel.is_set() or time.monotonic()>=self.end-1:
                        task.cancel()
                        try:await task
                        except BaseException:pass
                        raise TimeoutError('SETUP_DEADLINE')
                    await asyncio.wait({task},timeout=min(.01,max(0,self.end-1-time.monotonic())))
                return task.result()
            self.winner=loop.run_until_complete(supervised())
            if self.registry.pending or self.registry.reap_failed or asyncio.all_tasks(loop):raise DiagnosticIncomplete('TASKS_LEFT')
            self.require_evidence()
            if not validate_receipt(self.dns,self.trace.file.rows)['accepted']:raise DiagnosticIncomplete('DNS_RECEIPT')
            if time.monotonic()>=self.end-1:raise TimeoutError('SETUP_DEADLINE')
            self.winner.settimeout(10)
            return self.winner
        except BaseException:
            self.failed=True
            try:self.registry.close()
            finally:
                if self.winner:self.winner.close()
            raise
        finally:
            try:
                if loop:
                    for task in asyncio.all_tasks(loop):task.cancel()
                    if asyncio.all_tasks(loop):loop.run_until_complete(asyncio.gather(*asyncio.all_tasks(loop),return_exceptions=True))
                    loop.close();self.loop_closed=loop.is_closed()
            finally:SETUPS.release()
    def before_handoff(self):
        self.require_evidence()
        if self.failed or not self.loop_closed or self.registry.pending or self.registry.live()!=1 or time.monotonic()>=self.end:raise DiagnosticIncomplete('HANDOFF_DENIED')
        self.trace.observe(self.cid,'CONNECT_200','BEGIN',code='BEGIN');self.require_evidence()
    def after_handoff(self):
        self.trace.observe(self.cid,'CONNECT_200','END');self.tunnel=True;self.require_evidence()
    def finish(self):
        error=None
        try:self.registry.close()
        except BaseException as exc:
            error=exc;self.failed=True;self.observe_failure('FINISH','UNKNOWN',exc)
        finally:
            if self.winner:
                try:self.winner.close()
                except BaseException as exc:
                    self.observe_failure('FINISH','UPSTREAM',exc);raise
            self.trace.observe(self.cid,'TUNNEL_CLOSE','END',setupFinished=self.tunnel)
            self.trace.observe(self.cid,'REQUEST_FINISH','ERROR' if self.failed else 'END',code='ERROR' if self.failed else 'OK')
        if error is not None:self.trace.mark_incomplete()
    def phase(self,name,event):self.trace.observe(self.cid,name,event,code='BEGIN' if event=='BEGIN' else 'OK')
    def complete(self,worker_closed):
        self.trace.observe(self.cid,'WORKER_RETURN','END',workerStarted=True,workerReturned=True)
        self.trace.observe(self.cid,'CLOSURE_BARRIER','BEGIN',code='BEGIN',workerThreadsLeft=0 if worker_closed else 1)
        self.trace.observe(self.cid,'CLOSURE_BARRIER','END',workerThreadsLeft=0 if worker_closed else 1,requestSocketsLeft=int(self.client.fileno()!=-1))
        r=self.registry
        receipt=dict(version=2,ownerID=self.cid,registryOwnerID=r.cid,dns=self.dns,setupFinished=self.tunnel,socketsLeft=r.live(),socketPeak=r.maxLive,hostnameMode='STDLIB_HOSTNAME',
          batch=dict(code=r.stop_code,groups=r.groups,groupRecords=r.records,pending=len(r.pending),reapFailed=r.reap_failed,lateDenied=r.late_denied,suffixUnknown=r.suffix_unknown,epochActive=r.epoch_active))
        self.trace.close()
        rows=self.trace.file.rows if self.trace.file else []
        result=validate([receipt],rows)
        accepted=result['accepted'] and not self.trace.incomplete and not self.failed and self.loop_closed and worker_closed and self.client.fileno()==-1 and validate_receipt(self.dns,rows)['accepted']
        return dict(accepted=bool(accepted),ownerID=self.cid,receipt=receipt,trace=rows,traceIncomplete=self.trace.incomplete,validation=result,clientClosed=self.client.fileno()==-1,loopClosed=self.loop_closed,workerThreadClosed=worker_closed)

def server_class(base):
    """Bound active handlers when opted in; no retained lifetime request quota."""
    class OwnedServer(base):
        def __init__(self,*args,**kwargs):
            from .control import Broker
            self.phase_broker=Broker()
            self.policy_on=os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1'
            self.policy_lock=threading.RLock();self.policy_contexts={};self.policy_clients=set();self.policy_slots=threading.BoundedSemaphore(8)
            self.completed=collections.deque(maxlen=16);self.policy_pending=[]
            if self.policy_on:self.daemon_threads=False
            super().__init__(*args,**kwargs)
        def register_policy(self,client,auth=None):
            ctx=Request(client)
            ctx._worker_thread=threading.current_thread()
            with self.policy_lock:self.policy_contexts[client]=ctx
            try:self.phase_broker.attach(auth,ctx)
            except BaseException:ctx.failed=True;ctx.finish();raise
            return ctx
        def process_request(self,request,address):
            if not self.policy_on:return super().process_request(request,address)
            with self.policy_lock:
                if len(self.policy_pending)>=8:request.close();return
            if not self.policy_slots.acquire(blocking=False):request.close();return
            with self.policy_lock:self.policy_clients.add(request)
            try:return super().process_request(request,address)
            except BaseException:
                request.close()
                with self.policy_lock:self.policy_clients.discard(request)
                self.policy_slots.release();raise
        def process_request_thread(self,request,address):
            try:return super().process_request_thread(request,address)
            finally:
                with self.policy_lock:ctx=self.policy_contexts.pop(request,None);owned=request in self.policy_clients;self.policy_clients.discard(request)
                try:
                    if ctx:
                        # The current worker cannot prove its own return. Retain
                        # ownership until the serve thread joins this exact object.
                        with self.policy_lock:self.policy_pending.append((ctx,threading.current_thread()))
                finally:
                    if owned:self.policy_slots.release()
        def harvest_policy(self):
            with self.policy_lock:
                done=[];pending=[]
                for ctx,worker in self.policy_pending:
                    (pending if worker.is_alive() else done).append((ctx,worker))
                self.policy_pending=pending
            for ctx,worker in done:
                worker.join(0)
                try:result=ctx.complete(not worker.is_alive())
                except BaseException:result=dict(accepted=False,ownerID=ctx.cid,traceIncomplete=True,workerThreadClosed=not worker.is_alive())
                self.phase_broker.finish(ctx,result)
                with self.policy_lock:self.completed.append(result)
        def service_actions(self):
            super().service_actions();self.harvest_policy();self.phase_broker.tick()
        def shutdown_request(self,request):
            ctx=self.policy_contexts.get(request)
            if ctx:ctx.phase('REQUEST_SHUTDOWN','BEGIN')
            try:return super().shutdown_request(request)
            finally:
                if request.fileno()!=-1:request.close()
                if ctx:ctx.phase('REQUEST_SHUTDOWN','END')
        def close_request(self,request):
            ctx=self.policy_contexts.get(request)
            if ctx:ctx.phase('REQUEST_CLOSE','BEGIN')
            try:return super().close_request(request)
            finally:
                if request.fileno()!=-1:request.close()
                if ctx:ctx.phase('REQUEST_CLOSE','END')
        def server_close(self):
            with self.policy_lock:clients=list(self.policy_clients);contexts=list(self.policy_contexts.values())
            for ctx in contexts:ctx.cancel.set()
            for client in clients:
                try:client.shutdown(socket.SHUT_RDWR)
                except OSError:pass
            result=super().server_close();self.harvest_policy();return result
    return OwnedServer
