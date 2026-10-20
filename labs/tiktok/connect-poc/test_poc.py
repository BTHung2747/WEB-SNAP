"""Offline fixture only. Public event-loop extension; real loopback TCP, TLS and Requests."""
import asyncio, hashlib, importlib.metadata, json, os, pathlib, socket, sys, threading, time
sys.path[:0]=['/poc/vendor','/poc','/stock','/integration','/trace_lab','/app/apps/media/src']
import aiohappyeyeballs, requests
from candidate import Sockets, setup, guard, connect
from fixture_origin import Fixture
import egress as stock

OUT=pathlib.Path('/out')
ABSOLUTE_DEADLINE=float(sys.argv[2])
sys.excepthook=lambda *a:print('POC_FIXED_FAILURE',flush=True)

def addresses(families):
    return [(f,socket.SOCK_STREAM,6,'',(('1.1.1.1' if i%2==0 else '1.0.0.1'),443) if f==socket.AF_INET
             else ('2606:4700:4700::1111',443,0,0)) for i,f in enumerate(families)]

class FixtureLoop(asyncio.SelectorEventLoop):
    """Override a documented method only; never touch library private implementation."""
    def __init__(self, plans):
        super().__init__(); self.plans=plans; self.calls=[]; self.targets={}; self.identity=OSError(111,'FAKEPATH_SECRET_TOKEN'); self.doubleGate=None;self.doubleCount=0
    async def sock_connect(self,sock,address):
        index=len(self.calls);plan=self.plans[index]
        row={'index':index+1,'family':'IPv4' if sock.family==socket.AF_INET else 'IPv6','event':'BEGIN','elapsed':0}
        self.calls.append(row);beg=time.monotonic()
        try:
            await asyncio.sleep(plan[0])
            if plan[1]=='FAIL':raise self.identity
            await super().sock_connect(sock,self.targets[sock.family])
            if plan[1]=='DOUBLE':
                row['tcpConnected']=True
                if self.doubleGate is None:self.doubleGate=self.create_future()
                self.doubleCount+=1
                if self.doubleCount==2:self.doubleGate.set_result(None)
                await self.doubleGate
            row['event']='END'
        except asyncio.CancelledError:row['event']='CANCEL';raise
        except OSError:row['event']='ERROR';raise
        finally:row['elapsed']=time.monotonic()-beg

async def network_case(name,loop):
    writers=[]
    async def accept(reader,writer):
        writers.append(writer)
        try:await reader.read(1)
        finally:writer.close();await writer.wait_closed()
    servers=[]
    for family,host in ((socket.AF_INET,'127.0.0.1'),(socket.AF_INET6,'::1')):
        s=await asyncio.start_server(accept,host,0,family=family);servers.append(s)
        loop.targets[family]=s.sockets[0].getsockname()
    receipt={'case':name,'fixture':True,'sourceCalls':0,'perAttemptProductionTerminal':'UNKNOWN','correlation':'UNKNOWN'}
    registry=Sockets();families=CONFIG[name]['families'];infos=addresses(families)
    start=time.monotonic(); sock=None; outcome='PASS'
    try:
        if name=='private-mixed':
            infos[-1]=(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))
        task=asyncio.create_task(setup(infos,CONFIG[name].get('dns',0),registry,receipt,
                     staggered=name!='stock-latency',loop=loop,budget=CONFIG[name].get('budget',10),
                     host='not-allowed.invalid' if name=='bad-host' else 'fixture.tiktok.com',absolute_deadline=ABSOLUTE_DEADLINE))
        if name in ('cancel-dns','cancel-connect'):
            loop.call_later(.15,task.cancel)
        try:
            sock=await task
            receipt['winnerBlockingBeforeHandoff']=sock.getblocking()
            assert registry.live()==1 and not sock.getblocking()
            if name=='cancel-after-winner':
                async def handoff():
                    try:await asyncio.sleep(1)
                    finally:registry.close()
                hand=asyncio.create_task(handoff());loop.call_later(.05,hand.cancel)
                await hand
            else:
                # Public blocking-mode handoff proves compatibility with stock tunnel I/O.
                sock.settimeout(10);sock.sendall(b'x');receipt['blockingTunnelContract']='PASS'
        except asyncio.CancelledError:outcome='CANCEL'
        except TimeoutError:outcome='DEADLINE'
        except ValueError:outcome='POLICY_DENIED'
        except OSError as exc:
            outcome='CONNECT_ERROR';receipt['exceptionIdentity']=exc is loop.identity
        expected=CONFIG[name].get('expected','PASS');assert outcome==expected
        assert receipt.get('dnsChildReaped',True)
        if name in ('private-mixed','bad-host','small-budget'):assert not registry.sockets
        assert registry.maxLive<=2
        if name=='exception-identity':assert receipt['exceptionIdentity']
        if name=='double-success':assert sum(row.get('tcpConnected',False) for row in loop.calls)==2
        # All attempted addresses match original order; mixed-family interleave stays disabled.
        assert registry.order==infos[:len(registry.order)]
        receipt.update(outcome=outcome,addressOrder='UNCHANGED',socketPeak=registry.maxLive,
                       attempts=loop.calls,createdSockets=len(registry.sockets))
    finally:
        registry.close()
        for s in servers:s.close();await s.wait_closed()
        for w in writers:w.close()
        await asyncio.sleep(.05)
    receipt.update(elapsed=time.monotonic()-start,socketsLeft=registry.live(),threads=threading.active_count(),
                   childrenLeft=len(__import__('multiprocessing').active_children()),pendingTasks=len([t for t in asyncio.all_tasks() if t is not asyncio.current_task() and not t.done()]))
    assert receipt['socketsLeft']==0 and receipt['childrenLeft']==0 and receipt['threads']==1 and receipt['pendingTasks']==0
    return receipt

