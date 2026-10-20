"""Offline probes: real owned helper processes, numeric-only resolver, synthetic IPC faults."""
import asyncio,contextlib,copy,hashlib,json,os,pathlib,socket,subprocess,sys,threading,time
from unittest.mock import patch
from common import inventory,versions,stage_policy
from dns_ipc import resolve,identity
from dns_diagnostic import valid as dns_valid
from ownership import Trace,FileOps,DiagnosticIncomplete
from receipt_labels import labels,valid as receipt_valid

OUT=pathlib.Path('/out');RESULTS=[]
INFO=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]
SECRET='FAKE_PATH_TOKEN?FAKE_QUERY_TOKEN=fixture_cookie'
def save(name,row):
    encoded=json.dumps(row)
    assert SECRET not in encoded and 'FAKE_PATH_TOKEN' not in encoded
    with (OUT/name).open('x') as f:f.write(encoded)
def check(value,code):
    if not value:raise AssertionError(code)
def receipts():
    with patch.dict(os.environ,{'WHOLEPHOTO_STAGE':'source'}):
        try:stage_policy()
        except RuntimeError:pass
        else:raise AssertionError('SOURCE_ENTRY_NOT_BLOCKED')
    RESULTS.append(dict(case='source_python_entry_blocked',status='PASS',sourceInvoked=False))
    for stage in ('source','offline'):
        for started in (False,True):
            row=labels(stage,started)
            check(receipt_valid(row,stage),'LABEL_VALID')
            check(row['sourceAnalyzeAttempts']==int(stage=='source' and started),'SOURCE_INVOCATION')
            check(row['analyzeInvocations']==int(started),'ACTUAL_INVOCATION')
            if stage=='source':check(row['sourceCalls']=='UNKNOWN_USE_REQUEST_ACCOUNTING','SOURCE_UNKNOWN')
            RESULTS.append(dict(case=stage+('_started' if started else '_not_started'),status='PASS',receipt=row))
    raw=pathlib.Path('/historical/result.json').read_bytes();old=json.loads(raw)
    check(not receipt_valid(old,'source'),'HISTORICAL_CONTRADICTION')
    revised=copy.deepcopy(old);revised.update(labels('source',True))
    check(receipt_valid(revised,'source'),'COPY_LABEL_VALID')
    for key in ('stage','status','error','workerActualExit','workerSignal','requestAccounting','metadataPacket'):
        check(revised[key]==old[key],'PRIMARY_PRESERVED')
    save('historical-relabelled-copy.json',dict(syntheticRelabelOnly=True,sourceInvoked=False,
         originalSHA=hashlib.sha256(raw).hexdigest(),receipt=revised))
    check(hashlib.sha256(pathlib.Path('/historical/result.json').read_bytes()).hexdigest()==hashlib.sha256(raw).hexdigest(),'RAW_UNCHANGED')
    RESULTS.append(dict(case='historical_raw_copy_rejected_then_relabelled',status='PASS',sourceInvoked=False))
    for key,value in [('source',False),('fixture',True),('sourceCalls',0),('sourceAnalyzeAttempts',0),('analyzeInvocations',True)]:
        row=labels('source',True);row[key]=value
        check(not receipt_valid(row,'source'),'CONTRADICTORY_LABEL_DENIED')
        RESULTS.append(dict(case='label_conflict_'+key,status='PASS'))

class WriteFault(FileOps):
    def write(self,file,text):raise OSError(SECRET)
class RaiseTrace(Trace):
    def emit(self,*a,**k):raise OSError(SECRET)

async def dns_case(name,mode='numeric',payload=None,expected=None,fault=None,delay=0,budget=10,cancel=False,primary=False):
    fd_before=len(os.listdir('/proc/self/fd'));threads_before=threading.active_count()
    trace=(RaiseTrace if fault=='raise' else Trace)(OUT/(name+'.jsonl'),io=WriteFault() if fault=='write' else None)
    Trace.current=None if fault=='missing' else trace
    row={};actual=None;exception_object=None;started=time.monotonic();child_pids=[]
    native_popen=subprocess.Popen
    sentinel=OSError(SECRET)
    def spawn(argv,**kwargs):
        if payload is not None:
            # Fixture-only delegation to public Popen, original ownership flags untouched.
            argv=[sys.executable,'-c','import sys;sys.stdin.buffer.read();sys.stdout.buffer.write('+repr(payload)+');sys.stdout.buffer.flush()']
        p=native_popen(argv,**kwargs);child_pids.append(p.pid);return p
    idle_stop=threading.Event();idle=threading.Thread(target=idle_stop.wait);idle.start()
    a,b=socket.socketpair();os.set_inheritable(a.fileno(),True)
    try:
        with patch('dns_ipc.subprocess.Popen',side_effect=spawn), (patch('candidate.guard',side_effect=sentinel) if primary else contextlib.nullcontext()):
            task=asyncio.create_task(resolve(delay,INFO,time.monotonic()+budget,row,mode=mode,blocked=[identity(a.fileno())]))
            if cancel:asyncio.get_running_loop().call_later(.05,task.cancel)
            try:
                answers=await task;check(len(answers)==1,'ONE_ANSWER')
            except BaseException as error:
                actual=type(error).__name__;exception_object=error
        check(actual==expected,'EXCEPTION_CLASS_'+name)
        if primary:check(exception_object is sentinel,'PRIMARY_EXCEPTION_IDENTITY')
    finally:
        a.close();b.close();idle_stop.set();idle.join(1);trace.close();Trace.current=None
    check(row.get('dnsChildReaped') is True and row.get('dnsPipesClosed') is True and row.get('dnsGroupLeft')==0,'HELPER_CLEANUP')
    check(all(not pathlib.Path('/proc',str(pid)).exists() for pid in child_pids),'NO_CHILD_LEFT')
    check(len(os.listdir('/proc/self/fd'))==fd_before and threading.active_count()==threads_before,'FD_THREAD_BASELINE')
    check(row['inheritanceClean'] if 'inheritanceClean' in row else True,'NO_INHERITED_SOCKET')
    if actual is None:check(dns_valid(row['dnsDiagnostic']),'DNS_PASS_DIAGNOSTIC')
    else:check(not dns_valid(row['dnsDiagnostic']),'DNS_FAILURE_NOT_PASS')
    if fault:check(row['dnsDiagnostic']['evidence']=='PARTIAL','TRACE_PARTIAL')
    check(time.monotonic()-started < budget+1,'ABSOLUTE_DEADLINE')
    record=dict(case=name,status='PASS',exception=actual,primaryIdentity=(exception_object is sentinel) if primary else None,
                receipt=row,trace=trace.summary(),fdBefore=fd_before,fdAfter=len(os.listdir('/proc/self/fd')),
                threadsBefore=threads_before,threadsAfter=threading.active_count(),upstreamSockets=0,sourceCalls=0)
    save(name+'.json',record);RESULTS.append(record)

