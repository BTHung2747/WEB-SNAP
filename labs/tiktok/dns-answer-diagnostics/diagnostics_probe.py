"""Fresh schema/helper/IPC tests; fixed-label evidence, no source or private APIs."""
import asyncio,copy,hashlib,importlib.util,io,json,os,pathlib,signal,socket,subprocess,sys,threading,time
from unittest.mock import patch
from dns_counts import diagnostics_a,counts_valid,unknown_counts,endpoint_key
from dns_diagnostic import observe,validate_receipt
import dns_helper,test_diagnostics
OUT=pathlib.Path('/out');ROWS=[]
SECRET='FAKE_PATH_TOKEN?FAKE_QUERY_TOKEN=fixture_cookie'
def check(v,code):
    if not v:raise AssertionError(code)
def record(name,**v):ROWS.append(dict(case=name,status='PASS',**v))
def save(name,row):
    data=json.dumps(row,indent=2);check(SECRET not in data,'SANITIZED')
    with (OUT/name).open('x') as f:f.write(data)
def v4(ip='8.8.8.1'):return (socket.AF_INET,socket.SOCK_STREAM,6,'',(ip,443))
def v6(scope=0,flow=0):return (socket.AF_INET6,socket.SOCK_STREAM,6,'',('2001:4860:4860::8888',443,flow,scope))
def schemas():
    spec=importlib.util.spec_from_file_location('frozen_model','/frozen/model.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
    single=diagnostics_a([v4(),v4()],time.monotonic()+10);dual=diagnostics_a([v4(),v6()],time.monotonic()+10)
    over=diagnostics_a([v4()]*65,time.monotonic()+10)
    counter=[dict(dual,endpointCount=1,duplicateCount=1),dict(over,rawCount=0,rawCountMode='EXACT'),dict(over,rawCount=64,rawCountMode='EXACT'),dict(over,rawCount=None,rawCountMode='UNKNOWN')]
    for i,row in enumerate(counter):
        check(old.counts_valid(row) is True and counts_valid(row) is False,'REPRO_REJECT')
        record('audit_counterexample_'+str(i+1),frozenAccepted=True,successorAccepted=False,counts=row)
    for name,row in [('single',single),('dual',dual),('saturated',over),('empty',diagnostics_a([],time.monotonic()+10))]:
        check(counts_valid(row),'CONTROLS');record('schema_control_'+name,counts=row)
    for reason in ('DEADLINE','ROW_INVALID','IPC_CAP','MISSING'):
        for mode,raw in [('UNKNOWN',None),('EXACT',0),('EXACT',64),('AT_LEAST_65',65)]:
            expected=mode=='UNKNOWN' or mode=='EXACT' and reason in ('DEADLINE','ROW_INVALID')
            row=unknown_counts(reason,raw,mode);check(counts_valid(row) is expected,'TRUTH_TABLE')
            record('truth_'+reason+'_'+mode+'_'+str(raw),accepted=expected)
    for name,field,value in [('bool','rawCount',True),('sum','endpointCount',1),('family','ipv6Rows',2),('version','version',2),('huge','endpointCount',65536),('enum','reason',SECRET)]:
        row=dict(dual);row[field]=value;check(not counts_valid(row),'BAD_SCHEMA');record('schema_reject_'+name)
    for name,row in [('missing',{}),('extra',dict(dual,secret=SECRET)),('array',[]),('saturated_other_reason',dict(over,reason='DEADLINE'))]:
        check(not counts_valid(row),'EXACT_KEYS_MODE');record('schema_reject_'+name)
    with patch('dns_counts.endpoint_key',side_effect=AssertionError('NO_OVER_CAP_SCAN')):
        for size in (65,10000):check(diagnostics_a([v4()]*size,time.monotonic()+10)==over,'SATURATED')
    record('overflow_no_scan')
    for name,rows,count in [('scope',[v6(1),v6(2)],2),('flow',[v6(flow=1),v6(flow=2)],2),('protocol',[v4(),(2,1,0,'',v4()[4])],2),('port',[v4(),(2,1,6,'',('8.8.8.1',444))],2),('type',[v4(),(2,2,6,'',v4()[4])],2),('ipv6_text',[v6(),(10,1,6,'',('2001:4860:4860:0:0:0:0:8888',443,0,0))],1)]:
        check(diagnostics_a(rows,time.monotonic()+10)['endpointCount']==count,'KEY_FIELDS');record('key_'+name)
    for name,row in [('zone',(10,1,6,'',('2001:4860::8888%1',443,0,0))),('family',(2,1,6,'',v6()[4])),('scope_overflow',v6(4294967296)),('flow_overflow',v6(flow=1048576))]:
        check(diagnostics_a([row],time.monotonic()+10)['reason']=='ROW_INVALID','INVALID_KEY');record('key_reject_'+name)
    for name,ticks in [('before',[11]),('during',[0,11]),('after',[0,0,11])]:
        clock=iter(ticks);check(diagnostics_a([v4()],10,clock=lambda:next(clock))['reason']=='DEADLINE','COUNT_DEADLINE');record('scan_deadline_'+name)
def helper_function(name,rows,expected,exception=None):
    body=json.dumps(dict(mode='hostname',hostname='FAKE_NOT_RESOLVED',helperID='0123456789abcdef',deadline=time.monotonic()+10,addresses=[],blocked=[])).encode()
    inp=io.TextIOWrapper(io.BytesIO(body));buffer=io.BytesIO();stdout=io.TextIOWrapper(buffer)
    try:
        with patch('dns_helper.socket.getaddrinfo',**({'side_effect':socket.gaierror(SECRET)} if exception else {'return_value':rows})),patch.object(sys,'stdin',inp),patch.object(sys,'stdout',stdout):rc=dns_helper.main()
        packet=json.loads(buffer.getvalue());check(rc==0 and packet.get('code','OK')==expected,'HELPER_CODE')
        check(counts_valid(packet['counts']) and len(json.dumps(packet['counts']).encode())<=512,'BOUNDED_COUNTS')
        observation=observe(packet)
        if expected=='OK':
            check(packet['answers']==json.loads(json.dumps(rows)),'ORDER_UNCHANGED')
            from candidate import guard
            denied=False
            try:guard(packet['answers'])
            except (ValueError,TypeError,IndexError):denied=True
        else:denied=True;check(packet['answers']==[],'DISCARD_UNCHANGED')
        record(name,helperFunctionReturn=rc,helperCode=expected,counts=packet['counts'],observerEvidence=observation['evidence'],guardDenied=denied)
    finally:inp.close();stdout.close()
def helper_cases():
    helper_function('helper_raw64_unique64',[v4('8.8.8.'+str(i+1)) for i in range(64)],'OK')
    helper_function('helper_raw65_unique1',[v4()]*65,'ANSWER_CAP')
    helper_function('helper_raw65_unique65',[v4('8.8.8.'+str(i+1)) for i in range(65)],'ANSWER_CAP')
    helper_function('helper_dns_error',[],'DNS_ERROR',True)
    for kind,bad in [('private',v4('10.0.0.1')),('invalid',v4('FAKE_INVALID'))]:
        for size in (3,65):
            for pos in (0,size//2,size-1):
                rows=[v4()]*(size-1);rows.insert(pos,bad)
                helper_function('helper_'+kind+'_'+str(size)+'_'+str(pos),rows,'ANSWER_CAP' if size>64 else 'OK')
                check(ROWS[-1]['guardDenied'],'ALL_DNS_DENY')
async def wire_cases():
    from dns_ipc import resolve
    from ownership import Trace
    for mode in ('missing','family','helper','raw_mismatch','unknown','kill'):
        trace=Trace(OUT/('wire_'+mode+'.jsonl'));Trace.current=trace;row={};native_popen=subprocess.Popen;pids=[]
        fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
        count=diagnostics_a([v4()],time.monotonic()+10)
        answer=[v4(),v6()] if mode=='family' else [v4()]
        if mode=='family':count=dict(diagnostics_a(answer,time.monotonic()+10),endpointCount=1,duplicateCount=1)
        if mode=='raw_mismatch':count=dict(count,rawCount=2,duplicateCount=1,ipv4Rows=2)
        if mode=='unknown':count=dict(count,reason=SECRET)
        def spawn(argv,**kwargs):
            if mode!='kill':
                payload=dict(status='OK',answers=answer,unexpectedInherited=0,threads=1,counts=count)
                if mode=='missing':payload.pop('counts')
                if mode=='missing':
                    try:compile('value='+repr(payload),'FIXTURE','exec')
                    except SyntaxError:old_invalid=True
                    else:old_invalid=False
                    check(old_invalid,'OLD_FIXTURE_SYNTAX_REPRO')
                    save('fixture-repair-validation.json',dict(code='FIXTURE_INTENUM_REPR_SYNTAX_ERROR',oldCompileException='SyntaxError',runtimeChanged=False,sourceCalls=0))
                encoded='json.loads('+repr(json.dumps(payload))+')'
                code='import json,sys;obj=json.load(sys.stdin);value='+encoded+';value["helperID"]='+repr('e'*16)+';' if mode=='helper' else 'import json,sys;obj=json.load(sys.stdin);value='+encoded+';value["helperID"]=obj["helperID"];'
                code+='sys.stdout.write(json.dumps(value));sys.stdout.flush()'
                compile(code,'FIXTURE','exec')
                argv=[sys.executable,'-c',code]
            p=native_popen(argv,**kwargs);pids.append(p.pid)
            if mode=='kill':asyncio.get_running_loop().call_later(.03,os.killpg,p.pid,signal.SIGKILL)
            return p
        try:
            with patch('dns_ipc.subprocess.Popen',side_effect=spawn):
                try:await resolve(2 if mode=='kill' else 0,[v4()],time.monotonic()+10,row)
                except BaseException as exc:kind=type(exc).__name__
                else:raise AssertionError('WIRE_ACCEPTED')
            check(kind==('OSError' if mode=='kill' else 'DiagnosticIncomplete'),'WIRE_REJECT_CLASS')
        finally:trace.close();Trace.current=None
        check(row['dnsChildReaped'] and row['dnsPipesClosed'] and row['dnsGroupLeft']==0 and not any(pathlib.Path('/proc',str(pid)).exists() for pid in pids),'WIRE_CHILD_CLEAN')
        check(fd==len(os.listdir('/proc/self/fd')) and threads==threading.active_count(),'WIRE_FD_THREAD')
        check(not validate_receipt(row)['accepted'] and row['dnsDiagnostic']['resolution']=='FAIL','WIRE_NOT_PASS')
        save('wire_'+mode+'.json',dict(case=mode,exception=kind,receipt=row,trace=trace.summary(),sourceCalls=0,fdBefore=fd,fdAfter=len(os.listdir('/proc/self/fd'))))
        record('wire_'+mode,nativeExit=row['dnsExit'],resolution='FAIL',accepted=False)
async def ipc_cases():
    for name,kwargs in [('numeric',{}),('error',dict(mode='error',expected='OSError')),('deadline',dict(delay=2,budget=.25,expected='TimeoutError')),('cancel',dict(delay=2,cancel=True,expected='CancelledError')),('oversize',dict(mode='oversize',expected='ValueError')),('answers65',dict(mode='answer-oversize',expected='ValueError')),('child20',dict(mode='crash',expected='OSError')),('primary',dict(fault='raise',primary=True,expected='OSError')),('incomplete',dict(fault='missing',expected='DiagnosticIncomplete'))]:
        await test_diagnostics.dns_case('diag_ipc_'+name,**kwargs)
        row=test_diagnostics.RESULTS[-1];receipt=row['receipt']
        check(validate_receipt(receipt)['accepted']==(row['exception'] is None),'SAME_HELPER_V2')
        record('ipc_'+name,nativeExit=receipt['dnsExit'],resolution=receipt['dnsDiagnostic']['resolution'],accepted=validate_receipt(receipt)['accepted'],primaryIdentity=row['primaryIdentity'])
    base=copy.deepcopy(test_diagnostics.RESULTS[0]['receipt'])
    for name,mutate in [('missing',lambda r:r['dnsDiagnostic'].pop('counts')),('outer',lambda r:r['dnsCounts'].update(endpointCount=0)),('helper',lambda r:r.update(dnsHelperID='e'*16)),('exit',lambda r:r.update(dnsExit=20)),('reaped',lambda r:r.update(dnsChildReaped=False)),('cap',lambda r:r.update(answerCap=65)),('bool',lambda r:r['dnsDiagnostic']['counts'].update(rawCount=True)),('unknown',lambda r:r['dnsDiagnostic']['counts'].update(reason=SECRET))]:
        value=copy.deepcopy(base);mutate(value);before=copy.deepcopy(value);check(not validate_receipt(value)['accepted'] and value==before,'RECEIPT_CONFLICT_NOT_NORMALIZED');record('receipt_reject_'+name)
    changed=copy.deepcopy(base);changed['dnsElapsed']+=.123;check(validate_receipt(changed)['accepted'],'ELAPSED_NOT_EQUAL');record('receipt_elapsed_control')
def main():
    check(sys.version.split()[0]=='3.11.2' and os.getuid()==65534,'PINS');fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
    schemas();helper_cases();asyncio.run(ipc_cases());asyncio.run(wire_cases())
    check(fd==len(os.listdir('/proc/self/fd')) and threads==threading.active_count(),'CLEANUP')
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path('/integration').glob('*') if p.is_file()}
    save('result.json',dict(status='PASS_SCHEMA_FIX_AND_DIAGNOSTICS_A_OFFLINE',actualExit=0,cases=ROWS,caseCount=len(ROWS),counterexamplesRejected=4,fdBefore=fd,fdAfter=len(os.listdir('/proc/self/fd')),threadsBefore=threads,threadsAfter=threading.active_count(),sourceCalls=0,internetDNS=0,realClaims=0,helperProcesses=15,hashes=hashes,frozenModelSHA=hashlib.sha256(pathlib.Path('/frozen/model.py').read_bytes()).hexdigest(),findings='FIXED_PENDING_INDEPENDENT_REVIEW'))
    print('PASS_SCHEMA_DIAGNOSTICS_A cases='+str(len(ROWS)),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException as exc:
        if isinstance(exc,SystemExit):raise
        save('failure.json',dict(code='DIAGNOSTICS_PROBE_FAIL',actualExit=20,completedCases=len(ROWS),exception=type(exc).__name__ if type(exc).__name__ in ('AssertionError','ValueError','OSError','RuntimeError','TypeError','StopIteration') else 'UNKNOWN'))
        print('DIAGNOSTICS_PROBE_FAIL',flush=True);sys.exit(20)
