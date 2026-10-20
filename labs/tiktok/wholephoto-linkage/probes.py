"""Narrow offline probes: V2 accounting, delegated TCP identities, unchanged batching."""
import asyncio,copy,hashlib,json,os,pathlib,socket,subprocess,sys,threading,time,types,uuid
from accounting import receipt
from tcp_observer import coverage
from proxy_entry import SourceLoop
from offline_glue import OfflineLoop
from candidate import Sockets,connect
from common import inventory,versions
OUT=pathlib.Path('/out');sys.excepthook=lambda *a:print('DIAGNOSTIC_PROBE_FAIL',flush=True)
def row(p,i,rid,code='HTTP_RESPONSE',status=200,conn='b'*16):
    r={'phase':p,'index':i,'method':'GET','url':'[url-redacted]','decodedBytes':7 if status else 0,
       'boundaries':{'requestID':rid,'connectionID':conn,'incomplete':False},'sendDiagnostic':{'code':code}}
    if status:r['status']=status
    return r
def events(rid,p='metadata',setup=False,fail=False):
    names=['CONNECTION_SETUP'] if fail else (['CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS'] if setup else ['REQUEST_SEND','RESPONSE_HEADERS'])
    return [{'requestID':rid,'phase':p,'boundary':name,'event':event} for name in names for event in ('BEGIN','ERROR' if fail else 'END')]
def accounting_probes():
    rows=[row('metadata',1,'1'*16),row('metadata',2,'2'*16),row('prepare',1,'3'*16,'PROXY_ERROR',None)]
    result={'stage':'prepare','metadataPacket':{'status':'PASS','rows':copy.deepcopy(rows[:2])},'preparePacket':{'status':'FAIL','rows':copy.deepcopy(rows)}}
    ev=events('1'*16,setup=True)+events('2'*16)+events('3'*16,'prepare',fail=True)
    cases=[]
    def run(name,r,e=ev,present=True,incomplete=False):
        data=receipt(r,e,observer_present=present,observer_incomplete=incomplete)
        cases.append({'case':name,'receipt':data});return data
    r=run('setup_before_send',result)
    assert r['preparedGETAttempts']=={'metadata':2,'prepare':1} and r['adapterAttempts']=={'metadata':2,'prepare':1}
    assert r['requestSendBegin']=={'metadata':2,'prepare':0} and r['requestSendEnd']=={'metadata':2,'prepare':0} and r['exact']
    r=run('aggregate_dedupe_reused_connection',result);assert r['preparedGETAttempts']['metadata']==2 and r['responseHeadersEnd']['metadata']==2
    missing=copy.deepcopy(result);del missing['preparePacket'];r=run('missing_prepare_packet_parent_kill',missing)
    assert r['preparedGETAttempts']['metadata']==2 and r['preparedGETAttempts']['prepare']=='UNKNOWN' and not r['exact']
    r=run('missing_all_packets',{'stage':'prepare'});assert all(v=='UNKNOWN' for v in r['preparedGETAttempts'].values())
    r=run('metadata_parent_kill_before_packet',{'stage':'metadata'});assert r['preparedGETAttempts']['metadata']=='UNKNOWN' and r['preparedGETAttempts']['prepare']==0
    r=run('missing_observer',result,None,False);assert r['preparedGETAttempts']['prepare']==1 and r['requestSendBegin']['prepare']=='UNKNOWN' and not r['exact']
    r=run('observer_partial_terminal',result,ev[:-1]);assert r['observerCoverage']=='PARTIAL' and r['requestSendBegin']['metadata']=='UNKNOWN'
    partial=copy.deepcopy(result);partial['preparePacket']['rows'][0]['boundaries']['incomplete']=True
    r=run('observer_incomplete_packet',partial);assert r['observerCoverage']=='PARTIAL' and not r['exact']
    conflicting=copy.deepcopy(result);conflicting['preparePacket']['rows'][0]['boundaries']['requestID']='4'*16
    r=run('conflicting_identity',conflicting);assert r['preparedGETAttempts']['metadata']=='UNKNOWN' and not r['withinBudget']
    too_many=copy.deepcopy(result);extra=row('metadata',3,'5'*16);too_many['preparePacket']['rows'].append(extra)
    r=run('budget_cap_reject',too_many);assert not r['withinBudget']
    r=run('observer_cap128',result,ev*10);assert r['observerCoverage']=='PARTIAL'
    no_adapter=copy.deepcopy(result);del no_adapter['preparePacket']['rows'][2]['sendDiagnostic']
    r=run('adapter_evidence_missing',no_adapter);assert r['adapterAttempts']['prepare']=='UNKNOWN'
    malformed=copy.deepcopy(result);malformed['preparePacket']['rows'][2]['decodedBytes']='BAD'
    r=run('invalid_numeric_bytes',malformed);assert not r['withinBudget'] and r['decodedBytesFromPackets']['prepare']=='UNKNOWN'
    meta={'stage':'metadata','metadataPacket':result['metadataPacket']}
    r=run('metadata_only',meta,ev[:-2]);assert r['preparedGETAttempts']=={'metadata':2,'prepare':0} and r['requestSendBegin']['prepare']==0
    # New code derives accounting from old immutable raw without editing it or replaying source.
    old=pathlib.Path('/old/result.json')
    if old.exists():
        source=json.loads(old.read_text());raw_events=[json.loads(line) for line in pathlib.Path('/old/tiktok-boundaries.jsonl').read_text().splitlines()]
        r=run('historical_raw_readonly_derivation',source,raw_events)
        assert r['preparedGETAttempts']=={'metadata':2,'prepare':1} and r['requestSendBegin']=={'metadata':2,'prepare':0}
    return cases + linkage_probes(result,ev)

