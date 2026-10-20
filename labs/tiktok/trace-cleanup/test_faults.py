"""Real accepted TCP, owned public dispatch; fault expectations never imply diagnostic PASS."""
import hashlib,importlib.util,json,os,pathlib,socket,socketserver,subprocess,sys,threading,time,uuid
from ownership import Trace,Requests,FileOps,DiagnosticIncomplete,server_class
OUT=pathlib.Path('/out')
FAULTS=['control','cap-before-close','write-before-shutdown','total-cap-dispatch','owner-cap-dispatch',
        'accept-end','finish-begin','finish-end','finish-error','shutdown-begin','shutdown-end',
        'close-begin','close-end','worker-return','barrier-end','file-open','file-write','file-flush','file-close',
        'handler-error','thread-factory','thread-start','accept-callback','registry-cap',
        'delegate-close-before','delegate-close-after','trace-and-delegate','server-close-begin','registry-close','missing-evidence']
SECRET=OSError('https://fake.invalid/FAKEPATH_SECRET?token=FAKESIGNED&cookie=PRIVATE') # RAM; no message/stack output.

class FaultIO(FileOps):
    def __init__(self,name):self.name=name;self.fired=False
    def hit(self,operation,text=None):
        row=json.loads(text) if text else {}
        points={'accept-end':('REQUEST_ACCEPT','END'),'finish-begin':('REQUEST_FINISH','BEGIN'),
          'finish-end':('REQUEST_FINISH','END'),'finish-error':('REQUEST_FINISH','ERROR'),
          'shutdown-begin':('REQUEST_SHUTDOWN','BEGIN'),'shutdown-end':('REQUEST_SHUTDOWN','END'),
          'close-begin':('REQUEST_CLOSE','BEGIN'),'close-end':('REQUEST_CLOSE','END'),
          'worker-return':('WORKER_RETURN','END'),'barrier-end':('CLOSURE_BARRIER','END'),
          'server-close-begin':('SERVER_SERVE_CLOSE','BEGIN'),'registry-close':('REGISTRY_CLOSE','BEGIN'),
          'trace-and-delegate':('REQUEST_CLOSE','BEGIN'),'write-before-shutdown':('REQUEST_SHUTDOWN','BEGIN')}
        matched=(self.name=='file-'+operation or operation=='write' and (row.get('phase'),row.get('event'))==points.get(self.name))
        if matched and not self.fired:self.fired=True;raise SECRET
    def open(self,path):self.hit('open');return super().open(path)
    def write(self,file,text):self.hit('write',text);return super().write(file,text)
    def flush(self,file):self.hit('flush');return super().flush(file)
    def close(self,file):self.hit('close');return super().close(file)

