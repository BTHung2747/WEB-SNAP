"""Actual production CLI and Requests transport; private CA only in lab."""
import hashlib,json,os,pathlib,subprocess,sys,uuid
OUT=pathlib.Path('/control')
if sys.argv[1]=='generate':
    commands=[['openssl','req','-x509','-newkey','rsa:2048','-sha256','-days','1','-nodes','-keyout',str(OUT/'fixture-key.pem'),'-out',str(OUT/'fixture-cert.pem'),'-subj','/CN=www.tiktok.com','-addext','subjectAltName=DNS:www.tiktok.com,DNS:media.tiktokcdn.com,DNS:fixture.tiktok.com'],
      ['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','color=c=blue:s=64x64','-frames:v','1','-threads','1','-filter_threads','1',str(OUT/'input.jpg')]]
    native=[]
    for argv in commands:
        r=subprocess.run(argv,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10);native.append(r.returncode);assert r.returncode==0
    os.chmod(OUT/'fixture-key.pem',0o644)  # Disposable public lab fixture, readable by proxy uid65534 only in this namespace.
    (OUT/'generate.json').write_text(json.dumps(dict(actualExits=native,sourceCalls=0)));sys.exit(0)
folder=pathlib.Path('/media')/str(uuid.uuid4());folder.mkdir()
env={**os.environ,'TIKTOK_ADAPTER_ENABLED':'1','TIKTOK_PHOTO_ENABLED':'1','VERIFIED_PLATFORMS':'tiktok',
 'PYTHONPATH':'/fixture:/app/apps/media/src','ADAPTER_MAX_INPUT':str(36*1024*1024),'ADAPTER_MAX_OUTPUT':str(16*1024*1024),
 'ADAPTER_ANALYZE_TIMEOUT':'30','ADAPTER_PREPARE_TIMEOUT':'180','EGRESS_TLS_MEDIA_FIXTURE':'1'}
URL='https://www.tiktok.com/@fixture/photo/7000000000000000001'
calls=[]
try:
    def call(phase,selected=None,url=URL,label=None):
        r=subprocess.run(['python3','/app/infra/media_adapter.py',phase,url,str(folder)]+([selected] if selected else []),env=env,capture_output=True,text=True,timeout=33 if phase=='analyze' else 183)
        # Neither private HTML nor source URL ever becomes evidence/log output.
        assert 'FAKE' not in r.stdout and 'FAKE' not in r.stderr
        p=json.loads(r.stdout.strip().splitlines()[-1]);calls.append(dict(phase=label or phase,actualExit=r.returncode,packet=p));assert r.returncode==0
        return p
    meta=call('analyze');assert meta['kind']=='photo';p=call('prepare',meta['formats'][1]['id']);assert p['file']=='image.jpg' and p['selectedIndex']==2
    image=(folder/'image.jpg').read_bytes();assert image==(OUT/'input.jpg').read_bytes() and hashlib.sha256(image).hexdigest()==p['sha256']
    (OUT/'prepared-image.jpg').write_bytes(image)
    for name in ['tiktok-operations.jsonl','tiktok-boundaries.jsonl']:
        if (folder/name).exists():(OUT/name).write_bytes((folder/name).read_bytes())
    video=call('analyze',url='https://www.tiktok.com/@fixture/video/7000000000000000002',label='video-analyze')
    assert video['formats'] and video['duration']==2
    (OUT/'media-result.json').write_text(json.dumps(dict(status='PASS_ACTUAL_CLI_PROXY_TLS_FIXTURE',calls=calls,sourceCalls=0),indent=2))
finally:
    (OUT/'media-calls.json').write_text(json.dumps(calls,indent=2))
    (OUT/'stop').write_text('stop')
