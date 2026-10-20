"""Fresh integration gate, not the predecessor research/schema matrices."""
import asyncio,copy,gc,hashlib,io,ipaddress,json,os,pathlib,socket,subprocess,sys,threading,time,tracemalloc
from unittest.mock import patch
import dns_counts as counts
import dns_helper as helper
import dns_inspection as ins
import dns_diagnostic as diag
import dns_ipc as ipc
from candidate import guard
from ownership import Trace,delegate_cleanup
OUT=pathlib.Path('/out');CASES=[]
def check(name,ok,**data):
    CASES.append(dict(case=name,status='PASS' if ok else 'FAIL',**data))
    if not ok:raise AssertionError('OFFLINE_GATE_FAILED')
def v4(n=1,host=None,proto=6):return (2,1,proto,'',(host or str(ipaddress.IPv4Address(0x08080000+n)),443))
def v6(n=1,proto=6,flow=0,scope=0):return (10,1,proto,'',(str(ipaddress.IPv6Address(0x26064700000000000000000000000000+n)),443,flow,scope))
def wire(rows,**kwargs):
    value,stop=helper.packet_rows(rows,time.monotonic()+9,**kwargs)
    value.update(version=3,helperID='a'*16,unexpectedInherited=0,threads=1)
    return value,stop
def receipt(value):
    d=diag.observe(value);d.update(elapsed=.1,nativeExit=0,reaped=True,pipesClosed=True,groupsLeft=0,resolution='PASS')
    return dict(dnsDiagnostic=d,dnsHelperID=d['helperID'],dnsCounts=copy.deepcopy(d['counts']),dnsInspection=copy.deepcopy(d['inspection']),
      dnsExit=0,dnsChildReaped=True,dnsPipesClosed=True,dnsGroupLeft=0,answerCap=64,inputBytes=20,responseBytes=100)
