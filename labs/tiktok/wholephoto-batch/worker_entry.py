"""AGPL-3.0 lab glue: existing parent/worker, bounded file contract and ephemeral session."""
import json,os,pathlib,stat,sys
import time,hashlib,socket,subprocess
sys.path.insert(0,'/app/apps/media/src/tiktok/photo_lab')
sys.path.insert(0,'/app/apps/media/src')
sys.excepthook=lambda *a:print('PHOTO_ENTRY_FAILURE',flush=True)
from common import inventory,versions,stage_policy,isolation,trust_hash
URL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';ID='7678209751167110421'
def pipeline_run(folder,metadata_seconds=30,prepare_seconds=60):
    from parent import pipeline
    return pipeline(URL,ID,prepare=True,worker_argv=['python3','/integration/worker_entry.py','child',str(folder)],
                    metadata_seconds=metadata_seconds,prepare_seconds=prepare_seconds,output_dir=str(folder))
def main():
    stage=stage_policy()
    if len(sys.argv)>1 and sys.argv[1]=='child':
        from worker import worker
        settings=json.loads(pathlib.Path('/control/control.json').read_text());settings['phaseDeadline']=time.monotonic()+30
        pathlib.Path('/control/control.json').write_text(json.dumps(settings))
        # The existing worker has no pre-prepare trace callback. Adapt only its owned IPC input;
        # no extractor, HTTP, TLS or downloader override is introduced.
        original=sys.stdin
        class TraceInput:
            def readline(self):
                command=original.readline()
                if command.strip()=='prepare':
                    valid=False;receipt={'status':'FAIL','code':'TRACE_RECEIPT_UNKNOWN','clientCorrelation':'UNKNOWN'}
                    try:
                        path=pathlib.Path('/proxy/proxy-health.json');st=path.stat();health=json.loads(path.read_text())
                        valid=(health.get('incomplete') is False and health.get('uid')==65534 and st.st_uid==65534
                               and type(health.get('rows')) is int and 0<health['rows']<=256
                               and health.get('totalCap')==256 and health.get('connectionCap')==32 and stat.S_IMODE(st.st_mode)==0o644)
                        receipt.update(status='PASS' if valid else 'FAIL',code='TRACE_RECEIPT_OK' if valid else 'TRACE_RECEIPT_INCOMPLETE',
                                       proxyRowsReported=health.get('rows') if type(health.get('rows')) is int else None,
                                       proxyHealthUID=st.st_uid,proxyHealthMode=stat.S_IMODE(st.st_mode))
                    except FileNotFoundError:receipt['code']='TRACE_RECEIPT_MISSING'
                    except PermissionError:receipt['code']='TRACE_RECEIPT_PERMISSION'
                    except (ValueError,TypeError):receipt['code']='TRACE_RECEIPT_INVALID'
                    with (pathlib.Path(sys.argv[2])/'trace-prepare-gate.json').open('x') as f:json.dump(receipt,f)
                    if not valid:raise RuntimeError('TRACE_GATE_FAIL')
                    settings=json.loads(pathlib.Path('/control/control.json').read_text());settings['phaseDeadline']=time.monotonic()+60
                    pathlib.Path('/control/control.json').write_text(json.dumps(settings))
                return command
        sys.stdin=TraceInput()
        try:return worker(URL,ID,sys.argv[2])
        finally:isolation(pathlib.Path(sys.argv[2])/'child-isolation.json',stage)
    stage=os.environ.get('WHOLEPHOTO_STAGE')
    assert stage in ('offline','source') and os.geteuid()==1000 and sys.version.split()[0]=='3.11.2'
    OUT=pathlib.Path('/out')
    with (OUT/'worker-runtime.json').open('x') as f:json.dump({'python':sys.version.split()[0],'versions':versions(),'sources':inventory(),'uid':os.geteuid(),'trustSHA':trust_hash(),'stage':stage},f)
    mode=json.loads(pathlib.Path('/control/control.json').read_text()).get('mode','normal')
    # Private proxy trace permissions remain enforced across actual UID1000/65534.
    path=pathlib.Path('/proxy/proxy-trace.jsonl');st=path.stat();denied=False
    try:
        with path.open('rb') as f:f.read(1)
    except PermissionError:denied=True
    assert denied and st.st_uid==65534 and stat.S_IMODE(st.st_mode)==0o600
    blocked=False
    try:s=socket.create_connection(('192.0.2.1',443),timeout=.3);s.close()
    except OSError:blocked=True
    assert blocked
    (OUT/'permission-network.json').write_text(json.dumps({'uid':os.getuid(),'privateTraceUID':st.st_uid,'privateTraceMode':stat.S_IMODE(st.st_mode),'privateReadDenied':denied,'noBypass':blocked}))
    if mode=='preexisting':(OUT/'image.jpg').write_bytes(b'PREEXISTING_OWNED_SENTINEL')
    if mode in ('observer-extra-preexisting','observer-order-header-preexisting','batch-admission-preexisting'):(OUT/'keep.bin').write_bytes(b'PREEXISTING_UNRELATED_SENTINEL')
    prior=[p.name for p in (OUT/'image.jpg',OUT/'image.jpg.part') if p.exists()]
    (OUT/'ownership-before.json').write_text(json.dumps({'preexisting':prior,'unrelatedSHA':hashlib.sha256((OUT/'keep.bin').read_bytes()).hexdigest() if (OUT/'keep.bin').exists() else None,'sha':hashlib.sha256((OUT/'image.jpg').read_bytes()).hexdigest() if prior else None}))
    if mode=='guards':
        env=dict(os.environ,PYTHONPATH='/app/apps/media/src/tiktok/photo_lab:/app/apps/media/src')
        p=subprocess.run(['python3','/app/apps/media/src/tiktok/photo_lab/test_photo.py'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=80)
        assert p.returncode==0
        result={'stage':'guards','status':'PASS_FIXTURE_GUARDS','workerActualExit':0,'sourceCalls':0,'regressionCases':18};code=0
    elif mode.startswith('ssrf-'):
        import requests
        session=requests.Session();session.trust_env=False
        target='https://127.0.0.1/FAKEPATH' if mode=='ssrf-literal' else 'https://blocked.example/FAKEPATH'
        try:session.get(target,proxies={'https':'http://egress:8888'},timeout=(10,20),verify=True,allow_redirects=False)
        except requests.exceptions.ProxyError:result={'stage':'ssrf','status':'BLOCKED','workerActualExit':0,'sourceCalls':0};code=20
        else:raise AssertionError('SSRF_ALLOWED')
        finally:session.close()
    elif mode=='cancel':result,code=pipeline_run(OUT,metadata_seconds=.3,prepare_seconds=60)
    elif mode in ('parent-nonzero','parent-expiry'):
        from parent import pipeline
        code='import pathlib;pathlib.Path("/out/image.jpg.part").write_bytes(b"OWNED");'
        code+= 'print(\'{"stage":"metadata","status":"PASS"}\',flush=True);input();print(\'{"stage":"prepare","status":"PASS"}\',flush=True);raise SystemExit(20)' if mode=='parent-nonzero' else 'import time;time.sleep(10)'
        result,code=pipeline(URL,ID,prepare=True,worker_argv=['python3','-c',code],metadata_seconds=.3,prepare_seconds=.3,output_dir=str(OUT))
    else:result,code=pipeline_run(OUT)
    if mode.startswith('observer-'):
        assert stage=='offline' and result.get('preparePacket',{}).get('status')=='PASS' and result['workerActualExit']==0
        events=[json.loads(line) for line in (OUT/'tiktok-boundaries.jsonl').read_text().splitlines()]
        (OUT/'observer-before-injection.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events));os.chmod(OUT/'observer-before-injection.jsonl',0o600)
        if mode.startswith('observer-order-'):
            from order_fixture import mutate
            packetSHA=hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()
            events=mutate(events,mode)
            assert packetSHA==hashlib.sha256(json.dumps(result,sort_keys=True).encode()).hexdigest()
        elif mode=='observer-disjoint':
            ids={e['requestID']:hashlib.sha256(('OFFLINE:'+e['requestID']).encode()).hexdigest()[:16] for e in events}
            events=[dict(e,requestID=ids[e['requestID']]) for e in events]
        else:
            template=next(e for e in events if e['phase']=='metadata')
            for boundary in ('REQUEST_SEND','RESPONSE_HEADERS'):
                for event in ('BEGIN','END'):
                    events.append(dict(template,requestID='e'*16,boundary=boundary,event=event,code='BEGIN' if event=='BEGIN' else 'OK',elapsed=0))
        (OUT/'tiktok-boundaries.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in events));os.chmod(OUT/'tiktok-boundaries.jsonl',0o600)
        (OUT/'observer-injection.json').write_text(json.dumps({'fixture':True,'mode':mode,'packetUnchanged':True,'sourceCalls':0,'privateMode':0o600,'orderOnlyFixture':mode.startswith('observer-order-'),'terminalSequencePreserved':mode.startswith('observer-order-')}))
    from accounting import receipt,read_owned_observer
    events,present,incomplete=read_owned_observer(OUT/'tiktok-boundaries.jsonl')
    accounting=receipt(result,events,observer_present=present,observer_incomplete=incomplete)
    result.update(requestAccounting=accounting,sourceAnalyzeAttempts=0,source=False,fixture=True,parentActualExit=code,sourceCalls=0)
    (OUT/'request-accounting.json').write_text(json.dumps(accounting))
    isolation(OUT/'worker-isolation.json',stage)
    with (OUT/'result.json').open('x') as f:json.dump(result,f,indent=2)
    print(json.dumps(result),flush=True)
    return code
if __name__=='__main__':sys.exit(main())

