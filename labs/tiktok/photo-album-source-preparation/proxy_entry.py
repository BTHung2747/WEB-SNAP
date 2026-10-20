from tcp_observer import next_index,coverage
"""Stage-gated successor. Original CONNECT parser/tunnel; public connector/helper only."""
import asyncio,importlib.util,json,os,pathlib,resource,signal,socket,sys,threading,time,uuid
sys.path[:0]=['/integration','/vendor','/stock']
from common import inventory,versions,stage_policy,isolation,trust_hash
stage_policy() # Bind authority before fixture/source branch or CONNECT capability.
from ownership import Trace,Requests,FileOps,server_class,stop_server
from candidate import Sockets,connect
from dns_ipc import resolve
OUT=pathlib.Path('/out');CONTROL=pathlib.Path('/control/control.json')
sys.excepthook=lambda *a:print('WHOLEPHOTO_PROXY_FAIL',flush=True)
CONTEXT=threading.local();LIMIT=threading.BoundedSemaphore(1);ACTIVE=0;ACTIVE_LOCK=threading.Lock();MAX_HELPERS=0
def control():return json.loads(CONTROL.read_text())
def contain_helpers():
    targets=[];path=OUT/'proxy-trace-helper-owners.jsonl'
    if path.exists():
        for line in path.read_text().splitlines():
            row=json.loads(line);pid=row['helperPID']
            try:
                stat=pathlib.Path('/proc',str(pid),'stat').read_text().split(')',1)[1].split()
                if row['parentPID']==os.getpid() and stat[19]==row['startTicks'] and os.getpgid(pid)==pid:targets.append(pid)
            except (OSError,FileNotFoundError):pass
    for pid in targets:
        try:os.killpg(pid,signal.SIGKILL);os.waitpid(pid,0)
        except (ProcessLookupError,ChildProcessError):pass
    left=sum(pathlib.Path('/proc',str(pid)).exists() for pid in targets)
    return {'helperGroupsKilled':len(targets),'helperProcessesLeft':left,'closure':'PROCESS_CONTAINMENT'}
def memory():
    root=pathlib.Path('/sys/fs/cgroup')
    def value(name):
        try:return int((root/name).read_text().strip())
        except (OSError,ValueError):return None
    events={k:int(v) for k,v in ((root/'memory.events').read_text().splitlines()[i].split() for i in range(len((root/'memory.events').read_text().splitlines())))}
    return {'currentBytes':value('memory.current'),'peakBytes':value('memory.peak'),'limitBytes':value('memory.max'),'events':events,
            'rssBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
class PublishTrace(Trace):
    def __init__(self,path):
        super().__init__(path);self.publish_lock=threading.RLock();self.fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600);os.close(self.fd)
    def emit(self,*a,**k):
        result=super().emit(*a,**k);self.publish();return result
    def mark_incomplete(self):
        super().mark_incomplete()
    def publish(self):
        with self.publish_lock:
            state={'rows':self.rows,'incomplete':self.incomplete,'uid':65534,'totalCap':256,'connectionCap':32}
            try:
                temp=OUT/'health.tmp';temp.write_text(json.dumps(state));os.chmod(temp,0o644);os.replace(temp,OUT/'proxy-health.json')
            except OSError:super().mark_incomplete()
class SourceLoop(asyncio.SelectorEventLoop):
    """Observe the public numeric socket API, delegate all TCP to asyncio."""
    def __init__(self,ctx):
        super().__init__();self.ctx=ctx;self.calls=0
        self.set_exception_handler(lambda loop,context:ctx.trace.mark_incomplete())
    async def sock_connect(self,sock,address):
        index=next_index(self);ctx=self.ctx;start=time.monotonic()
        group=getattr(getattr(ctx,'registry',None),'group_index',0)
        if getattr(ctx,'registry',None):ctx.registry.worker_tasks.add(asyncio.current_task())
        ctx.trace.observe(ctx.cid,'TCP_CONNECT','BEGIN',code='BEGIN',index=index,remaining=max(0,ctx.end-1-start),groupIndex=group)
        try:
            result=await super().sock_connect(sock,address)
            ctx.trace.observe(ctx.cid,'TCP_CONNECT','END',time.monotonic()-start,index=index,groupIndex=group)
            return result
        except asyncio.CancelledError:
            ctx.trace.observe(ctx.cid,'TCP_CONNECT','ERROR',time.monotonic()-start,code='CANCELLED',index=index,groupIndex=group);raise
        except BaseException:
            ctx.trace.observe(ctx.cid,'TCP_CONNECT','ERROR',time.monotonic()-start,code='ERROR',index=index,groupIndex=group);raise