class Collector:
    def __init__(self,drop=False):self.rows=[];self.incomplete=False;self.drop=drop;self.dropped=0
    def observe(self,cid,phase,event,elapsed=0,code='OK',**fields):
        if self.drop and event=='END':self.dropped+=1;return
        if len(self.rows)>=32:self.incomplete=True;self.dropped+=1;return
        self.rows.append({'ownerID':cid,'phase':phase,'event':event,'code':code,'elapsed':elapsed,**fields})
    def mark_incomplete(self):self.incomplete=True
def listener():
    sock=socket.socket();sock.bind(('127.0.0.1',0));sock.listen(64);return sock
def drain(sock):
    sock.settimeout(.01)
    while True:
        try:client,_=sock.accept();client.close()
        except TimeoutError:return
def native_gate(cov,incomplete,left):
    p=subprocess.run([sys.executable,'/integration/diagnostic_gate.py'],input=json.dumps({'coverage':cov['status'],'incomplete':incomplete,'socketsLeft':left}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
    assert len(p.stdout)<=4096 and p.returncode in (0,20)
    return p.returncode
def index_probe(name,loop_type=SourceLoop,mode='success',drop=False):
    before=len(os.listdir('/proc/self/fd'));listen=listener();target=listen.getsockname()
    closed=socket.socket();closed.bind(('127.0.0.1',0));bad=closed.getsockname();closed.close()
    collector=Collector(drop);ctx=types.SimpleNamespace(cid=uuid.uuid4().hex[:16],end=time.monotonic()+10,trace=collector,addresses=[1,2])
    failures=[]
    class Delegate(asyncio.SelectorEventLoop):
        async def sock_connect(self,sock,address):
            try:
                if mode in ('winner_cancel','timeout') and address[0]=='1.1.1.1':await asyncio.sleep(30)
                if mode=='timeout':await asyncio.sleep(30)
                return await super().sock_connect(sock,bad if mode=='errors' else target)
            except BaseException as e:failures.append(e);raise
    if loop_type is SourceLoop:
        class Observed(SourceLoop,Delegate):pass
        loop=Observed(ctx)
    else:
        # OfflineLoop's routing logic delegates to the same public method; this test
        # only replaces its own control() with fixed offline control in a scoped module.
        import offline_glue
        original=offline_glue.control;offline_glue.control=lambda:{'mode':'normal'}
        class Observed(OfflineLoop,Delegate):pass
        fixture=types.SimpleNamespace(servers=[types.SimpleNamespace(server_address=target)])
        loop=Observed(ctx,fixture)
    sockets=[socket.socket() for _ in range(2)]
    for s in sockets:s.setblocking(False)
    received=[]
    async def call():
        if mode=='reuse':
            for s in sockets:await loop.sock_connect(s,('1.1.1.2',443))
        elif mode=='winner_cancel':
            tasks=[asyncio.create_task(loop.sock_connect(s,('1.1.1.'+str(i+1),443))) for i,s in enumerate(sockets)]
            await tasks[1];tasks[0].cancel()
            result=await asyncio.gather(*tasks,return_exceptions=True);received.extend(x for x in result if isinstance(x,BaseException))
        elif mode=='timeout':
            try:
                async with asyncio.timeout(.1):await asyncio.gather(*(loop.sock_connect(s,('1.1.1.'+str(i+1),443)) for i,s in enumerate(sockets)))
            except TimeoutError:pass
        else:
            result=await asyncio.gather(*(loop.sock_connect(s,('1.1.1.'+str(i+1),443)) for i,s in enumerate(sockets)),return_exceptions=True)
            received.extend(x for x in result if isinstance(x,BaseException))
    try:loop.run_until_complete(call())
    finally:
        for s in sockets:s.close()
        drain(listen);listen.close();loop.close()
        if loop_type is not SourceLoop:offline_glue.control=original
    c=coverage(collector.rows)
    assert c['status']==('INCOMPLETE' if drop else 'COMPLETE')
    begins=[r['index'] for r in collector.rows if r['event']=='BEGIN'];terminals=[r['index'] for r in collector.rows if r['event']!='BEGIN']
    assert begins==[1,2] and (drop or sorted(terminals)==[1,2])
    if mode=='errors':assert len(received)==2 and all(any(e is original for original in failures) for e in received)
    if mode=='winner_cancel':assert any(r['code']=='CANCELLED' and r['index']==1 for r in collector.rows)
    assert before==len(os.listdir('/proc/self/fd'))
    gate_exit=native_gate(c,collector.incomplete,0)
    assert gate_exit==(20 if drop else 0)
    (OUT/(name+'-trace.jsonl')).write_text(''.join(json.dumps(r)+'\n' for r in collector.rows))
    return {'case':name,'coverage':c,'beginIndices':begins,'terminalIndices':terminals,'delegateIdentity':mode!='errors' or all(any(e is original for original in failures) for e in received),'FD_before':before,'FD_after':len(os.listdir('/proc/self/fd')),'physicalSocketsLeft':0,'traceIncompleteExpected':drop,'diagnosticGateActualExit':gate_exit}

def batch_probe(name,plan):
    before=len(os.listdir('/proc/self/fd'));listen=listener();target=listen.getsockname();col=Collector()
    closed=socket.socket();closed.bind(('127.0.0.1',0));bad=closed.getsockname();closed.close()
    calls=[]
    ctx=types.SimpleNamespace(cid=uuid.uuid4().hex[:16],end=time.monotonic()+10,trace=col)
    class Delegate(asyncio.SelectorEventLoop):
        async def sock_connect(self,sock,address):
            i=int(address[0].rsplit('.',1)[1]);calls.append(i)
            if plan=='stall_third' and i<=2:await asyncio.sleep(30)
            return await super().sock_connect(sock,target if (plan=='first_winner' and i==1 or plan=='stall_third' and i==3 or plan=='immediate_fail' and i==7 or plan=='many45' and i==45) else bad)
    class Observed(SourceLoop,Delegate):pass
    loop=Observed(ctx);registry=Sockets();size=45 if plan=='many45' else 7 if plan=='immediate_fail' else 3
    infos=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.'+str(i),443)) for i in range(1,size+1)]
    status='PASS';third=False;elapsed=0;primary=[]
    async def call():
        nonlocal status,third,elapsed,primary
        start=time.monotonic()
        try:await connect(infos,start+.5,registry,loop=loop)
        except TimeoutError:status='TIMEOUT'
        finally:elapsed=time.monotonic()-start;registry.close();primary=calls.copy()
        if plan=='stall_third':
            control=Sockets()
            try:await connect(infos[2:],time.monotonic()+.5,control,loop=loop);third=True
            finally:control.close()
    try:loop.run_until_complete(call())
    finally:registry.close();drain(listen);listen.close();loop.close()
    assert before==len(os.listdir('/proc/self/fd')) and registry.live()==0 and registry.maxLive<=2
    if plan=='stall_third':assert status=='TIMEOUT' and calls[:2]==[1,2] and len(calls)==3 and third
    elif plan=='first_winner':assert calls==[1] and status=='PASS'
    elif plan=='immediate_fail':assert calls==list(range(1,8)) and status=='PASS'
    elif plan=='many45':assert calls==list(range(1,46)) and col.incomplete and len(col.rows)==32
    cov=coverage(col.rows)
    gate_exit=native_gate(cov,col.incomplete,0);assert gate_exit==(20 if plan=='many45' else 0)
    (OUT/(name+'-trace.jsonl')).write_text(''.join(json.dumps(r)+'\n' for r in col.rows))
    return {'case':name,'status':status,'lowerFixtureBudgetSeconds':.5,'elapsed':elapsed,'attemptedNumericIndices':primary,'allIncludingControl':calls,'thirdAttemptedBeforeDeadline':3 in primary,'thirdAloneControl':third,'socketPeak':registry.maxLive,'socketsLeft':0,'tcpTraceRows':len(col.rows),'ownerCap':32,'traceIncomplete':col.incomplete,'coverage':cov,'diagnosticGateActualExit':gate_exit,'FD_before':before,'FD_after':len(os.listdir('/proc/self/fd')),'transportChanged':False,'sourceOtherAddressesReachable':'UNKNOWN'}

def linkage_probes(control,control_events):
    cases=[]
    def run(name,r,e,expected=False):
        value=receipt(r,e,observer_present=e is not None)
        assert value['exact'] is expected and value['withinBudget'] is expected
        payload={'result':r,'events':e,'observerPresent':e is not None}
        p=subprocess.run([sys.executable,'/integration/accounting_gate.py'],input=json.dumps(payload).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
        assert len(p.stdout)<=4096 and p.returncode==(0 if expected else 20)
        packet=json.loads(p.stdout);assert packet['scope']=='ACCOUNTING_LINKAGE_GATE' and packet['accepted'] is expected
        cases.append({'case':name,'receipt':value,'accountingGateActualExit':p.returncode,'scope':packet['scope']})
        return value
    run('linked_setup_failure_control',copy.deepcopy(control),copy.deepcopy(control_events),True)
    r=copy.deepcopy(control);e=copy.deepcopy(control_events)
    mapping={'1'*16:'a'*16,'2'*16:'b'*16,'3'*16:'c'*16}
    e=[dict(x,requestID=mapping[x['requestID']]) for x in e]
    value=run('disjoint_packet_observer_ids',r,e);assert value['preparedGETAttempts']=={'metadata':2,'prepare':1} and value['requestSendBegin']['metadata']=='UNKNOWN'
    e=copy.deepcopy(control_events)+events('d'*16)
    value=run('extra_unaccounted_send',copy.deepcopy(control),e);assert value['observedSendBeginLowerBound']['metadata']==3
    e=copy.deepcopy(control_events)+[dict(x,requestID='d'*16) for x in events('1'*16) if x['boundary']=='RESPONSE_HEADERS']
    run('extra_unaccounted_header',copy.deepcopy(control),e)
    e=[dict(x,phase='prepare') if x['requestID']=='1'*16 else x for x in copy.deepcopy(control_events)]
    run('observer_crossphase',copy.deepcopy(control),e)
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):r[p]['rows'][1]['boundaries']['requestID']='1'*16
    run('repeated_rid_two_indices',r,copy.deepcopy(control_events))
    r=copy.deepcopy(control);r['preparePacket']['rows'][2]['boundaries']['requestID']='1'*16
    run('repeated_rid_crossphase',r,copy.deepcopy(control_events))
    for name,identifier in (('empty_rid',''),('malformed_rid','z'*16),('numeric_rid',123),('missing_rid',None)):
        r=copy.deepcopy(control)
        for p in ('metadataPacket','preparePacket'):
            if identifier is None:del r[p]['rows'][0]['boundaries']['requestID']
            else:r[p]['rows'][0]['boundaries']['requestID']=identifier
        value=run(name,r,copy.deepcopy(control_events));assert value['preparedGETAttempts']['metadata']==2
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):r[p]['rows'][0]['status']=200.0
    run('invalid_status_numeric',r,copy.deepcopy(control_events))
    r=copy.deepcopy(control);r['preparePacket']['rows'][2]['status']=200
    run('packet_status_without_header',r,copy.deepcopy(control_events))
    e=[x for x in copy.deepcopy(control_events) if not(x['requestID']=='1'*16 and x['boundary']=='REQUEST_SEND')]
    run('header_without_send',copy.deepcopy(control),e)
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):r[p]['rows'][0]['sendDiagnostic']['status']=201
    run('diagnostic_status_disagreement',r,copy.deepcopy(control_events))
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):
        r[p]['rows'][0]['sendDiagnostic']['code']='PROXY_ERROR';del r[p]['rows'][0]['status']
    run('adapter_error_with_headers',r,copy.deepcopy(control_events))
    r=copy.deepcopy(control);r['preparePacket']['rows'][0]['decodedBytes']=8
    run('aggregate_content_conflict',r,copy.deepcopy(control_events))
    e=copy.deepcopy(control_events);e[0]['connectionID']='c'*16
    run('connection_identity_conflict',copy.deepcopy(control),e)
    run('missing_packet_rid_events',copy.deepcopy(control),[x for x in control_events if x['requestID']!='2'*16])
    value=run('partial_observer_budget_known',copy.deepcopy(control),control_events[:-1]);assert value['preparedGETAttempts']=={'metadata':2,'prepare':1} and value['budgetWithinCaps']
    value=run('missing_observer_budget_known',copy.deepcopy(control),None);assert value['preparedGETAttempts']['prepare']==1
    r=copy.deepcopy(control);r['preparePacket']['rows'][2]['decodedBytes']=1
    run('body_without_response_headers',r,copy.deepcopy(control_events))
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):r[p]['rows'][0]['index']=True
    run('boolean_budget_index_invalid',r,copy.deepcopy(control_events))
    e=copy.deepcopy(control_events);e[0]['requestID']='Z'*16
    run('malformed_observer_identity',copy.deepcopy(control),e)
    r=copy.deepcopy(control)
    for p in ('metadataPacket','preparePacket'):r[p]['rows'][0]['boundaries']['terminal']=[]
    run('packet_terminal_disagreement',r,copy.deepcopy(control_events))
    return cases

