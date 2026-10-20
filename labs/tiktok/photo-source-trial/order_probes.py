"""Offline request-order controls/faults; HTTP remains Requests/urllib3's work."""
import copy,http.server,json,os,pathlib,subprocess,sys,threading
from accounting import receipt

def run_order(result,events,name,expected=False,reason=None):
    before=json.dumps(result,sort_keys=True);original=copy.deepcopy(events)
    value=receipt(result,events,observer_present=True)
    assert value['exact'] is expected and value['withinBudget'] is expected
    assert value['preparedGETAttempts']=={'metadata':2,'prepare':1} or result['stage']=='metadata'
    assert value['budgetWithinCaps'] and value['originReceipt']=='UNKNOWN'
    if not expected:
        assert value['linkageCoverage']['status']=='PARTIAL' and value['requestSendBegin']['metadata']=='UNKNOWN'
        assert reason in value['linkageCoverage']['reasonCodes']
    assert before==json.dumps(result,sort_keys=True) and original==events
    p=subprocess.run([sys.executable,'/integration/accounting_gate.py'],input=json.dumps({'result':result,'events':events,'observerPresent':True}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
    assert len(p.stdout)<=4096 and p.returncode==(0 if expected else 20)
    assert json.loads(p.stdout)=={'accepted':expected,'scope':'ACCOUNTING_LINKAGE_GATE'}
    folder=pathlib.Path('/out')/'order-cases'/name;folder.mkdir(parents=True)
    (folder/'packet.json').write_text(before)
    (folder/'observer.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events));os.chmod(folder/'observer.jsonl',0o600)
    (folder/'receipt.json').write_text(json.dumps(value))
    return {'case':name,'scope':'ACCOUNTING_ORDER_GATE','accepted':expected,'accountingGateActualExit':p.returncode,'receipt':value,'packetUnchanged':True,'observerUnchanged':True,'expectedReason':reason,'sourceCalls':0}

def real_http_control():
    import requests
    sys.path.insert(0,'/app/apps/media/src')
    from tiktok.connection_boundaries import BoundaryObserver,ObservedAdapter
    before=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
    class Origin(http.server.BaseHTTPRequestHandler):
        protocol_version='HTTP/1.1'
        def setup(self):super().setup();self.connection.settimeout(2)
        def log_message(self,*args):pass
        def do_GET(self):
            self.send_response(200);self.send_header('Content-Length','7');self.end_headers();self.wfile.write(b'FIXTURE')
    server=http.server.HTTPServer(('127.0.0.1',0),Origin)
    worker=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.02},daemon=True);worker.start()
    class OwnedAdapter(ObservedAdapter):
        # Requests documents this hook for adapter subclasses, not user callers.
        def __init__(self,*args,**kwargs):self.owned_pools={};super().__init__(*args,**kwargs)
        def get_connection_with_tls_context(self,*args,**kwargs):
            pool=super().get_connection_with_tls_context(*args,**kwargs);self.owned_pools[id(pool)]=pool;return pool
        def close(self):
            try:
                for pool in self.owned_pools.values():pool.close()
            finally:self.owned_pools.clear();super().close()
    observer=BoundaryObserver('order-public-http.jsonl',root='/out');session=requests.Session();session.trust_env=False
    session.mount('http://',OwnedAdapter(max_retries=0));rows=[]
    url='http://127.0.0.1:'+str(server.server_port)+'/FAKE'
    try:
        for i in (1,2):
            row={'phase':'metadata','index':i,'method':'GET','url':'[url-redacted]','decodedBytes':0}
            with observer.request(row,'metadata'):
                with session.get(url,timeout=(10,20),allow_redirects=False,stream=True) as response:
                    row['status']=response.status_code;row['sendDiagnostic']={'code':'HTTP_RESPONSE','status':response.status_code}
                    for block in response.iter_content(1024):row['decodedBytes']+=len(block);assert row['decodedBytes']<=7
            rows.append(row)
    finally:session.close();server.shutdown();server.server_close();worker.join(2)
    cleanup={'FD_before':before,'FD_after':len(os.listdir('/proc/self/fd')),'threadsBefore':threads,'threadsAfter':threading.active_count(),'handlerThreadAlive':worker.is_alive()}
    (pathlib.Path('/out')/'order-public-http-cleanup.json').write_text(json.dumps(cleanup))
    assert not worker.is_alive() and before==cleanup['FD_after'] and threads==cleanup['threadsAfter']
    events=[json.loads(line) for line in observer.path.read_text().splitlines()]
    first=[(e['boundary'],e['event']) for e in events if e['requestID']==rows[0]['boundaries']['requestID']]
    assert first==[('REQUEST_SEND','BEGIN'),('CONNECTION_SETUP','BEGIN'),('CONNECTION_SETUP','END'),('REQUEST_SEND','END'),('RESPONSE_HEADERS','BEGIN'),('RESPONSE_HEADERS','END')]
    assert rows[1]['boundaries']['reused'] and rows[0]['boundaries']['connectionID']==rows[1]['boundaries']['connectionID']
    assert not any(e['boundary']=='CONNECTION_SETUP' for e in events if e['requestID']==rows[1]['boundaries']['requestID'])
    control=run_order({'stage':'metadata','metadataPacket':{'status':'PASS','rows':rows}},events,'actual_public_http_nested_and_reuse',True)
    control.update(publicObserver=True,privateMode=observer.path.stat().st_mode&0o777,FD_before=before,FD_after=len(os.listdir('/proc/self/fd')),threadsBefore=threads,threadsAfter=threading.active_count(),handlersLeft=0)
    from order_fixture import mutate
    result={'stage':'metadata','metadataPacket':{'status':'PASS','rows':rows}}
    faults=[run_order(copy.deepcopy(result),mutate(events,mode),name,reason=reason) for mode,name,reason in
            [('observer-order-send','actual_public_audit_send_before_begin','ORDER_TERMINAL_BEFORE_BEGIN'),
             ('observer-order-header','actual_public_audit_header_before_send_end','ORDER_HEADER_BEFORE_SEND_END')]]
    return [control]+faults

def order_probes(control,control_events):
    cases=[]
    def run(name,e,expected=False,reason=None,r=None):
        cases.append(run_order(copy.deepcopy(control) if r is None else r,e,name,expected,reason))
    def locate(e,b,event,rid='1'*16):return next(i for i,x in enumerate(e) if x['requestID']==rid and x['boundary']==b and x['event']==event)
    def move_begin(e,b,after=None,before=None):
        value=e.pop(locate(e,b,'BEGIN'))
        if after:e.insert(locate(e,after,'END')+1,value)
        else:e.insert(locate(e,before,'END'),value)
        return e
    run('order_setup_before_send_control',copy.deepcopy(control_events),True)
    nested=copy.deepcopy(control_events);value=nested.pop(locate(nested,'REQUEST_SEND','BEGIN'));nested.insert(0,value)
    run('order_nested_setup_control',nested,True)
    # Reuse and separate phase/request interleaving are valid, with no global sort.
    groups=[[copy.deepcopy(x) for x in control_events if x['requestID']==rid] for rid in ('1'*16,'2'*16,'3'*16)]
    interleaved=[group[i] for i in range(max(map(len,groups))) for group in groups if i<len(group)]
    run('order_phase_request_interleaving_control',interleaved,True)
    run('order_reused_connection_control',copy.deepcopy(control_events),True)
    failure=copy.deepcopy(control)
    for packet in ('metadataPacket','preparePacket'):
        r=failure[packet]['rows'][0];r.pop('status');r['decodedBytes']=0;r['sendDiagnostic']={'code':'PROXY_ERROR'}
    e=[x for x in copy.deepcopy(control_events) if x['requestID']!='1'*16]
    e[:0]=[{'requestID':'1'*16,'phase':'metadata','boundary':b,'event':event} for b,event in [('REQUEST_SEND','BEGIN'),('CONNECTION_SETUP','BEGIN'),('CONNECTION_SETUP','ERROR'),('REQUEST_SEND','ERROR')]]
    run('order_nested_setup_error_send_error_control',e,True,r=failure)
    e=copy.deepcopy(control_events)
    # Fixture durations deliberately unrelated to global order.
    for i,x in enumerate(e):x['elapsed']=1000-i*11
    run('order_elapsed_is_not_timestamp_control',e,True)
    # Keep terminal sequence and original packet unchanged in both audit faults.
    for name,b in [('audit_send_terminal_before_begin','REQUEST_SEND'),('setup_terminal_before_begin','CONNECTION_SETUP'),('header_terminal_before_begin','RESPONSE_HEADERS')]:
        e=move_begin(copy.deepcopy(control_events),b,after=b)
        assert [x for x in e if x['event']!='BEGIN']==[x for x in control_events if x['event']!='BEGIN']
        run(name,e,reason='ORDER_TERMINAL_BEFORE_BEGIN')
    e=move_begin(copy.deepcopy(control_events),'RESPONSE_HEADERS',before='REQUEST_SEND')
    run('audit_header_begin_before_send_end',e,reason='ORDER_HEADER_BEFORE_SEND_END')
    e=copy.deepcopy(control_events);x=e.pop(locate(e,'RESPONSE_HEADERS','BEGIN'));e.insert(0,x)
    run('header_begin_before_send_begin',e,reason='ORDER_HEADER_BEFORE_SEND_END')
    for b,label in [('REQUEST_SEND','send'),('CONNECTION_SETUP','setup'),('RESPONSE_HEADERS','header')]:
        e=copy.deepcopy(control_events);i=locate(e,b,'BEGIN');e.insert(i+1,copy.deepcopy(e[i]));run('duplicate_'+label+'_begin',e,reason='ORDER_DUPLICATE_BEGIN')
        e=copy.deepcopy(control_events);i=locate(e,b,'END');e.insert(i+1,copy.deepcopy(e[i]));run('duplicate_'+label+'_terminal',e,reason='ORDER_DUPLICATE_TERMINAL')
        e=copy.deepcopy(control_events);begin=copy.deepcopy(e[locate(e,b,'BEGIN')]);e.insert(locate(e,b,'END')+1,begin);run('reopen_'+label,e,reason='ORDER_BOUNDARY_REOPEN')
    e=copy.deepcopy(control_events);i=locate(e,'REQUEST_SEND','END');e[i]['event']='ERROR';run('send_error_then_header',e,reason='ORDER_HEADER_AFTER_SEND_ERROR')
    e=copy.deepcopy(control_events);i=locate(e,'REQUEST_SEND','END');e[i]['event']='ERROR';e.insert(i+1,dict(e[i],event='END'));run('send_error_then_end',e,reason='ORDER_DUPLICATE_TERMINAL')
    e=copy.deepcopy(control_events);i=locate(e,'CONNECTION_SETUP','END');e[i]['event']='ERROR';run('setup_error_then_send',e,reason='ORDER_SEND_AFTER_SETUP_ERROR')
    e=copy.deepcopy(nested);i=locate(e,'CONNECTION_SETUP','END');e[i]['event']='ERROR';run('nested_setup_error_then_send_end',e,reason='ORDER_SEND_END_AFTER_SETUP_ERROR')
    e=copy.deepcopy(control_events);begin=e.pop(locate(e,'REQUEST_SEND','BEGIN'));e.insert(locate(e,'CONNECTION_SETUP','END'),begin);run('send_begin_during_prior_setup',e,reason='ORDER_SEND_DURING_SETUP')
    e=copy.deepcopy(nested);terminal=e.pop(locate(e,'REQUEST_SEND','END'));e.insert(locate(e,'CONNECTION_SETUP','END'),terminal);run('send_terminal_during_nested_setup',e,reason='ORDER_SEND_TERMINAL_DURING_SETUP')
    e=copy.deepcopy(control_events);setup=[x for x in e if x['requestID']=='1'*16 and x['boundary']=='CONNECTION_SETUP'];e=[x for x in e if x not in setup];i=locate(e,'REQUEST_SEND','END');e[i+1:i+1]=setup;run('setup_after_send_terminal',e,reason='ORDER_SETUP_AFTER_SEND_TERMINAL')
    e=copy.deepcopy(control_events);e.pop(locate(e,'REQUEST_SEND','END'));run('missing_send_terminal_order',e,reason='ORDER_HEADER_BEFORE_SEND_END')
    cases.extend(real_http_control())
    return cases
