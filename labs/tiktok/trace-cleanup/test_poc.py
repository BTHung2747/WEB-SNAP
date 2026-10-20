"""Offline fixture only. Public event-loop extension; real loopback TCP, TLS and Requests."""
import asyncio, hashlib, importlib.metadata, json, os, pathlib, socket, sys, threading, time
sys.path[:0]=['/vendor','/poc','/stock','/integration','/trace_lab','/app/apps/media/src']
import aiohappyeyeballs, requests
from candidate import Sockets, setup, guard, connect
from owned_fixture import Fixture
from ownership import Trace,Requests,server_class,stop_server
import uuid
import egress as stock

OUT=pathlib.Path('/out')
PHASE='INIT'
ABSOLUTE_DEADLINE=float(sys.argv[2])
sys.excepthook=lambda *a:print('POC_FIXED_FAILURE',flush=True)
def fixed_error(cls,error,tb):
    codes={AssertionError:'ASSERT',ValueError:'CONTRACT',OSError:'IO',TimeoutError:'DEADLINE',RuntimeError:'RUNTIME',AttributeError:'ATTRIBUTE',TypeError:'TYPE',KeyError:'KEY'}
    value={'status':'FAIL','phase':PHASE,'code':codes.get(cls,'UNKNOWN'),'fdCount':len(os.listdir('/proc/self/fd')),
           'threads':threading.active_count(),'sourceCalls':0,'trace':Trace.current.summary() if Trace.current else None}
    (OUT/(sys.argv[1]+'-failure.json')).write_text(json.dumps(value,indent=2))
    if Trace.current:Trace.current.close()
    print('POC_FIXED_FAILURE',flush=True)