def main():
    before=len(os.listdir('/proc/self/fd'));thread_before=threading.active_count()
    account=accounting_probes()
    indices=[index_probe('source_two_success'),index_probe('source_reuse',mode='reuse'),index_probe('source_winner_cancel',mode='winner_cancel'),index_probe('source_two_errors',mode='errors'),index_probe('source_two_timeout',mode='timeout'),index_probe('source_missing_terminal',drop=True),index_probe('offline_two_success',OfflineLoop)]
    batches=[batch_probe('first_pair_stall_third_control','stall_third'),batch_probe('many_immediate_fail','immediate_fail'),batch_probe('first_winner','first_winner'),batch_probe('many45_trace_cap','many45')]
    assert before==len(os.listdir('/proc/self/fd')) and thread_before==threading.active_count()
    result={'status':'PASS_DIAGNOSTIC_PROBES','actualExit':0,'sourceCalls':0,'accountingCases':len(account),'indexCases':len(indices),'batchCases':len(batches),'accounting':account,'indices':indices,'batches':batches,'fdBefore':before,'fdAfter':len(os.listdir('/proc/self/fd')),'threadsBefore':thread_before,'threadsAfter':threading.active_count(),'runtime':{'python':sys.version.split()[0],'versions':versions(),'sources':inventory()},'transportChanged':False}
    (OUT/'probe-result.json').write_text(json.dumps(result,indent=2));print('PASS diagnostic probes; no source',flush=True)
    return 0
if __name__=='__main__':sys.exit(main())
