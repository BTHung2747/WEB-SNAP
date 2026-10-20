"""Offline integration uses real Requests -> own proxy -> trusted HTTPS fixture -> photo worker.
Legacy photo fixture generates metadata/JPEG; source stage never imports this module.
"""
import hashlib,json,os,pathlib,socket,subprocess,sys,time
sys.path.insert(0,'/trace_lab')
from common import summary_valid
from worker_entry import pipeline_run,URL,ID
from proxy_entry import ReceiptSink
from tiktok.send_diagnostics import classify
from parent import pipeline
def run(out):
    checkpoint={'phase':'INIT'}
    def safe_failure(kind,value,tb):
        with (out/'test-failure.json').open('x') as f:
            json.dump({'phase':checkpoint['phase'],'code':'OFFLINE_ASSERT' if kind is AssertionError else 'OFFLINE_UNKNOWN'},f)
        print('OFFLINE_INTEGRATION_FAILURE',flush=True)
    sys.excepthook=safe_failure
    assert os.environ.get('TIKTOK_APP_FIXTURE') is None
    results=[]
    # Worker has only internal network; direct public test-address connection must fail.
    start=time.monotonic()
    try:
        s=socket.create_connection(('192.0.2.1',443),timeout=.5);s.close()
    except OSError:results.append({'case':'no-direct-egress','blocked':True,'elapsed':time.monotonic()-start})
    else:raise AssertionError('DIRECT_EGRESS_NOT_BLOCKED')
    for mode,success in [('normal',True),('image-dns-failure',False),('image-tcp-failure',False),
                         ('image-cert-failure',False),('image-tls-stall',False),('image-html',False),
                         ('wrong-body',False),('redirect',False),('dns-private',False),('health-missing',False),('health-incomplete',False)]:
        case='network-'+mode;folder=out/case;folder.mkdir()
        checkpoint['phase']=case
        pathlib.Path('/control/control.json').write_text(json.dumps({'case':case,'mode':mode}))
        started=time.monotonic();r,rc=pipeline_run(folder)
        with (folder/'result.json').open('x') as f:json.dump(r,f,indent=2)
        assert rc==(0 if success else 20)
        meta=r.get('metadataPacket') or {};prep=r.get('preparePacket') or {}
        rows=prep.get('rows') or meta.get('rows') or []
        metadata=[row for row in rows if row['phase']=='metadata'];image=[row for row in rows if row['phase']=='prepare']
        assert len(metadata)<=2 and len(image)<=1
        assert all(row['method']=='GET' and row['url']=='[url-redacted]' for row in rows)
        if success:
            assert r['workerActualExit']==0 and meta['summary']['id']==ID and meta['summary']['type']=='photo'
            assert [i['index'] for i in meta['summary']['images']]==[1,2]
            assert prep['contract']['magic']=='jpeg' and prep['contract']['frames']==1 and prep['contract']['fullDecode']=='PASS'
            assert prep['contract']['width']==prep['contract']['height']==64
            assert hashlib.sha256((folder/'image.jpg').read_bytes()).hexdigest()==prep['sha256']
            assert len(metadata)==2 and len(image)==1
        else:
            assert not(folder/'image.jpg').exists() and not(folder/'image.jpg.part').exists()
            if mode.startswith('image-'):
                assert meta['status']=='PASS' and prep['status']=='FAIL' and len(image)==1
            else:assert not image
            if mode.startswith('health-'):
                assert meta['status']=='PASS' and not image
                assert json.loads((folder/'trace-prepare-gate.json').read_text())['status']=='FAIL'
        if mode=='image-tls-stall':
            assert prep['error']=='SOURCE_TIMEOUT'
            boundary=image[0]['boundaries']['terminal']
            assert len(boundary)==1 and boundary[0]['boundary']=='CONNECTION_SETUP' and boundary[0]['event']=='ERROR'
        if mode=='image-cert-failure':assert image[0]['sendDiagnostic']['code']=='TLS_ERROR'
        if mode=='image-html':assert prep['error']=='JPEG_REQUIRED'
        encoded=json.dumps(r)
        assert all(secret not in encoded for secret in ('FAKEPATH','FAKESIGNED','fixture_cookie','FIXTURE_SECRET','__UNIVERSAL'))
        results.append({'case':case,'fixture':True,'parentActualExit':rc,'workerActualExit':r['workerActualExit'],
                        'metadataGET':len(metadata),'imageGET':len(image),'elapsed':time.monotonic()-started})
    # SSRF literal and disallowed host are blocked by the same stock proxy.
    import requests,urllib3
    for label,url in [('literal','https://127.0.0.1/SECRET'),('host','https://blocked.example/SECRET')]:
        session=requests.Session();session.trust_env=False
        try:
            prepared=session.prepare_request(requests.Request('GET',url))
            session.get_adapter(url).send(prepared,stream=True,verify=True,timeout=urllib3.util.Timeout(connect=10,read=20,total=30),
                                         proxies={'https':'http://egress:8888'})
        except requests.exceptions.ProxyError:results.append({'case':'ssrf-'+label,'blocked':True})
        else:raise AssertionError('SSRF_NOT_BLOCKED')
        finally:session.close()
    # New receipt validation path fails closed on cap, I/O failure and absence; exact exception unchanged.
    sink=ReceiptSink(out/'unit-cap.jsonl')
    checkpoint['phase']='RECEIPT_CAP_IO'
    for i in range(9):
        con=sink.connection()
        for j in range(35):con.emit('DNS_LOOKUP','BEGIN',code='BEGIN')
    summary=sink.final(grace=0);rows=[json.loads(line) for line in (out/'unit-cap.jsonl').read_text().splitlines()]
    assert len(rows)==256 and summary['incomplete'] and not summary_valid(summary,rows)
    with (out/'unit-cap-summary.json').open('x') as f:json.dump(summary,f,indent=2)
    error=TimeoutError('FAKE_SECRET')
    sink=ReceiptSink(out/'missing-directory'/'trace.jsonl');con=sink.connection()
    def fail():raise error
    try:con.call('UPSTREAM_TCP_CONNECT',fail)
    except TimeoutError as caught:assert caught is error
    else:raise AssertionError('EXCEPTION_IDENTITY')
    summary=sink.final(grace=0);assert summary['incomplete'] and not summary_valid(summary,[])
    with (out/'unit-io-summary.json').open('x') as f:json.dump(summary,f,indent=2)
    assert not summary_valid(None,[]) and not summary_valid({'final':False},[])
    results.extend([{'case':'receipt-cap','rows':256,'rejected':True},{'case':'receipt-IO','sameException':True,'rejected':True},
                    {'case':'receipt-missing','rejected':True}])
    # Parent failure/OS deadline with the same output cleanup implementation.
    for mode,code in [('exit20',"print('{\"stage\":\"metadata\",\"status\":\"PASS\"}',flush=True);input();print('{\"stage\":\"prepare\",\"status\":\"PASS\"}',flush=True);raise SystemExit(20)"),
                      ('deadline',"import time;time.sleep(10)")]:
        folder=out/('parent-'+mode);folder.mkdir()
        checkpoint['phase']='parent-'+mode
        program='import pathlib;pathlib.Path('+repr(str(folder/'image.jpg.part'))+').write_bytes(b"OWNED");'+code
        r,rc=pipeline(URL,ID,prepare=True,worker_argv=['python3','-c',program],metadata_seconds=.3,prepare_seconds=.3,output_dir=str(folder))
        assert rc==20 and not(folder/'image.jpg.part').exists()
        results.append({'case':'parent-'+mode,'parentActualExit':rc,'result':r})
    # Reuse the 18-case photo regression (including body timeout fix), with isolated fixture session.
    # It does not substitute for the real proxy network cases above.
    env=dict(os.environ,PYTHONPATH='/app/apps/media/src/tiktok/photo_lab:/app/apps/media/src')
    checkpoint['phase']='PHOTO_REGRESSION'
    p=subprocess.run(['python3','/app/apps/media/src/tiktok/photo_lab/test_photo.py'],env=env,
                     stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=140)
    with (out/'regression-exit.json').open('x') as f:json.dump({'actualExit':p.returncode},f)
    assert p.returncode==0
    old=json.loads((out/'offline-result.json').read_text())
    assert old['status']=='PASS' and old['sourceCalls']==0 and len(old['results'])==18
    results.append({'case':'photo-regression','actualExit':p.returncode,'cases':18})
    with (out/'integration-result.json').open('x') as f:
        json.dump({'status':'PASS','sourceCalls':0,'networkFixtureCases':11,'regressionCases':18,'results':results},f,indent=2)
    print('PASS photo integration pipeline JPEG/ID/decode/SHA/guards/timeout/receipt; source0',flush=True)
    return 0