async def dns_tests():
    await dns_case('dns_numeric_ok')
    await dns_case('dns_getaddrinfo_error',mode='error',expected='OSError')
    await dns_case('dns_answer_cap',mode='answer-oversize',expected='ValueError')
    await dns_case('dns_child_exit',mode='crash',expected='OSError')
    await dns_case('dns_response_cap',mode='oversize',expected='ValueError')
    await dns_case('dns_absolute_deadline',delay=2,budget=.25,expected='TimeoutError')
    await dns_case('dns_cancel',delay=2,cancel=True,expected='CancelledError')
    def encoded(value):return json.dumps(value).encode()
    base=dict(status='ERROR',code='DNS_ERROR',answers=[],unexpectedInherited=0,threads=1)
    for name,value,expected in [
        ('dns_error_response',base,'OSError'),
        ('dns_answer_cap_response',dict(base,code='ANSWER_CAP'),'OSError'),
        ('dns_deadline_response',dict(base,code='DEADLINE'),'TimeoutError'),
        ('dns_unknown_code',dict(base,code=SECRET),'OSError'),
        ('dns_secret_thread_field',dict(base,threads=SECRET),'OSError'),
        ('dns_missing_status',dict(answers=[],unexpectedInherited=0,threads=1),'OSError'),
        ('dns_wrong_type',[SECRET],'AttributeError'),
        ('dns_unknown_ok_code',dict(base,status='OK',code=SECRET,answers=INFO),'DiagnosticIncomplete')]:
        await dns_case(name,payload=encoded(value),expected=expected)
    await dns_case('dns_malformed_json',payload=b'{'+SECRET.encode(),expected='JSONDecodeError')
    await dns_case('dns_missing_response',payload=b'',expected='JSONDecodeError')
    await dns_case('dns_trace_write_failure',fault='write',expected='DiagnosticIncomplete')
    await dns_case('dns_trace_raise_primary',fault='raise',primary=True,expected='OSError')
    await dns_case('dns_missing_trace',fault='missing',expected='DiagnosticIncomplete')
    for key,value in [('nativeExit',True),('reaped',False),('answerCount',65),('responseCode','UNKNOWN'),('evidence','PARTIAL')]:
        good=next(r for r in RESULTS if r['case']=='dns_numeric_ok')['receipt']['dnsDiagnostic']
        bad=dict(good);bad[key]=value
        check(not dns_valid(bad),'DIAGNOSTIC_CONFLICT_REJECT')
        RESULTS.append(dict(case='diagnostic_conflict_'+key,status='PASS'))
    check(not dns_valid(None) and not dns_valid({}),'MISSING_DIAGNOSTIC_REJECT')
    RESULTS.append(dict(case='diagnostic_missing_rejected',status='PASS'))

def main():
    check(sys.version.split()[0]=='3.11.2','PYTHON_PIN')
    receipts();asyncio.run(dns_tests())
    for path in OUT.glob('dns_*.json*'):
        text=path.read_text()
        check(all(secret not in text for secret in (SECRET,'FAKE_PATH_TOKEN','fixture_cookie','1.1.1.1','https://')),'REDACTION')
    save('diagnostics-result.json',dict(status='PASS_OFFLINE_RECEIPT_DNS',actualExit=0,cases=len(RESULTS),results=RESULTS,
         versions=versions(),python=sys.version.split()[0],sources=inventory(),sourceCalls=0,internetDNS=0,claimActions=0))
    print('PASS_OFFLINE_RECEIPT_DNS cases='+str(len(RESULTS)),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException as error:
        if isinstance(error,SystemExit):raise
        save('diagnostics-failure.json',dict(code='OFFLINE_PROBE_FAIL',completedCases=len(RESULTS),
             exception=type(error).__name__ if type(error).__name__ in ('AssertionError','OSError','ValueError','RuntimeError') else 'UNKNOWN'))
        print('OFFLINE_PROBE_FAIL',flush=True);sys.exit(20)