CONFIG={
 'one':{'families':[socket.AF_INET],'plans':[(.01,'OK')]},
 'two-v4':{'families':[socket.AF_INET]*2,'plans':[(1,'OK'),(.02,'OK')]},
 'many-v4':{'families':[socket.AF_INET]*5,'plans':[(0,'FAIL')]*4+[(.01,'OK')]},
 'mixed':{'families':[socket.AF_INET6,socket.AF_INET,socket.AF_INET6,socket.AF_INET],'plans':[(0,'FAIL')]*3+[(.01,'OK')]},
 'all-fail':{'families':[socket.AF_INET]*4,'plans':[(0,'FAIL')]*4,'expected':'CONNECT_ERROR'},
 'near-success':{'families':[socket.AF_INET]*2,'plans':[(.252,'OK'),(.001,'OK')]},
 'double-success':{'families':[socket.AF_INET]*2,'plans':[(0,'DOUBLE')]*2},
 'stock-latency':{'families':[socket.AF_INET]*2,'dns':6.353045,'plans':[(10,'FAIL'),(.421074,'OK')],'expected':'DEADLINE'},
 'candidate-latency':{'families':[socket.AF_INET]*2,'dns':6.353045,'plans':[(10,'FAIL'),(.421074,'OK')]},
 'cancel-dns':{'families':[socket.AF_INET],'dns':30,'plans':[(0,'OK')],'expected':'CANCEL'},
 'dns-deadline':{'families':[socket.AF_INET],'dns':30,'plans':[(0,'OK')],'expected':'DEADLINE'},
 'cancel-connect':{'families':[socket.AF_INET]*2,'plans':[(30,'OK')]*2,'expected':'CANCEL'},
 'cancel-after-winner':{'families':[socket.AF_INET],'plans':[(0,'OK')],'expected':'CANCEL'},
 'small-budget':{'families':[socket.AF_INET],'budget':.5,'plans':[(0,'OK')],'expected':'DEADLINE'},
 'private-mixed':{'families':[socket.AF_INET]*2,'plans':[(0,'OK')]*2,'expected':'POLICY_DENIED'},
 'bad-host':{'families':[socket.AF_INET],'plans':[(0,'OK')],'expected':'POLICY_DENIED'},
 'exception-identity':{'families':[socket.AF_INET],'plans':[(0,'FAIL')],'expected':'CONNECT_ERROR'},
}