sys.excepthook=fixed_error

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
    writers=[];tasks=[];accepted=asyncio.Condition()
    async def accept(reader,writer):
        writers.append(writer);tasks.append(asyncio.current_task())
        async with accepted:accepted.notify_all()
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
        expectedAccepted=sum(r['event']=='END' or r.get('tcpConnected',False) for r in loop.calls)
        async with asyncio.timeout_at(ABSOLUTE_DEADLINE):
            async with accepted:await accepted.wait_for(lambda:len(writers)>=expectedAccepted)
        for s in servers:s.close();await s.wait_closed()
        for w in writers:w.close()
        async with asyncio.timeout_at(ABSOLUTE_DEADLINE):
            if tasks:await asyncio.gather(*tasks)
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
    global PHASE
    PHASE='TLS_FIXTURE_INIT'
    out=OUT/name;out.mkdir();trace=Trace.current;owners=Requests(trace,ABSOLUTE_DEADLINE)
    for file in ('fixture.jpg','fixture.pem','fixture.key','bad.pem','bad.key'):
        path=pathlib.Path('/tmp')/file
        if path.exists():assert path.stat().st_uid==os.getuid();path.unlink()
    mode='normal' if name in ('tls-success','tls-close-early','tls-close-slow') else {'tls-cert':'image-cert-failure','tls-stall':'image-tls-stall'}[name]
    class OwnedFixture(Fixture):
        def control(self):return {'case':name,'mode':mode}
    fixture=OwnedFixture(out,owners,trace,ABSOLUTE_DEADLINE);reg=[];dns=[]
    port=fixture.servers[0].server_address[1] if mode=='normal' else fixture.servers[1].server_address[1] if mode=='image-cert-failure' else fixture.stall.server_address[1]
    class Routed:
        def __init__(self,*a):self.base=None;self.timeout=10;self.owner=uuid.uuid4().hex[:16]
        def settimeout(self,n):
            self.timeout=n
            if self.base:self.base.settimeout(n)
        def connect(self,addr):
            registry=Sockets();reg.append(registry);row={};dns.append(row)
            loop=FixtureLoop([(0,'OK')]);loop.targets[socket.AF_INET]=('127.0.0.1',port)
            try:self.base=loop.run_until_complete(setup(addresses([socket.AF_INET]),0,registry,row,loop=loop,absolute_deadline=ABSOLUTE_DEADLINE))
            finally:loop.close()
            assert not self.base.getblocking();self.base.settimeout(min(self.timeout,max(.001,ABSOLUTE_DEADLINE-time.monotonic())))
        def close(self):
            with trace.phase(self.owner,'WINNER_CLOSE'):
                if self.base:self.base.close()
        def __getattr__(self,k):return getattr(self.base,k)
    class Facade:
        AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM;socket=Routed
        @staticmethod
        def getaddrinfo(host,port,type=1):return guard(addresses([socket.AF_INET]))
    import importlib.util
    spec=importlib.util.spec_from_file_location('owned_stock_fixture','/stock/egress.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.socket=Facade
    gate=threading.Event() if name in ('tls-close-early','tls-close-slow') else None
    if gate and name=='tls-close-early':gate.set()
    Proxy=server_class(module.Server,owners,gate)
    proxy=Proxy(('127.0.0.1',0),module.Handler)
    serve=threading.Thread(target=proxy.serve_forever,kwargs={'poll_interval':.05});serve.start()
    session=requests.Session();session.trust_env=False;session.mount('https://',requests.adapters.HTTPAdapter(max_retries=0))
    before=time.monotonic();outcome='PASS';barrier=None;timer=None;cid=uuid.uuid4().hex[:16]
    try:
        PHASE='TLS_REQUEST'
        target='https://www.tiktok.com/@adne_la.veil/video/7678209751167110421' if mode=='normal' else 'https://media.tiktokcdn.com/FAKEPATH_SECRET_TOKEN?token=FAKESIGNED'
        reply=session.get(target,proxies={'https':'http://127.0.0.1:'+str(proxy.server_address[1])},verify=str(out/'fixture-ca.pem'),
             timeout=(min(10,max(.001,ABSOLUTE_DEADLINE-time.monotonic()-1)),20),allow_redirects=False)
        assert reply.status_code==200;reply.close();del reply
    except requests.exceptions.SSLError:outcome='TLS_VERIFY_ERROR'
    except requests.exceptions.ReadTimeout:outcome='SETUP_TIMEOUT'
    except requests.exceptions.ConnectionError:outcome='CONNECTION_ERROR'
    finally:
        PHASE='TLS_SESSION_CLOSE'
        with trace.phase(cid,'SESSION_CLOSE'):session.close()
        PHASE='TLS_SERVER_CLOSE'
        stop_server(proxy,serve,trace,ABSOLUTE_DEADLINE)
        preBarrier=owners.snapshot()
        for registry in reg:registry.close()
        PHASE='TLS_FIXTURE_CLOSE'
        with trace.phase(cid,'FIXTURE_SERVER_CLOSE'):fixture.close()
        if name=='tls-close-slow':
            assert preBarrier['requestSocketsLeft']>=1
            # Controlled delayed release, not a sleep used to assume closure.
            timer=threading.Timer(.15,gate.set);timer.start()
        PHASE='TLS_OWNED_BARRIER'
        barrier=owners.wait()
        if timer:timer.join(max(0,ABSOLUTE_DEADLINE-time.monotonic()))
    expected='PASS' if mode=='normal' else 'TLS_VERIFY_ERROR' if name=='tls-cert' else 'SETUP_TIMEOUT'
    assert outcome==expected
    if name=='tls-close-slow':assert barrier['elapsed']>=.1
    assert owners.snapshot()['requestSocketsLeft']==0 and owners.snapshot()['workerThreadsLeft']==0
    assert all(row['dnsChildReaped'] and row['dnsGroupLeft']==0 and row['dnsPipesClosed'] for row in dns)
    return {'case':name,'fixture':True,'sourceCalls':0,'outcome':outcome,'TLSverify':True,'elapsed':time.monotonic()-before,
      'socketPeak':max(r.maxLive for r in reg),'socketsLeft':sum(r.live() for r in reg),'proxy200DoesNotProveTLS':True,
      'correlation':'UNKNOWN','historicalTLSCause':'UNKNOWN','fixtureCleanup':'CLOSED','barrier':barrier,'beforeBarrier':preBarrier,
      'owners':owners.snapshot(),'dnsFromThreadedHandler':dns,'threadsAtFinal':threading.active_count()}

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
    global PHASE
    name=sys.argv[1];beforeFD=len(os.listdir('/proc/self/fd'))
    Trace.current=Trace(OUT/(name+'-ownership.jsonl'))
    if name=='legacy-reproduce' or name.startswith('fault-'):
        PHASE='TARGETED_FAULTS'
        from test_faults import main_case
        return main_case(name,ABSOLUTE_DEADLINE)
    if name=='eventloop-block':time.sleep(30);raise AssertionError()
    if name=='stock-actual':stock_actual();raise AssertionError('Expected external budget stop')
    if name=='socket-expired':
        PHASE='SOCKET_EXPIRED_CASE';registry=Sockets();registry.deadline=time.monotonic()-1
        try:registry.factory(addresses([socket.AF_INET])[0]);raise AssertionError('Expired socket accepted')
        except TimeoutError:receipt={'case':name,'outcome':'DEADLINE_REJECT','sourceCalls':0,'createdSockets':len(registry.sockets),'socketsLeft':registry.live()}
        assert not registry.sockets
    elif name=='closure-expired':
        PHASE='CLOSURE_EXPIRED_CASE';owners=Requests(Trace.current,time.monotonic()-1)
        try:owners.wait();raise AssertionError('Expired barrier accepted')
        except TimeoutError:receipt={'case':name,'outcome':'DEADLINE_REJECT','sourceCalls':0,'owners':owners.snapshot()}
    elif name.startswith('dns-thread-'):
        PHASE='DNS_THREADED_CASE'
        from test_dns import threaded_case
        receipt=threaded_case(name,ABSOLUTE_DEADLINE,Trace.current)
    elif name.startswith('tls-'):receipt=tls_case(name)
    else:
        loop=FixtureLoop(CONFIG[name]['plans'])
        try:receipt=loop.run_until_complete(network_case(name,loop))
        finally:loop.close()
    Trace.current.close()
    receipt.update(fdBefore=beforeFD,fdAfter=len(os.listdir('/proc/self/fd')),python=sys.version.split()[0],
                   library=importlib.metadata.version('aiohappyeyeballs'))
    PHASE='FINAL_RESOURCE_CHECK'
    receipt['trace']=Trace.current.summary()
    (OUT/(name+'-precheck.json')).write_text(json.dumps(receipt,indent=2))
    assert receipt['fdAfter']<=beforeFD+1 and not receipt['trace']['incomplete']
    (OUT/(name+'.json')).write_text(json.dumps(receipt,indent=2))
    print('PASS '+name,flush=True)
if __name__=='__main__':main()