def clock(values):return iter(values).__next__
def functions():
    for name,rows,raw,endpoints in [('64',[v4()]*64,64,1),('65dup',[v4()]*65,65,1),('65unique',[v4(i) for i in range(1,66)],65,65),
      ('mixed70',[v4(),v4(proto=0),v6(),v6(proto=0),v6(flow=1),v6(scope=1),v6(flow=1,scope=1)]*10,70,7),('256',[v6(i) for i in range(1,257)],256,256)]:
        value,stop=wire(rows);d=diag.observe(value);i=d['inspection']
        check('producer_'+name,d['evidence']=='COMPLETE' and (i is None if raw==64 else (i['evidence']=='COMPLETE' and i['endpointCount']==endpoints and i['rawCount']==raw) or (raw==256 and i['reason']=='DEADLINE' and i['endpointCount'] is None)),
          responseCode=value['code'],inspection=i,combinedBytes=len(ins.stats_bytes(value['counts'],i)))
        check('refusal_'+name,(value['code']=='OK' and diag.validate_receipt(receipt(value))['accepted']) if raw==64 else
          value['code']=='ANSWER_CAP' and value['answers']==[] and not diag.validate_receipt(receipt(value))['accepted'])
    with patch('dns_inspection.endpoint_key',side_effect=AssertionError()):
        for size in (257,10000):
            value,stop=wire([v4()]*size);i=value['inspection']
            check('overbound_'+str(size),i['reason']=='INSPECTION_BOUND' and i['rawCount']==257 and i['endpointCount'] is None and value['code']=='ANSWER_CAP')
    for size in (64,65,256):
        for position in sorted(set((0,size//2,64 if size>64 else 63,size-1))):
            for kind in ('private','invalid'):
                rows=[v4()]*size;rows[position]=v4(host='10.0.0.1' if kind=='private' else 'INVALID')
                denied=False
                try:guard(rows)
                except ValueError:denied=True
                value,stop=wire(rows);i=value['inspection']
                check(f'guard_{size}_{position}_{kind}',denied and (i is None if size==64 else
                  i['publicState']=='HAS_NON_GLOBAL' if kind=='private' else i['reason']=='ROW_INVALID' and i['endpointCount'] is None))
    value,stop=wire([]);check('empty_guard',value['inspection'] is None and value['counts']['rawCount']==0 and not diag.validate_receipt(receipt(value))['accepted'])
    for name,kwargs in [('allocator',dict(inspector=lambda *a,**k:(_ for _ in ()).throw(MemoryError()))),('observer',dict(inspector=lambda *a,**k:(_ for _ in ()).throw(OSError())))]:
        value,stop=wire([v4()]*65,**kwargs);check('optional_'+name,value['code']=='ANSWER_CAP' and value['answers']==[] and value['inspection']['reason']==('MEMORY_BOUND' if name=='allocator' else 'MISSING'))
    value,stop=wire([v4()]*65,inspector=lambda rows,stop,**kw:ins.inspect(rows,stop,key_limit=64))
    check('retained_exhausted',value['code']=='ANSWER_CAP' and value['inspection']['reason']=='MEMORY_BOUND')
    for name,ticks in [('before',[2]),('mid',[0,0,2]),('after',[0]+[0]*65+[2])]:
        i=ins.inspect([v4()]*65,1,clock=clock(ticks));check('deadline_'+name,i['reason']=='DEADLINE' and i['rawCount'] is None and i['endpointCount'] is None)
    # Production encoding path, including delayed encoder and pre-write rechecks.
    value,stop=wire([v4()]*65)
    data=helper.encoded(copy.deepcopy(value),10,1,clock=clock([0,0,0,2,2,2]))
    check('late_encode_discards_counts',json.loads(data)['inspection']['reason']=='DEADLINE' and json.loads(data)['code']=='ANSWER_CAP')
    value,stop=wire([v4()]*65);written=[]
    rc=helper.deliver(copy.deepcopy(value),10,1,clock=clock([0,0,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2]),writer=written.append)
    check('late_prewrite_discards_counts',rc==0 and json.loads(written[0])['inspection']['reason']=='DEADLINE')
    check('absolute_no_spawn_write',helper.deliver(copy.deepcopy(value),1,1,clock=lambda:2,writer=lambda d:check('never',False))==20)
    calls=0
    def encoder(v):
        nonlocal calls
        calls+=1
        if calls==1:raise MemoryError()
        return json.dumps(v,separators=(',',':')).encode()
    data=helper.encoded(copy.deepcopy(value),time.monotonic()+9,stop,encoder=encoder)
    check('encode_memory_primary',json.loads(data)['code']=='ANSWER_CAP' and json.loads(data)['inspection']['reason']=='MEMORY_BOUND')
    check('ipc_encode_cap',helper.encoded(copy.deepcopy(value),time.monotonic()+9,stop,encoder=lambda v:b'X'*32769) is None)
    # Real helper.main public resolver injection, bounded stdin/stdout actual serialization.
    for name,side,expected in [('gaierror',socket.gaierror(),'DNS_ERROR'),('memory',MemoryError(),'DNS_ERROR')]:
        output=io.BytesIO();body=json.dumps(dict(deadline=time.monotonic()+9,helperID='a'*16,mode='hostname',hostname='FAKE',addresses=[])).encode()
        class Stream:
            def __init__(self,b):self.buffer=b
        with patch('dns_helper.sys.stdin',Stream(io.BytesIO(body))),patch('dns_helper.sys.stdout',Stream(output)),patch('dns_helper.socket.getaddrinfo',side_effect=side):native=helper.main()
        w=json.loads(output.getvalue());check('helper_main_'+name,native==0 and w['code']==expected and w['counts']['rawCount'] is None and w['inspection'] is None and diag.observe(w)['evidence']=='COMPLETE',actualFunctionExit=native)
    value,stop=wire([v4()]*65);baseline=value['inspection']
    for field,bad in [('version',True),('version',2),('rawCount',64),('rawCount',65.0),('rawCount',float('nan')),('rawCountMode','UNKNOWN'),
      ('evidence','PARTIAL'),('endpointCount',0),('duplicateCount',0),('ipv6Rows',1),('publicState','UNKNOWN'),('policy','B'),('reason','UNKNOWN')]:
        v=copy.deepcopy(value);v['inspection'][field]=bad;check('schema_'+field+'_'+str(len(CASES)),diag.observe(v)['evidence']=='PARTIAL')
    for name in ('extra','missing','bad-id','wrong-version','ok-with-inspection','cap-with-null','cap-with-answers'):
        v=copy.deepcopy(value)
        if name=='extra':v['inspection']['extra']=0
        elif name=='missing':v.pop('inspection')
        elif name=='bad-id':v['helperID']='bad'
        elif name=='wrong-version':v['version']=2
        elif name=='ok-with-inspection':v.update(status='OK',code='OK')
        elif name=='cap-with-null':v['inspection']=None
        elif name=='cap-with-answers':v['answers']=[v4()]
        check('wire_'+name,diag.observe(v)['evidence']=='PARTIAL')
    for reason in ('DEADLINE','MEMORY_BOUND','ENCODE_CAP','IPC_CAP','MISSING'):
        v=copy.deepcopy(value);v['inspection']=ins.partial(reason)
        check('partial_truth_'+reason,diag.observe(v)['evidence']=='COMPLETE' and not diag.validate_receipt(receipt(v))['accepted'])
    value,stop=wire([v4()]);normal=receipt(value)
    for field,bad in [('dnsHelperID','e'*16),('dnsCounts',{}),('dnsInspection',{}),('dnsExit',20),('dnsChildReaped',False),('dnsPipesClosed',False),('dnsGroupLeft',1),('answerCap',65)]:
        v=copy.deepcopy(normal);v[field]=bad;check('receipt_'+field,not diag.validate_receipt(v)['accepted'])
    trace=[dict(ownerID='a'*16,phase='DNS_HELPER',event='BEGIN',inputBytes=20),dict(ownerID='a'*16,phase='DNS_HELPER',event='END',responseBytes=100,nativeExit=0,childReaped=True)]
    check('trace_control',diag.validate_receipt(normal,trace)['accepted'])
    for name,t in [('reverse',trace[::-1]),('missing',trace[:1]),('duplicate',trace+[trace[1]]),('native',[trace[0],dict(trace[1],nativeExit=20)]),('owner',[trace[0],dict(trace[1],ownerID='e'*16)])]:
        check('trace_link_'+name,not diag.validate_receipt(normal,t)['accepted'])
    # Combined encoding uses the RUNTIME function for all legal partial enum variants.
    c=counts.unknown_counts('RAW_CAP',65,'AT_LEAST_65');variants=[ins.partial(x) for x in ('DEADLINE','MEMORY_BOUND','ENCODE_CAP','IPC_CAP','MISSING')]
    variants.extend([ins.partial('INSPECTION_BOUND',257,'AT_LEAST_257'),ins.partial('ROW_INVALID',256,'EXACT')])
    max_partial=max(len(ins.stats_bytes(c,x)) for x in variants)
    syntactic=dict(baseline,rawCount=256,endpointCount=256,duplicateCount=256,ipv4Rows=256,ipv6Rows=256,publicState='HAS_NON_GLOBAL')
    check('combined_runtime_encoding',max_partial==469 and len(ins.stats_bytes(c,syntactic))==452 and max_partial<=512,partialMax=max_partial,syntacticComplete=452)
    # Beyond512 is refused by producer and observer; no silent object normalization by observer.
    bad=wire([v4()]*65)[0];bad['inspection']['reason']='X'*600
    check('stats_oversize_rejected',diag.observe(bad)['evidence']=='PARTIAL' and len(ins.stats_bytes(bad['counts'],bad['inspection']))>512)
    samples=[]
    for n in range(3):
        rows=[v6(i,proto=2147483647,flow=1048575,scope=4294967295) for i in range(1,257)];gc.collect();tracemalloc.start();start=time.monotonic();measure={}
        stats=ins.inspect(rows,start+.25,measured=measure);elapsed=time.monotonic()-start;_,peak=tracemalloc.get_traced_memory();tracemalloc.stop()
        check('pressure_'+str(n),ins.valid(stats) and (stats['evidence']=='COMPLETE' or stats['reason']=='DEADLINE' and stats['endpointCount'] is None),elapsed=elapsed,peak=peak,charge=measure.get('retained'),evidence=stats['evidence'])
        samples.append(dict(elapsed=elapsed,peak=peak,charge=measure.get('retained'),evidence=stats['evidence']))
    return samples
async def children():
    reports=[];original=subprocess.Popen
    modes=['numeric','answer-oversize','error','oversize','crash','deadline','cancel','sigkill','trace-error','wire-incomplete','wire-disjoint','late-receive']
    for mode in modes:
        trace=Trace(OUT/(mode+'.jsonl'));Trace.current=trace;r={};caught=None
        if mode=='trace-error':trace.emit=lambda *a,**k:(_ for _ in ()).throw(OSError())
        kwargs={'mode':mode if mode in ('numeric','answer-oversize','error','oversize','crash') else 'numeric'}
        delay=10 if mode in ('deadline','cancel','sigkill') else 0;deadline=time.monotonic()+(.12 if mode=='deadline' else 2)
        def fixture_popen(args,**kw):
            return original([sys.executable,'/integration/wire_fixture.py',mode],**kw)
        context=patch('dns_ipc.subprocess.Popen',side_effect=fixture_popen) if mode in ('wire-incomplete','wire-disjoint','late-receive') else patch('dns_ipc.subprocess.Popen',wraps=original)
        with context:
            task=asyncio.create_task(ipc.resolve(delay,[v4()],deadline,r,**kwargs))
            if mode in ('cancel','sigkill'):
                while 'dnsPID' not in r:await asyncio.sleep(.001)
                if mode=='cancel':task.cancel()
                else:os.killpg(r['dnsPID'],9)
            try:await task
            except BaseException as exc:caught=type(exc).__name__
        trace.close();Trace.current=None
        success=mode=='numeric'
        closure=r.get('dnsChildReaped') and r.get('dnsPipesClosed') and r.get('dnsGroupLeft')==0
        check('child_'+mode,closure and (caught is None and r['dnsDiagnostic']['resolution']=='PASS' if success else caught is not None and r['dnsDiagnostic']['resolution']=='FAIL'),
          errorClass=caught,nativeExit=r.get('dnsExit'),inspection=r.get('dnsInspection'),traceIncomplete=trace.incomplete)
        reports.append(dict(case=mode,receipt=r,errorClass=caught))
    primary=OSError();seen=[];got=None
    try:delegate_cleanup(lambda:(_ for _ in ()).throw(primary),lambda:(_ for _ in ()).throw(RuntimeError()),lambda error:seen.append(type(error).__name__))
    except BaseException as exc:got=exc
    check('primary_identity_cleanup',got is primary and len(seen)==1)
    return reports
def main():
    fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count();samples=functions();reports=asyncio.run(children())
    check('closure',len(os.listdir('/proc/self/fd'))==fd and threading.active_count()==threads,fdBefore=fd,fdAfter=len(os.listdir('/proc/self/fd')),threadsBefore=threads,threadsAfter=threading.active_count())
    paths=['/integration/'+p.name for p in pathlib.Path('/integration').iterdir() if p.is_file()]
    paths+=[socket.__file__,ipaddress.__file__]
    hashes=[dict(path=p,sha256=hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()) for p in sorted(paths)]
    check('actual_stdlib',hashlib.sha256(pathlib.Path(ipaddress.__file__).read_bytes()).hexdigest()=='8fc7549ef3ea782afc6dd9215e61baa72c8cf1047399bf60c221241f5f5355e1')
    result=dict(status='PASS_OFFLINE_HELPER_IPC_OBSERVER_V3',actualExit=0,caseCount=len(CASES),cases=CASES,children=reports,samples=samples,hashes=hashes,sourceCalls=0,claims=0,internetDNS=0)
    (OUT/'result.json').write_text(json.dumps(result,indent=2));print(json.dumps(dict(status=result['status'],actualExit=0,caseCount=len(CASES))))
if __name__=='__main__':
    try:main()
    except BaseException as exc:
        (OUT/'failure.json').write_text(json.dumps(dict(actualExit=20,errorClass=type(exc).__name__,cases=CASES),indent=2));sys.exit(20)
