import asyncio,copy,hashlib,json,os,pathlib,socket,threading,time
os.environ['TIKTOK_EGRESS_POLICY_ENABLED']='1'
from tiktok_policy import runtime
from tiktok_policy.dns_admission import admit,packet_valid,strict_loads
from tiktok_policy.dns_helper import packet_rows,deliver
from tiktok_policy.dns_ipc import resolve
from tiktok_policy.dns_diagnostic import validate_receipt
from tiktok_policy.ownership import Trace,MemoryIO
from tiktok_policy.candidate import Sockets,connect
from tiktok_policy.batch_validation import validate
import egress
OUT=pathlib.Path('/out');results=[]
def row(ip='1.1.1.1',port=443):return (socket.AF_INET,socket.SOCK_STREAM,6,'',(ip,port))
def case(name,**kw):results.append(dict(case=name,**kw))
def fail(call):
    try:call()
    except BaseException:return
    raise AssertionError('Expected rejection')
def suite():
    runtime.verify_vendor()
    for name,rows,expected in [
        ('duplicates256',[row()]*256,'OK'),('mixed-private',[row(),row('127.0.0.1')],'POLICY_DENIED'),
        ('suffix-private',[row()]*63+[row('10.0.0.1')],'POLICY_DENIED'),('wrong-port',[row(),row(port=80)],'POLICY_DENIED'),
        ('malformed',[[2,1,6,'',['1.1.1.1',443,0]]],'ROW_INVALID'),('raw257',[row()]*257,'RAW_PARSE_CAP'),
        ('unique65',[row('11.0.0.'+str(i)) for i in range(1,66)],'ENDPOINT_CAP'),
        ('mapped-private',[(10,1,6,'',('::ffff:127.0.0.1',443,0,0))],'POLICY_DENIED')]:
        answers,stats,_,_=admit(rows,time.monotonic()+2);assert stats['reason']==expected
        if expected=='OK':assert len(answers)==1 and stats['validatedCount']==256
        else:assert not answers
        case(name,reason=expected)
    ordered=[row('8.8.8.8'),row(),row('8.8.8.8')];answers,stats,_,_=admit(ordered,time.monotonic()+2);assert answers==ordered[:2];case('ordered-first-representative')
    for value in ['{"a":1,"a":2}','{"a":NaN}']:fail(lambda:strict_loads(value))
    case('duplicate-json-nonfinite-reject')
    a,s,_,_=admit([row()],time.monotonic()+2);p=dict(version=4,status='OK',code='OK',answers=a,admission=s,helperID='a'*16,unexpectedInherited=0,threads=1);assert packet_valid(p)
    for key,value in [('answers',[]),('threads',2),('unexpectedInherited',1),('code','ERROR')]:q=copy.deepcopy(p);q[key]=value;assert not packet_valid(q)
    case('helper-schema-contradictions')
    a,s,_,_=admit([row()],time.monotonic()-1);assert not a and s['reason']=='DEADLINE'
    a,s,_,_=admit([row()],time.monotonic()+1,memory_limit=1);assert not a and s['reason']=='MEMORY_CAP';case('scan-deadline-memory')
    async def dns_tests():
        trace=Trace();receipt={};answers=await resolve('fixture.tiktok.com',time.monotonic()+2,receipt,trace=trace)
        assert len(answers)==1 and validate_receipt(receipt,trace.file.rows)['accepted'];trace.close();assert receipt['dnsChildReaped'] and receipt['dnsExit']==0
        case('real-helper-IPC-reap',receipt=receipt)
        for mode in ['malformed','oversize','pass-exit20','duplicate','hang']:
            path=OUT/('fault-'+mode+'.py');path.write_text("import sys;sys.argv=['fault',"+repr(mode)+"];exec(open('/fixture/helper_fault.py').read())")
            trace=Trace();receipt={};start=time.monotonic()
            try:await resolve('fixture.tiktok.com',time.monotonic()+(.2 if mode=='hang' else 2),receipt,trace=trace,helper_path=path)
            except BaseException:pass
            else:raise AssertionError('Fault accepted')
            trace.close();assert receipt['dnsChildReaped'] and receipt['dnsGroupLeft']==0 and receipt['dnsPipesClosed'];assert time.monotonic()-start<3
            case('IPC-'+mode,reaped=True,actualExit=receipt['dnsExit'],elapsed=time.monotonic()-start)
        trace=Trace();receipt={};path=OUT/'fault-hang.py'
        task=asyncio.create_task(resolve('fixture.tiktok.com',time.monotonic()+3,receipt,trace=trace,helper_path=path));await asyncio.sleep(.1);task.cancel()
        try:await task
        except asyncio.CancelledError:pass
        assert receipt['dnsChildReaped'] and receipt['dnsGroupLeft']==0;trace.close();case('helper-cancel-reap')
    asyncio.run(dns_tests())
    # Actual TCP socket/library race; loopback remapping exists only in this fixture.
    listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(32);port=listener.getsockname()[1];stop=threading.Event()
    def echo():
        listener.settimeout(.1)
        while not stop.is_set():
            try:c,_=listener.accept()
            except socket.timeout:continue
            try:
                c.settimeout(.1)
                try:data=c.recv(100)
                except socket.timeout:data=b''
                if data:c.sendall(data)
            except OSError:pass
            finally:c.close()
    thread=threading.Thread(target=echo);thread.start()
    original=runtime.ObservedLoop
    class Loop(original):
        async def sock_connect(self,sock,address):return await super().sock_connect(sock,('127.0.0.1',port))
    runtime.ObservedLoop=Loop
    try:
        from types import SimpleNamespace
        # Public library owns race/tasks/losers; only loopback mapping/delay is fake.
        for mode in ['pair-winner','next-group','budget-before-socket','suffix-private-before-socket','group-cap','cancel']:
            trace=Trace();ctx=SimpleNamespace(cid='c'*16,trace=trace)
            registry=Sockets(trace,ctx.cid);ctx.registry=registry;ctx.end=time.monotonic()+10
            class PolicyLoop(original):
                async def sock_connect(self,sock,address):
                    if mode in ('pair-winner','cancel') and address[0]=='1.1.1.1':await asyncio.sleep(5)
                    denied=mode=='next-group' and address[0] in ('1.1.1.1','1.0.0.1') or mode=='group-cap'
                    return await super().sock_connect(sock,('127.0.0.1',9 if denied else port))
            loop=PolicyLoop(ctx)
            addresses=[row(),row('1.0.0.1')]
            if mode=='next-group':addresses+=[row('8.8.8.8')]
            if mode=='suffix-private-before-socket':addresses+=[row('10.0.0.1')]
            if mode=='group-cap':addresses=[row('11.0.0.'+str(i)) for i in range(1,11)]
            deadline=time.monotonic()+(.1 if mode=='budget-before-socket' else 9)
            async def run():
                task=asyncio.create_task(connect(addresses,deadline,registry,loop=loop))
                if mode=='cancel':await asyncio.sleep(.05);task.cancel()
                return await task
            try:
                winner=loop.run_until_complete(run());assert mode in ('pair-winner','next-group');assert registry.live()==1 and registry.maxLive<=2
                if mode=='pair-winner':assert registry.maxLive==2
                if mode=='next-group':assert registry.groups==2 and registry.records[0]['live']==0 and registry.records[0]['created']==registry.records[0]['closed']
                fail(lambda:registry.last_factory(row()))
            except BaseException:
                if mode in ('pair-winner','next-group'):raise
                if mode in ('budget-before-socket','suffix-private-before-socket'):assert not registry.sockets
                if mode=='group-cap':assert registry.groups==4 and registry.suffix_unknown==2
            finally:
                registry.close();assert registry.live()==0 and not registry.pending and not asyncio.all_tasks(loop);loop.close();trace.close()
            case('public-library-'+mode,maxLive=registry.maxLive,groups=registry.groups,socketsLeft=0)
        # Exercise production CONNECT parser/Handler and persistent bounded server.
        server=egress.Server(('127.0.0.1',0),egress.Handler);serving=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.01});serving.start()
        def request():
            client=socket.create_connection(server.server_address,timeout=3)
            client.sendall(b'CONNECT fixture.tiktok.com:443 HTTP/1.1\r\n\r\n');reply=b''
            while b'\r\n\r\n' not in reply:reply+=client.recv(1024)
            assert reply.startswith(b'HTTP/1.1 200');client.sendall(b'echo');assert client.recv(4)==b'echo';client.close()
        for i in range(20):request()
        failures=[]
        def concurrent():
            try:request()
            except BaseException as exc:failures.append(type(exc).__name__)
        workers=[threading.Thread(target=concurrent) for _ in range(3)]
        for worker in workers:worker.start()
        for worker in workers:worker.join(4);assert not worker.is_alive()
        assert not failures
        for i in range(200):
            if not server.policy_contexts and not server.policy_pending:break
            time.sleep(.01)
        assert not server.policy_contexts and not server.policy_pending and len(server.completed)==16
        assert all(c['accepted'] for c in server.completed),[(c.get('validation'),c.get('traceIncomplete')) for c in server.completed]
        sample=server.completed[-1];(OUT/'sample-proxy-receipt.json').write_text(json.dumps(sample,indent=2))
        assert sample['receipt']['socketPeak']<=2 and sample['clientClosed'] and sample['loopClosed'] and sample['workerThreadClosed']
        for field in ['groups','pending']:
            r=copy.deepcopy(sample['receipt']);r['batch'][field]+=1;assert not validate([r],sample['trace'])['accepted']
        r=copy.deepcopy(sample['receipt']);r['socketsLeft']=1;assert not validate([r],sample['trace'])['accepted']
        case('actual-CONNECT-TCP-repeated20-concurrent3-isolated-owners',retained=16,maxLive=sample['receipt']['socketPeak'])
        case('batch-registry-receipt-trace-contradictions')
        # Observer failure in a full owned handler is never a transport fallback.
        originalRequest=runtime.Request
        class BrokenIO(MemoryIO):
            def write(self,*args):raise OSError('FIXTURE_TRACE_WRITE')
        class BrokenRequest(originalRequest):
            def __init__(self,client):super().__init__(client,Trace(io=BrokenIO()))
        runtime.Request=BrokenRequest
        try:
            client=socket.create_connection(server.server_address,timeout=2);client.sendall(b'CONNECT fixture.tiktok.com:443 HTTP/1.1\r\n\r\n');assert client.recv(1024).startswith(b'HTTP/1.1 403');client.close()
            for _ in range(100):
                if not server.policy_contexts and not server.policy_pending:break
                time.sleep(.01)
            assert not server.completed[-1]['accepted'] and server.completed[-1]['clientClosed']
        finally:runtime.Request=originalRequest
        request();case('full-handler-trace-error-no-fallback-then-fresh-request')
        # Non-TikTok and flag-off use the existing sequential path, actual TCP.
        originalSocket=egress.socket
        class MappedSocket(socket.socket):
            def connect(self,address):return super().connect(('127.0.0.1',port))
        class Facade:
            SOCK_STREAM=socket.SOCK_STREAM;socket=MappedSocket
            @staticmethod
            def getaddrinfo(*args,**kwargs):return [row()]
        try:
            egress.socket=Facade
            for host,flag in [('www.youtube.com','1'),('fixture.tiktok.com','0')]:
                os.environ['TIKTOK_EGRESS_POLICY_ENABLED']=flag
                client=socket.create_connection(server.server_address,timeout=2);client.sendall(('CONNECT '+host+':443 HTTP/1.1\r\n\r\n').encode());assert client.recv(1024).startswith(b'HTTP/1.1 200');client.sendall(b'echo');assert client.recv(4)==b'echo';client.close()
            case('legacy-YouTube-and-policy-off-actual-TCP-no-new-helper')
        finally:egress.socket=originalSocket;os.environ['TIKTOK_EGRESS_POLICY_ENABLED']='1'
        server.shutdown();server.server_close();serving.join(2);assert not serving.is_alive()
    finally:
        runtime.ObservedLoop=original;stop.set();thread.join(1);listener.close()
    # Trace open/write/flush/close errors: cleanup never depends on observer I/O.
    for phase in ['open','write','flush','close']:
        class Fault(MemoryIO):
            def open(self,path):
                if phase=='open':raise OSError('FIXTURE')
                return super().open(path)
            def write(self,file,text):
                if phase=='write':raise OSError('FIXTURE')
                return super().write(file,text)
            def flush(self,file):
                if phase=='flush':raise OSError('FIXTURE')
            def close(self,file):
                if phase=='close':raise OSError('FIXTURE')
                return super().close(file)
        trace=Trace(io=Fault());reg=Sockets(trace,'b'*16);s=socket.socket();reg.sockets.append(s)
        try:reg.close()
        except BaseException:pass
        trace.close();assert s.fileno()==-1 and trace.incomplete;case('trace-'+phase+'-physical-cleanup')
    assert runtime.enabled('a.tiktokcdn.com') and not runtime.enabled('www.youtube.com')
    os.environ['TIKTOK_EGRESS_POLICY_ENABLED']='0';assert not runtime.enabled('www.tiktok.com');os.environ['TIKTOK_EGRESS_POLICY_ENABLED']='1';case('flag-and-domain-scope')
    (OUT/'results.json').write_text(json.dumps(dict(status='PASS_OFFLINE_POLICY_UNIT',sourceCalls=0,cases=results),indent=2));print('PASS unit',len(results))
