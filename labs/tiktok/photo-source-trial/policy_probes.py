"""Fresh offline policy/coverage/admission faults, separate from78 inherited contracts."""
import asyncio,copy,json,os,pathlib,subprocess,sys,threading,time,uuid
from common import inventory,versions
from batch_tests import policies,run_batch,native_operation
from ownership import Trace,FileOps
from operation_coverage import operation_coverage
from candidate import Sockets,setup
OUT=pathlib.Path('/out')
def failure(kind,value,tb):
    allowed={AssertionError:'ASSERT',RuntimeError:'RUNTIME',ValueError:'VALUE',TimeoutError:'TIMEOUT',OSError:'IO',KeyError:'KEY',AttributeError:'ATTRIBUTE',ImportError:'IMPORT'}
    line=0
    while tb:line=tb.tb_lineno;tb=tb.tb_next
    (OUT/'probe-failure.json').write_text(json.dumps({'code':allowed.get(kind,'UNKNOWN'),'line':line,'sourceCalls':0}));print('POLICY_PROBE_FAIL',flush=True)
sys.excepthook=failure
def admission_probes():
    cases=[]
    for label,count in [('owner_below',3),('owner_at',4),('owner_above',5)]:
        trace=Trace(OUT/(label+'.jsonl'));ctx='a'*16;reg='b'*16;assert trace.attach_connection(reg,ctx)
        accepted=[]
        for i in range(count):
            value=trace.admit_group(reg,ctx,2);accepted.append(value)
            if not value:break
            # Materialize every reserved event; operations contain distinct indices.
            trace.observe(reg,'LIBRARY_SELECT','BEGIN',code='BEGIN')
            for _ in range(2):
                for event in ('BEGIN','ERROR'):trace.observe(reg,'SOCKET_CREATE',event,code='BEGIN' if event=='BEGIN' else 'ERROR')
                for event in ('BEGIN','ERROR'):trace.observe(ctx,'TCP_CONNECT',event,code='BEGIN' if event=='BEGIN' else 'ERROR',index=2*i+_+1)
            trace.observe(reg,'LIBRARY_SELECT','ERROR',code='ERROR');trace.release_group(reg,ctx)
        assert accepted==([True]*count if count<=4 else [True]*4+[False])
        trace.close();cases.append({'case':label,'acceptedGroups':accepted,'sourceCalls':0})
    trace=Trace(OUT/'atomic.jsonl')
    for i in range(16):
        for _ in range(7):
            for event in ('BEGIN','END'):trace.observe(str(i).zfill(16),'SERVER_SERVE_CLOSE',event,code='BEGIN' if event=='BEGIN' else 'OK')
    barrier=threading.Barrier(3);results=[]
    def reserve(i):
        barrier.wait();reg=str(20+i).zfill(16);ctx=str(30+i).zfill(16)
        with trace.lock:
            result=trace.attach_connection(reg,ctx) and trace.admit_group(reg,ctx,2)
        results.append(result)
    workers=[threading.Thread(target=reserve,args=(i,)) for i in range(2)]
    for w in workers:w.start()
    barrier.wait()
    for w in workers:w.join(2);assert not w.is_alive()
    assert sum(results)==1 and trace.count+trace.summary()['reservedRows']<=256
    cases.append({'case':'atomic_concurrent_global','accepted':results,'rows':trace.count,'reserved':trace.summary()['reservedRows'],'cap':256,'sourceCalls':0})
    trace.release_group('0'*14+'20','0'*14+'30');trace.release_group('0'*14+'21','0'*14+'31');trace.close()
    for label,limit in [('owner_map',64)]:
        trace=Trace(OUT/(label+'.jsonl'))
        for i in range(limit):trace.observe(str(i).zfill(16),'REQUEST_ACCEPT','END')
        assert not trace.attach_connection('a'*16,'b'*16);trace.close();cases.append({'case':label,'existingOwners':64,'admission':False,'sourceCalls':0})
    return cases