def tls_case(name):
    # Reuse previous HTTPS/photo provider and unmodified stock CONNECT handler.
    # Explicit fixture socket facade supplies the already guarded winner; no new parser.
    import socketserver
    out=OUT/name;out.mkdir();control=pathlib.Path('/tmp/control');control.mkdir(exist_ok=True)
    # Exact names created by this lab's reused provider in its private tmpfs.
    for file in ('fixture.jpg','fixture.pem','fixture.key','bad.pem','bad.key'):
        path=pathlib.Path('/tmp')/file
        if path.exists():
            assert path.stat().st_uid==os.getuid();path.unlink()
    mode={'tls-success':'normal','tls-cert':'image-cert-failure','tls-stall':'image-tls-stall'}[name]
    class OwnedFixture(Fixture):
        def control(self):return {'case':name,'mode':mode}
    fixture=OwnedFixture(out);reg=[]; metrics=[];handlers=[]
    port=fixture.servers[0].server_address[1] if mode=='normal' else fixture.servers[1].server_address[1] if mode=='image-cert-failure' else fixture.stall.server_address[1]
    class Routed:
        def __init__(self,*a):self.base=None;self.timeout=10
        def settimeout(self,n):
            self.timeout=n
            if self.base:self.base.settimeout(n)
        def connect(self,addr):
            registry=Sockets();reg.append(registry);loop=FixtureLoop([(0,'OK')]);loop.targets[socket.AF_INET]=('127.0.0.1',port)
            try:self.base=loop.run_until_complete(connect(addresses([socket.AF_INET]),min(time.monotonic()+9,ABSOLUTE_DEADLINE-1),registry,loop=loop))
            finally:loop.close()
            assert not self.base.getblocking();self.base.settimeout(self.timeout)
        def close(self):
            if self.base:self.base.close()
        def __getattr__(self,k):return getattr(self.base,k)
    class Facade:
        AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM;socket=Routed
        @staticmethod
        def getaddrinfo(host,port,type=1):return guard(addresses([socket.AF_INET]))
    # Modify only the dependency of a separately loaded fixture module, never library internals.
    import importlib.util
    spec=importlib.util.spec_from_file_location('owned_stock_fixture','/stock/egress.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.socket=Facade
    class Handler(module.Handler):
        def handle(self):
            try:return super().handle()
            finally:handlers.append('CLOSED')
    proxy=module.Server(('127.0.0.1',0),Handler);thread=threading.Thread(target=proxy.serve_forever);thread.start()
    session=requests.Session();session.trust_env=False;session.mount('https://',requests.adapters.HTTPAdapter(max_retries=0))
    before=time.monotonic();outcome='PASS'
    try:
        remaining=max(.01,10-(time.monotonic()-before)-.5)
        target='https://www.tiktok.com/@adne_la.veil/video/7678209751167110421' if name=='tls-success' else 'https://media.tiktokcdn.com/FAKEPATH_SECRET_TOKEN?token=FAKESIGNED'
        reply=session.get(target,
             proxies={'https':'http://127.0.0.1:'+str(proxy.server_address[1])},verify=str(out/'fixture-ca.pem'),
             timeout=(min(10,remaining),20),allow_redirects=False)
        assert reply.status_code==200;reply.close()
    except requests.exceptions.SSLError:outcome='TLS_VERIFY_ERROR'
    except requests.exceptions.ReadTimeout:outcome='SETUP_TIMEOUT'
    except requests.exceptions.ConnectionError:outcome='CONNECTION_ERROR'
    finally:
        elapsed=time.monotonic()-before;session.close();proxy.shutdown();proxy.server_close();thread.join(1)
        # Server daemon threads/fixture TLS stall can live beyond a client timeout.
        # Do not hide them: supervisor hard-deadline case contains/reaps this whole process.
        for registry in reg:registry.close()
        if name!='tls-stall':fixture.close()
    assert outcome=={'tls-success':'PASS','tls-cert':'TLS_VERIFY_ERROR','tls-stall':'SETUP_TIMEOUT'}[name]
    return {'case':name,'fixture':True,'sourceCalls':0,'outcome':outcome,'TLSverify':True,'elapsed':elapsed,
            'socketPeak':max(r.maxLive for r in reg),'socketsLeft':sum(r.live() for r in reg),
            'proxy200DoesNotProveTLS':True,'correlation':'UNKNOWN','fixtureCleanup':'PROCESS_OWNED' if name=='tls-stall' else 'CLOSED'}

def stock_actual():
    # Unmodified stock handler on the same injected DNS/first/second latency profile.
    import importlib.util
    spec=importlib.util.spec_from_file_location('stock_control','/stock/egress.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    path=OUT/'stock-actual-events.jsonl'
    def emit(stage,event):
        with path.open('a') as f:f.write(json.dumps({'stage':stage,'event':event,'elapsed':time.monotonic()-begin})+'\n')
    begin=time.monotonic()
    class Routed:
        def __init__(self,*a):self.base=socket.socket(*a)
        def __getattr__(self,key):return getattr(self.base,key)
        def connect(self,address):
            emit('TCP','BEGIN');time.sleep(10);raise TimeoutError('FIXTURE_SECRET')
    class Facade:
        AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=1;socket=Routed
        @staticmethod
        def getaddrinfo(*a,**k):
            emit('DNS','BEGIN');time.sleep(6.353045);emit('DNS','END');return addresses([socket.AF_INET]*2)
    module.socket=Facade
    server=module.Server(('127.0.0.1',0),module.Handler)
    thread=threading.Thread(target=server.serve_forever);thread.start()
    session=requests.Session();session.trust_env=False
    try:
        session.get('https://fixture.tiktok.com/FAKEPATH_SECRET_TOKEN?token=FAKESIGNED',
          proxies={'https':'http://127.0.0.1:'+str(server.server_address[1])},timeout=(10,20),verify=True,allow_redirects=False)
    finally:session.close();server.shutdown();server.server_close();thread.join()

def main():
    name=sys.argv[1];beforeFD=len(os.listdir('/proc/self/fd'))
    if name=='eventloop-block':time.sleep(30);raise AssertionError()
    if name=='stock-actual':stock_actual();raise AssertionError('Expected external budget stop')
    if name.startswith('tls-'):receipt=tls_case(name)
    else:
        loop=FixtureLoop(CONFIG[name]['plans'])
        try:receipt=loop.run_until_complete(network_case(name,loop))
        finally:loop.close()
    receipt.update(fdBefore=beforeFD,fdAfter=len(os.listdir('/proc/self/fd')),python=sys.version.split()[0],
                   library=importlib.metadata.version('aiohappyeyeballs'))
    assert receipt['fdAfter']<=beforeFD+1
    (OUT/(name+'.json')).write_text(json.dumps(receipt,indent=2))
    print('PASS '+name,flush=True)
if __name__=='__main__':main()