def main():
    global ACTIVE,MAX_HELPERS
    stage=stage_policy();assert os.getuid()==65534 and sys.version.split()[0]=='3.11.2'
    (OUT/'proxy-runtime.json').write_text(json.dumps({'python':sys.version.split()[0],'versions':versions(),'sources':inventory(),'uid':os.getuid(),'trustSHA':trust_hash(),'stage':stage}))
    trace=PublishTrace(OUT/'proxy-trace.jsonl');Trace.current=trace
    if stage=='offline':
        from offline_glue import FaultIO,OfflineLoop,dns
        from owned_fixture import Fixture
        trace.io=FaultIO(control()['mode'])
    trace.publish()
    if stage=='offline' and control()['mode']=='trace-cap':
        for i in range(256):trace.emit(str(i//32).zfill(16),'REGISTRY_CLOSE','END',fixtureFiller=True)
    # Registry barrier deadline is set freshly at shutdown, not used to reset per-request setup.
    owners=Requests(trace,time.monotonic()+240)
    fixture=None
    if stage=='offline':
        class OwnedFixture(Fixture):
            def control(self):return control()
        fixture=OwnedFixture(OUT,owners,trace,owners.deadline)
    spec=importlib.util.spec_from_file_location('stock_owned_proxy','/stock/egress.py');stock=importlib.util.module_from_spec(spec);spec.loader.exec_module(stock)
    class Routed:
        def __init__(self,*a):self.base=None;self.timeout=10
        def settimeout(self,n):self.timeout=n
        def connect(self,address):
            ctx=CONTEXT.value
            if ctx.attempted:raise OSError('ALREADY_ATTEMPTED')
            ctx.attempted=True;registry=Sockets();ctx.registry=registry
            loop=OfflineLoop(ctx,fixture) if stage=='offline' else SourceLoop(ctx)
            # Independent global setup containment; does not extend deadlines or
            # pretend an uncooperative event loop can enforce a .10s reap slice.
            def contain_deadline():
                try:(OUT/'setup-containment.json').write_text(json.dumps({'code':'SETUP_WATCHDOG','actualExit':30,'sourceCalls':0 if stage=='offline' else None}))
                finally:os._exit(30)
            watchdog=threading.Timer(max(0,ctx.end-time.monotonic()),contain_deadline);watchdog.daemon=True;watchdog.start()
            try:self.base=loop.run_until_complete(connect(ctx.addresses,ctx.end-1,registry,loop=loop))
            finally:
                watchdog.cancel();watchdog.join(.1)
                if registry.pending or registry.reap_failed and any(not t.done() for t in asyncio.all_tasks(loop)):
                    contain_deadline()
                loop.close()
            assert not self.base.getblocking();self.base.settimeout(min(10,max(.001,ctx.end-time.monotonic())))
            ctx.winner=self.base
        def close(self):
            if self.base:self.base.close()
        def __getattr__(self,name):return getattr(self.base,name)
    class Facade:
        AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM;socket=Routed
        @staticmethod
        def getaddrinfo(host,port,type=1):
            global ACTIVE,MAX_HELPERS
            ctx=CONTEXT.value;settings=control();receipt={}
            if stage=='source':stage_policy()
            if not LIMIT.acquire(timeout=max(0,ctx.end-1-time.monotonic())):raise TimeoutError('HELPER_LIMIT')
            try:
                with ACTIVE_LOCK:ACTIVE+=1;MAX_HELPERS=max(MAX_HELPERS,ACTIVE)
                infos=dns(ctx,host,settings,receipt) if stage=='offline' else asyncio.run(resolve(0,[],ctx.end-1,receipt,mode='hostname',hostname=host))
                ctx.addresses=infos
                trace.observe(ctx.cid,'DNS_RESULT','END',answers=len(infos),childReaped=receipt.get('dnsChildReaped',False),
                  ipv4=sum(a[0]==socket.AF_INET for a in infos),ipv6=sum(a[0]==socket.AF_INET6 for a in infos))
                return infos
            finally:
                with ACTIVE_LOCK:ACTIVE-=1
                LIMIT.release()
                ctx.dns=receipt
    stock.socket=Facade
    class Conn:
        def __init__(self,base,ctx):self.base=base;self.ctx=ctx
        def __getattr__(self,name):return getattr(self.base,name)
        def settimeout(self,n):self.base.settimeout(min(n,max(.001,self.ctx.end-time.monotonic())))
        def sendall(self,data):
            if not self.ctx.tunnel and data==b'HTTP/1.1 200 Connection established\r\n\r\n':
                with trace.phase(self.ctx.cid,'CONNECT_200'):self.base.sendall(data)
                self.ctx.tunnel=True;self.base.settimeout(10)
                if self.ctx.winner:self.ctx.winner.settimeout(10)
            else:self.base.sendall(data)
    class Handler(stock.Handler):
        def handle(self):
            from types import SimpleNamespace
            settings=control();end=min(time.monotonic()+10,settings.get('phaseDeadline',time.monotonic()+30))
            ctx=SimpleNamespace(cid=owners.cid(self.request),end=end,trace=trace,addresses=[],attempted=False,registry=None,dns=None,winner=None,tunnel=False)
            CONTEXT.value=ctx;original=self.connection;self.connection=Conn(original,ctx)
            try:return super().handle()
            finally:
                if ctx.registry:
                    ctx.registry.close()
                    if stage=='offline' and control()['mode']=='closure-idempotent':ctx.registry.close()
                trace.observe(ctx.cid,'TUNNEL_CLOSE','END',setupFinished=ctx.tunnel)
                with (OUT/'connector-receipts.jsonl').open('a') as f:json.dump({'version':2,'ownerID':ctx.cid,'registryOwnerID':ctx.registry.cid if ctx.registry else 'UNKNOWN','dns':ctx.dns,'setupFinished':ctx.tunnel,
                  'socketsLeft':ctx.registry.live() if ctx.registry else 0,'socketPeak':ctx.registry.maxLive if ctx.registry else 0,'hostnameMode':'RAM_STDLIB_HOSTS_FIXTURE' if stage=='offline' else 'RAM_STDLIB_SOURCE',
                  'batch':{'code':ctx.registry.stop_code,'groups':ctx.registry.groups,'groupRecords':ctx.registry.records,'pending':len(ctx.registry.pending),'reapFailed':ctx.registry.reap_failed,'lateDenied':ctx.registry.late_denied,'suffixUnknown':ctx.registry.suffix_unknown,'epochActive':ctx.registry.epoch_active} if ctx.registry else {'code':'NOT_STARTED'}},f);f.write('\n')
    def abort(request):
        if stage=='offline' and control()['mode']=='owner-abort':raise OSError('FIXTURE_ABORT')
    Server=server_class(stock.Server,owners,accept_callback=abort)
    server=Server(('0.0.0.0',8888),Handler);serve=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.05});serve.start()
    stop=threading.Event();signal.signal(signal.SIGTERM,lambda *a:stop.set());signal.signal(signal.SIGINT,lambda *a:stop.set())
    isolation(OUT/'proxy-isolation.json',stage)
    (OUT/'proxy-ready.json').write_text(json.dumps({'ready':True,'stage':stage,'uid':65534,'fixture':stage=='offline','helperLimit':1,'mapping':'DOCKER_INTERNAL_HOSTS_ONLY' if stage=='offline' else 'NONE'}))
    stop.wait();owners.deadline=time.monotonic()+10
    if fixture:fixture.deadline=owners.deadline
    containment=None
    try:
        stop_server(server,serve,trace,owners.deadline)
        if fixture:fixture.close()
        physical=owners.wait_cleanup()
    except BaseException:
        trace.mark_incomplete();containment=contain_helpers();physical={'status':'FAIL_OR_CONTAINED'}
    if stage=='offline' and control()['mode']=='postfile-diagnostic':owners.errors+=1
    trace.close();trace.publish()
    receipts=[json.loads(line) for line in (OUT/'connector-receipts.jsonl').read_text().splitlines()] if (OUT/'connector-receipts.jsonl').exists() else []
    if stage=='offline' and control()['mode'] in ('batch-admission-postfile','batch-admission-preexisting','batch-epoch-postfile') and receipts:
        receipts[-1]['batch']['code']='TRACE_ADMISSION_LIMIT' if control()['mode']!='batch-epoch-postfile' else 'EPOCH_CLOSED'
        receipts[-1]['fixturePostfileFault']=True
        (OUT/'connector-receipts.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in receipts))
    groups=sum((r.get('dns') or {}).get('dnsGroupLeft',0) for r in receipts)
    tcp_rows=[json.loads(line) for line in (OUT/'proxy-trace.jsonl').read_text().splitlines()]
    if stage=='offline' and control()['mode']=='batch-phase-missing':
        index=next(i for i,r in enumerate(tcp_rows) if r['phase']=='SOCKET_CREATE' and r['event']=='BEGIN')
        tcp_rows.pop(index);(OUT/'proxy-trace.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in tcp_rows))
    tcpCoverage=coverage(tcp_rows)
    if stage=='offline' and (control()['mode'].startswith('batchval-') or control()['mode'].startswith('closure-') and control()['mode']!='closure-idempotent'):
        from validation_faults import mutate
        (OUT/'connector-before-fault.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in receipts))
        (OUT/'trace-before-fault.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in tcp_rows))
        os.chmod(OUT/'connector-before-fault.jsonl',0o600);os.chmod(OUT/'trace-before-fault.jsonl',0o600)
        receipts,tcp_rows=mutate(receipts,tcp_rows,control()['mode'])
        (OUT/'connector-receipts.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in receipts))
        (OUT/'proxy-trace.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in tcp_rows))
        # Only fresh fault fixture: accurate row counts of its modified trace;
        # no discarded evidence or counter adjustment in source/runtime controls.
        trace.count=len(tcp_rows);trace.counts={}
        for row in tcp_rows:trace.counts[row['ownerID']]=trace.counts.get(row['ownerID'],0)+1
        tcpCoverage=coverage(tcp_rows)
    from operation_coverage import operation_coverage
    operationCoverage=operation_coverage(tcp_rows)
    if tcpCoverage['status']!='COMPLETE':trace.mark_incomplete()
    if operationCoverage['status']!='COMPLETE':trace.mark_incomplete()
    summary={'tcpCoverage':tcpCoverage,'operationCoverage':operationCoverage,'final':True,'owners':owners.snapshot(),'physical':physical,'trace':trace.summary(),'traceClosed':True,'containment':containment,
        'incomplete':trace.incomplete or owners.errors!=0,'helpersActive':ACTIVE,'helperGroupsLeft':groups,'helperLimit':1,'maxHelpers':MAX_HELPERS,
        'memory':memory(),'uid':65534,'TLSDetail':'UNKNOWN','clientCorrelation':'UNKNOWN','sourceCalls':0 if stage=='offline' else None,'stage':stage}
    if stage=='source' or control()['mode']!='summary-missing':(OUT/'proxy-summary.json').write_text(json.dumps(summary,indent=2))
    return 30 if summary['incomplete'] else 0
if __name__=='__main__':sys.exit(main())