def coverage_faults():
    phases=['SOCKET_CREATE','LIBRARY_SELECT','REGISTRY_CLOSE','TCP_CONNECT','DNS_HELPER']
    cases=[]
    for phase in phases:
        good=[{'ownerID':'a'*16,'phase':phase,'event':'BEGIN','operationIndex':1},{'ownerID':'a'*16,'phase':phase,'event':'END','operationIndex':1}]
        for label,rows,expected in [('control',good,0),('missing_begin',good[1:],20),('missing_terminal',good[:1],20),('terminal_before_begin',list(reversed(good)),20),('duplicate_terminal',good+[good[1]],20),('reopen',good+[good[0]],20)]:
            rc=native_operation(rows,False,0);assert rc==expected;cases.append({'case':phase+'_'+label,'nativeExit':rc,'coverage':operation_coverage(rows),'sourceCalls':0})
    return cases

def io_faults():
    cases=[]
    class Fault(FileOps):
        def __init__(self,where):self.where=where
        def open(self,p):
            if self.where=='open':raise OSError('FIXTURE_IO')
            return super().open(p)
        def write(self,f,s):
            if self.where=='write':raise OSError('FIXTURE_IO')
            return super().write(f,s)
        def flush(self,f):
            if self.where=='flush':raise OSError('FIXTURE_IO')
            return super().flush(f)
        def close(self,f):
            if self.where=='close':raise OSError('FIXTURE_IO')
            return super().close(f)
    for name in ('open','write','flush','close'):
        r=run_batch('trace_io_'+name,'first_winner',2,2.2,Fault(name))
        assert r['socketsLeft']==0 and r['diagnosticGateActualExit']==20 and r['connectorGateActualExit']==20
        cases.append(r)
    return cases

def dns_budget():
    from proxy_entry import SourceLoop
    import types,socket
    cases=[]
    for delay in (0,.35):
        trace=Trace(OUT/('dns-'+str(delay)+'.jsonl'));old=Trace.current;Trace.current=trace;registry=Sockets()
        ctx=types.SimpleNamespace(cid=uuid.uuid4().hex[:16],end=time.monotonic()+1.4,trace=trace,registry=registry)
        loop=SourceLoop(ctx);r={};code=None
        async def call():
            nonlocal code
            try:await setup([(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443)),(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.2',443))],delay,registry,r,loop=loop,budget=1.4)
            except Exception as e:code=getattr(e,'code','SETUP_DEADLINE' if isinstance(e,TimeoutError) else 'UNKNOWN')
        try:loop.run_until_complete(call())
        finally:registry.close();trace.close();loop.close();Trace.current=old
        expected='SETUP_DEADLINE' if registry.remaining_at_admission is None else 'TCP_BUDGET_EXHAUSTED'
        (OUT/('dns-'+str(delay)+'-receipt.json')).write_text(json.dumps({'code':code,'expectedPhaseCode':expected,'remainingAtTCP':registry.remaining_at_admission,'dns':r,'sourceCalls':0}))
        assert code==expected and not registry.order and r['dnsChildReaped'] and r['dnsPipesClosed'] and r['dnsGroupLeft']==0
        cases.append({'case':'dns_remaining_floor_'+str(delay),'code':code,'attempts':0,'dns':r,'sourceCalls':0})
    return cases

def main():
    fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
    p=policies();a=admission_probes();c=coverage_faults();i=io_faults();d=dns_budget()
    before=time.monotonic()
    child=subprocess.run([sys.executable,'/integration/containment_fixture.py'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=3,start_new_session=True,close_fds=True)
    assert child.returncode==30
    containment={'case':'blocked_loop_independent_watchdog','actualExit':child.returncode,'elapsed':time.monotonic()-before,'closure':'PROCESS_CONTAINMENT','sourceCalls':0}
    assert fd==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    result={'status':'PASS_BATCH_POLICY_OFFLINE','actualExit':0,'sourceCalls':0,'policies':p,'admission':a,'coverageFaults':c,'ioFaults':i,'dnsBudgets':d,'containment':containment,'newCases':len(p)+len(a)+len(c)+len(i)+len(d)+1,'fdBefore':fd,'fdAfter':len(os.listdir('/proc/self/fd')),'threadsBefore':threads,'threadsAfter':threading.active_count(),'runtime':{'python':sys.version.split()[0],'versions':versions(),'sources':inventory()}}
    (OUT/'probe-result.json').write_text(json.dumps(result,indent=2));print('PASS fresh policy gates; source0',flush=True);return 0
if __name__=='__main__':sys.exit(main())
