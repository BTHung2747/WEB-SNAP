"""Offline-only CONNECT glue. Original parser/tunnel delegates; no source mode."""
import asyncio,importlib.util,json,os,pathlib,resource,signal,socket,sys,threading,time,uuid
sys.path[:0]=['/integration','/vendor','/stock']
from common import inventory,versions
from ownership import Trace,Requests,FileOps,server_class,stop_server
from candidate import Sockets,connect
from dns_ipc import resolve
from owned_fixture import Fixture
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
class FaultIO(FileOps):
    def __init__(self,kind):self.kind=kind
    def open(self,path):
        if self.kind=='trace-open':raise OSError('FIXTURE_IO')
        return super().open(path)
    def write(self,file,text):
        if self.kind=='trace-write':raise OSError('FIXTURE_IO')
        return super().write(file,text)
    def close(self,file):
        if self.kind=='final-close-fail':raise OSError('FIXTURE_IO')
        return super().close(file)
class OfflineLoop(asyncio.SelectorEventLoop):
    def __init__(self,ctx,fixture):super().__init__();self.ctx=ctx;self.fixture=fixture;self.calls=0
    async def sock_connect(self,sock,address):
        self.calls+=1;mode=control()['mode'];image=address[0]=='1.0.0.1'
        cid=self.ctx.cid;trace=self.ctx.trace;start=time.monotonic()
        trace.observe(cid,'FIXTURE_TCP','BEGIN',code='BEGIN',index=self.calls)
        try:
            if mode=='candidate-latency' and len(self.ctx.addresses)>1:
                await asyncio.sleep(10 if self.calls==1 else .421074)
                if self.calls==1:raise TimeoutError('FIXTURE_STALL')
            port=self.fixture.servers[0].server_address[1]
            if image and mode=='image-tcp-failure':port=self.fixture.closed_port
            elif image and mode=='image-cert-failure':port=self.fixture.servers[1].server_address[1]
            elif image and mode=='image-tls-stall':port=self.fixture.stall.server_address[1]
            if mode=='handoff-fail':raise ConnectionError('FIXTURE_HANDOFF')
            await super().sock_connect(sock,('127.0.0.1',port))
            trace.observe(cid,'FIXTURE_TCP','END',time.monotonic()-start,index=self.calls)
        except BaseException:
            trace.observe(cid,'FIXTURE_TCP','ERROR',time.monotonic()-start,code='ERROR',index=self.calls);raise
def main():
    global ACTIVE,MAX_HELPERS
    assert os.environ.get('WHOLEPHOTO_STAGE')=='offline' and os.getuid()==65534 and sys.version.split()[0]=='3.11.2'
    (OUT/'proxy-runtime.json').write_text(json.dumps({'python':sys.version.split()[0],'versions':versions(),'sources':inventory(),'uid':os.getuid()}))
    trace=PublishTrace(OUT/'proxy-trace.jsonl');Trace.current=trace
    trace.io=FaultIO(control()['mode']);trace.publish()
    if control()['mode']=='trace-cap':
        for i in range(256):trace.emit(str(i//32).zfill(16),'REGISTRY_CLOSE','END',fixtureFiller=True)
    # Registry barrier deadline is set freshly at shutdown, not used to reset per-request setup.
    owners=Requests(trace,time.monotonic()+240)
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
            loop=OfflineLoop(ctx,fixture)
            try:self.base=loop.run_until_complete(connect(ctx.addresses,ctx.end-1,registry,loop=loop))
            finally:loop.close()
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
            ctx=CONTEXT.value;settings=control();mode=settings['mode'];receipt={}
            if not LIMIT.acquire(timeout=max(0,ctx.end-1-time.monotonic())):raise TimeoutError('HELPER_LIMIT')
            try:
                with ACTIVE_LOCK:ACTIVE+=1;MAX_HELPERS=max(MAX_HELPERS,ACTIVE)
                options={'mode':'hostname','hostname':host}
                delay=6.353045 if mode=='candidate-latency' else 0
                if mode=='dns-private':options['hostname']='localhost'
                elif mode=='image-dns-failure' and host=='media.tiktokcdn.com':options['mode']='error'
                elif mode=='helper-crash':options['mode']='crash'
                elif mode=='helper-cap':options['mode']='oversize'
                elif mode=='helper-late':options['mode']='late-reply';delay=30
                elif mode=='helper-answer-cap':options['mode']='answer-oversize'
                seed=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]
                if mode=='proxy-parent-block':
                    async def blocked():
                        task=asyncio.create_task(resolve(30,seed,ctx.end-1,receipt,**options))
                        await asyncio.sleep(.1);time.sleep(30)
                        return await task
                    infos=asyncio.run(blocked())
                else:infos=asyncio.run(resolve(delay,seed,ctx.end-1,receipt,**options))
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
                if ctx.registry:ctx.registry.close()
                trace.observe(ctx.cid,'TUNNEL_CLOSE','END',setupFinished=ctx.tunnel)
                with (OUT/'connector-receipts.jsonl').open('a') as f:json.dump({'ownerID':ctx.cid,'dns':ctx.dns,'setupFinished':ctx.tunnel,
                  'socketsLeft':ctx.registry.live() if ctx.registry else 0,'socketPeak':ctx.registry.maxLive if ctx.registry else 0,'hostnameMode':'RAM_STDLIB_HOSTS_FIXTURE'},f);f.write('\n')
    def abort(request):
        if control()['mode']=='owner-abort':raise OSError('FIXTURE_ABORT')
    Server=server_class(stock.Server,owners,accept_callback=abort)
    server=Server(('0.0.0.0',8888),Handler);serve=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.05});serve.start()
    stop=threading.Event();signal.signal(signal.SIGTERM,lambda *a:stop.set());signal.signal(signal.SIGINT,lambda *a:stop.set())
    (OUT/'proxy-ready.json').write_text(json.dumps({'ready':True,'stage':'offline','uid':65534,'fixture':True,'helperLimit':1,'mapping':'DOCKER_INTERNAL_HOSTS_ONLY'}))
    stop.wait();owners.deadline=time.monotonic()+10;fixture.deadline=owners.deadline
    containment=None
    try:stop_server(server,serve,trace,owners.deadline);fixture.close();physical=owners.wait_cleanup()
    except BaseException:
        trace.mark_incomplete();containment=contain_helpers();physical={'status':'FAIL_OR_CONTAINED'}
    if control()['mode']=='postfile-diagnostic':owners.errors+=1
    trace.close();trace.publish()
    receipts=[json.loads(line) for line in (OUT/'connector-receipts.jsonl').read_text().splitlines()] if (OUT/'connector-receipts.jsonl').exists() else []
    groups=sum((r.get('dns') or {}).get('dnsGroupLeft',0) for r in receipts)
    summary={'final':True,'owners':owners.snapshot(),'physical':physical,'trace':trace.summary(),'traceClosed':True,'containment':containment,
        'incomplete':trace.incomplete or owners.errors!=0,'helpersActive':ACTIVE,'helperGroupsLeft':groups,'helperLimit':1,'maxHelpers':MAX_HELPERS,
        'memory':memory(),'uid':65534,'TLSDetail':'UNKNOWN','clientCorrelation':'UNKNOWN','sourceCalls':0}
    if control()['mode']!='summary-missing':(OUT/'proxy-summary.json').write_text(json.dumps(summary,indent=2))
    return 30 if summary['incomplete'] else 0
if __name__=='__main__':sys.exit(main())