def fill(trace,owner=False):
    ids=[uuid.uuid4().hex[:16] for _ in range(8)]
    for index in range(32 if owner else 256):trace.emit(ids[0] if owner else ids[index//32],'REGISTRY_CLOSE','END',fixtureFiller=True)
    if owner:trace.emit(ids[0],'REGISTRY_CLOSE','END')

def diagnostics(owners):
    try:owners.wait();return 'PASS'
    except DiagnosticIncomplete:return 'FAIL_TRACE_INCOMPLETE'
    except RuntimeError:return 'FAIL_DELEGATE'

def fault_case(name,deadline):
    folder=OUT/name;folder.mkdir();io=FaultIO(name);trace=Trace(folder/'trace.jsonl',io);Trace.current=trace
    owners=Requests(trace,deadline);captured=[];identityVerified=None;direct=name in ('control','cap-before-close','write-before-shutdown')
    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            if name in ('handler-error','finish-error'):raise SECRET
    class Base(socketserver.ThreadingTCPServer):
        daemon_threads=True
        def close_request(self,request):
            if name in ('delegate-close-before','trace-and-delegate'):raise SECRET
            super().close_request(request)
            if name=='delegate-close-after':raise SECRET
    class StartFailure(threading.Thread):
        def start(self):raise SECRET
    def factory(**kwargs):raise SECRET
    def callback(request):captured.append(request);raise SECRET
    Server=server_class(Base,owners,accept_callback=callback if name=='accept-callback' else None,
           worker_factory=factory if name=='thread-factory' else StartFailure if name=='thread-start' else None)
    server=Server(('127.0.0.1',0),Handler);client=None;request=None;diagnostic=None;physical=None
    try:
        if name=='registry-cap':
            for index in range(64):
                connection=socket.create_connection(server.server_address,timeout=1)
                req,address=server.get_request();connection.close();server.process_request(req,address)
            owners.wait_cleanup()
        client=socket.create_connection(server.server_address,timeout=1)
        try:request,address=server.get_request()
        except BaseException as error:
            identityVerified=error is SECRET if name=='accept-callback' else isinstance(error,RuntimeError)
            if captured:request=captured[0]
        client.close();client=None
        if request is not None and name!='accept-callback':
            if name in ('cap-before-close','total-cap-dispatch'):fill(trace)
            if name=='owner-cap-dispatch':fill(trace,True)
            try:
                if direct:
                    if name=='cap-before-close':server.close_request(request)
                    else:server.shutdown_request(request)
                else:server.process_request(request,address)
            except BaseException as error:identityVerified=error is SECRET
        if direct:
            assert request.fileno()==-1
            physical=owners.snapshot();diagnostic='PASS_CLOSE_CONTROL' if name=='control' else 'FAIL_TRACE_INCOMPLETE'
        else:
            physical=owners.wait_cleanup()['after'];diagnostic=diagnostics(owners)
            if name in ('handler-error','finish-error','delegate-close-before','delegate-close-after','trace-and-delegate'):
                identityVerified=owners.error_objects.get(owners.cid(request)) is SECRET
        if name=='server-close-begin':
            # Exercise actual public stop_server delegate despite observer fault.
            from ownership import stop_server
            serve=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.05});serve.start()
            stop_server(server,serve,trace,deadline)
        if name=='registry-close':
            from candidate import Sockets
            registry=Sockets();registry.deadline=deadline
            sock=registry.factory((socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))) # no connect; guard validated.
            registry.close();assert sock.fileno()==-1
        trace.close()
        if trace.incomplete:diagnostic='FAIL_TRACE_INCOMPLETE'
        if name=='missing-evidence':diagnostic='FAIL_MISSING_EVIDENCE'
        if name!='control':assert diagnostic.startswith('FAIL')
        if name not in ('control','handler-error','thread-factory','thread-start','accept-callback','delegate-close-before','delegate-close-after','missing-evidence'):
            assert trace.incomplete
        if name in ('accept-callback','thread-factory','thread-start'):
            assert physical['dispatchAborted']==1 and physical['workersStarted']==0 and physical['workersReturned']==0
        if name=='registry-cap':assert physical['accepted']==64 and physical['rejected']==1
        if identityVerified is not None:assert identityVerified
        assert physical['requestSocketsLeft']==0 and physical['workerThreadsLeft']==0
        state={'physical':physical}
        if name!='missing-evidence':state['trace']=trace.summary()
        packet=json.dumps(state).encode();assert len(packet)<=4096
        gate=subprocess.run([sys.executable,'/poc/diagnostic_gate.py'],input=packet,stdout=subprocess.PIPE,
             stderr=subprocess.DEVNULL,timeout=max(.001,deadline-time.monotonic()),close_fds=True)
        expected=0 if name=='control' else 20
        assert gate.returncode==expected and gate.stdout.strip() in (b'DIAGNOSTIC_PASS',b'DIAGNOSTIC_FAIL')
        return {'case':name,'status':'PASS_FAULT_EXPECTATION','acceptedTCP':True,'sourceCalls':0,
          'cleanupByCandidate':True,'manualCleanupAfterMeasurement':False,'physical':physical,
          'diagnostic':diagnostic,'gateActualExit':gate.returncode,'gateScope':'LAB_NUMERIC_RECEIPT_ONLY','gateChildReaped':True,'sourceFileAccepted':False,
          'identityVerified':identityVerified,'trace':trace.summary(),'faultFired':io.fired,'deadlineRemaining':max(0,deadline-time.monotonic())}
    finally:
        if client:client.close()
        server.server_close();trace.close()

def legacy_reproduce(deadline):
    spec=importlib.util.spec_from_file_location('frozen_old_ownership','/prior/ownership.py')
    old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
    results=[]
    class WriteFailure:
        def write(self,*a):raise SECRET
        def flush(self):pass
        def close(self):pass
    for name in ('control','cap-close','io-shutdown'):
        trace=old.Trace(OUT/('legacy-'+name+'.jsonl'));owners=old.Requests(trace,deadline)
        Server=old.server_class(socketserver.ThreadingTCPServer,owners)
        server=Server(('127.0.0.1',0),socketserver.BaseRequestHandler)
        client=socket.create_connection(server.server_address,timeout=1);req,_=server.get_request();saved=None
        try:
            if name=='cap-close':
                ids=[uuid.uuid4().hex[:16] for _ in range(8)]
                for i in range(255):trace.emit(ids[i//32],'REGISTRY_CLOSE','END',fixtureFiller=True)
            if name=='io-shutdown':saved=trace.file;trace.file=WriteFailure()
            try:
                if name=='cap-close':server.close_request(req)
                else:server.shutdown_request(req)
            except (OSError,RuntimeError):pass
            left=req.fileno()!=-1
            assert left==(name!='control')
            results.append({'case':name,'requestFDLeft':left,'ownersClosed':owners.snapshot()['closed'],'incomplete':trace.incomplete,'manualRecoveryAfterMeasurement':True})
        finally:
            req.close();client.close();server.server_close();trace.close()
            if saved:saved.close()
    return {'case':'legacy-reproduce','status':'REPRODUCED_OLD_DEFECT','results':results,'sourceCalls':0,
       'ownershipSHA':hashlib.sha256(pathlib.Path('/prior/ownership.py').read_bytes()).hexdigest()}

def main_case(name,deadline):
    before=len(os.listdir('/proc/self/fd'))
    result=legacy_reproduce(deadline) if name=='legacy-reproduce' else fault_case(name.removeprefix('fault-'),deadline)
    result.update(fdBefore=before,fdAfter=len(os.listdir('/proc/self/fd')),threadsAtFinal=threading.active_count())
    assert result['fdBefore']==result['fdAfter'] and result['threadsAtFinal']==1
    (OUT/(name+'.json')).write_text(json.dumps(result,indent=2));print('PASS '+name,flush=True)
