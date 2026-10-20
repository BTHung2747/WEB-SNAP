"""Offline fixtures only; real extractor/downloader/native file contract are invoked by CLI children."""
import copy,hashlib,io,json,os,pathlib,subprocess,sys,time,types,uuid
import requests.exceptions as re
import urllib3.exceptions as ue
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import Budget,BoundedBody,versions
from tiktok.adapter import error_code
from tiktok.candidate_file import inspect_file,validate_contract
from tiktok.prepare_operations import Operations

OUT=pathlib.Path('/out');ROOT=OUT/'media';ROOT.mkdir()
results=[];native=[]
def run_native(args,timeout=15):
    start=time.monotonic()
    p=subprocess.run(args,capture_output=True,timeout=timeout)
    native.append({'operation':args[0],'actualExit':p.returncode,'seconds':time.monotonic()-start,'timeout':timeout})
    assert p.returncode==0
    return p.stdout
def media(name,seconds):
    path=OUT/(name+'.mp4')
    run_native(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','testsrc=size=64x64:rate=25',
      '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t',str(seconds),
      '-c:v','libx264','-preset','ultrafast','-threads','1','-filter_threads','1',
      '-pix_fmt','yuv420p','-c:a','aac','-b:a','32k',str(path)])
    return path
def probe(path):
    return json.loads(run_native(['ffprobe','-v','error','-show_entries',
      'stream=codec_type,codec_name,duration:format=format_name,duration:format_tags=major_brand',
      '-of','json',str(path)]))
files={name:media(name,seconds) for name,seconds in [('below',1.92),('equal',2),('above',2.12),('mismatch',1.5)]}
probes={name:probe(path) for name,path in files.items()}
assert float(probes['below']['format']['duration'])<2
assert float(probes['equal']['format']['duration'])==2
assert float(probes['above']['format']['duration'])>2

# A video stream alone exceeding the cap is rejected even if container duration is within it.
data=copy.deepcopy(probes['equal'])
next(s for s in data['streams'] if s['codec_type']=='video')['duration']='2.01'
try:validate_contract(data,2,2)
except RuntimeError as e:assert e.args==('DURATION_POLICY',)
else:raise AssertionError('video ceiling')
results.append({'case':'H264-ceiling-independent-of-container','error':'LIMIT_EXCEEDED'})

long=OUT/'over600.mp4'
run_native(['ffmpeg','-v','error','-nostdin','-stream_loop','-1','-i',str(files['equal']),
            '-t','601','-c','copy',str(long)])
long_probe=probe(long);assert float(long_probe['format']['duration'])>600
try:inspect_file(long,600,Operations(root=OUT,sink='over600-operations.jsonl'))
except RuntimeError as e:assert e.args==('DURATION_POLICY',)
else:raise AssertionError('600 ceiling')
assert not any(json.loads(x)['operation']=='DECODE' for x in (OUT/'over600-operations.jsonl').read_text().splitlines())
results.append({'case':'actual-over600-before-decode','error':'LIMIT_EXCEEDED','containerDuration':long_probe['format']['duration']})

# Exact exception objects and byte/deadline/request state survive body boundary failures.
class Raw:
    def __init__(self,error):self.error=error;self.calls=0
    def read(self,*args,**kwargs):
        self.calls+=1
        if self.calls==1:return b'abc'
        raise self.error
class Reply:
    def __init__(self,error):self.raw=Raw(error);self.closed=False
    def close(self):self.closed=True
for phase in ('metadata','prepare'):
    for kind in ('direct','wrapped','maxretry','request-read','protocol','fake-name','prior-byte'):
        inner=ue.ReadTimeoutError(None,None,'FIXTURE_SECRET')
        error={'direct':inner,'wrapped':re.ConnectionError(inner),
               'maxretry':ue.MaxRetryError(None,None,inner),'request-read':re.ReadTimeout('FIXTURE_SECRET'),
               'protocol':ue.ProtocolError('FIXTURE_SECRET'),
               'fake-name':type('ReadTimeoutError',(Exception,),{})('FIXTURE_SECRET'),
               'prior-byte':inner}[kind]
        b=Budget(deadline=time.monotonic()+180)
        if phase=='prepare':b.prepare()
        row=b.sent();reply=Reply(error);body=BoundedBody(reply,b,row)
        assert body.read(3)==b'abc'
        before=(b.deadline,b.phase_deadline,b.total,b.network_total,b.requests,body.used)
        if kind=='prior-byte':b.failure='BYTE_LIMIT'
        try:body.read(1)
        except Exception as got:assert got is error
        else:raise AssertionError('missing error')
        assert before==(b.deadline,b.phase_deadline,b.total,b.network_total,b.requests,body.used)
        assert reply.closed and body.closed
        expected='LIMIT_EXCEEDED' if kind=='prior-byte' else 'CONTENT_UNAVAILABLE' if kind in ('protocol','fake-name') else 'SOURCE_TIMEOUT'
        assert error_code(error,b)==expected
        results.append({'case':'body-identity-'+phase+'-'+kind,'error':expected,'sameException':True,'unchangedBudgets':True,'decodedBytes':3})
for guard in ('BYTE_LIMIT','DEADLINE'):
    b=Budget(input_cap=2) if guard=='BYTE_LIMIT' else Budget(deadline=time.monotonic()-1)
    row={'decodedBytes':0};response=types.SimpleNamespace(raw=io.BytesIO(b'abc'),close=lambda:None)
    # BytesIO cannot take decode_content; delegate only in this fixture.
    response.raw=types.SimpleNamespace(read=lambda n,decode_content=True:b'abc')
    body=BoundedBody(response,b,row);deadline=b.deadline
    try:body.read()
    except Exception as e:assert b.failure==guard and error_code(e,b)==('SOURCE_TIMEOUT' if guard=='DEADLINE' else 'LIMIT_EXCEEDED')
    else:raise AssertionError('guard')
    assert b.deadline==deadline
    results.append({'case':'body-'+guard+'-unchanged','failure':guard,'networkBytes':b.network_total})

env={**os.environ,'MEDIA_ROOT':str(ROOT),'TIKTOK_ADAPTER_ENABLED':'1','TIKTOK_APP_FIXTURE':'1',
 'FIXTURE_CONTROL':str(OUT/'control'),'PYTHONPATH':'/fixture:/app/apps/media/src',
 'ADAPTER_ANALYZE_TIMEOUT':'30','ADAPTER_PREPARE_TIMEOUT':'180','ADAPTER_MAX_DURATION':'2'}
URL='https://www.tiktok.com/@fixture/video/7692288554839313682'
def job(mode):
    folder=ROOT/str(uuid.uuid4());folder.mkdir()
    control=OUT/'control'/folder.name;control.mkdir(parents=True)
    (control/'mode.json').write_text(json.dumps({'mode':mode}))
    return folder,control
def call(phase,folder,path,selected=None):
    p=subprocess.run(['python3','/app/infra/media_adapter.py',phase,URL,str(folder)]+([selected] if selected else []),
      env={**env,'FIXTURE_MEDIA_FILE':str(path)},capture_output=True,text=True,timeout=35 if phase=='analyze' else 185)
    assert all(secret not in p.stdout+p.stderr for secret in ('FAKE','FIXTURE_SECRET','fixture_cookie','__UNIVERSAL'))
    return p.returncode,json.loads(p.stdout.strip().splitlines()[-1])
for name in ('below','equal','above','mismatch'):
    folder,control=job('normal');rc,a=call('analyze',folder,files[name]);assert rc==0
    rc,b=call('prepare',folder,files[name],a['formats'][0]['id'])
    expected=None if name in ('below','equal') else 'LIMIT_EXCEEDED' if name=='above' else 'FORMAT_UNAVAILABLE'
    assert rc==(0 if expected is None else 1),(name,rc,b)
    if expected:assert b['error']==expected and not any((folder/n).exists() for n in ('media.mp4','media.mp4.part','media.mp4.ytdl'))
    else:
        assert b['file']=='media.mp4'
        assert hashlib.sha256((folder/'media.mp4').read_bytes()).digest()==hashlib.sha256(files[name].read_bytes()).digest()
        ops=[json.loads(x) for x in (folder/'tiktok-operations.jsonl').read_text().splitlines()]
        assert any(x['operation']=='DECODE' and x['event']=='END' and x['returncode']==0 for x in ops)
    results.append({'case':'CLI-duration-'+name,'actualExits':[0,rc],'error':expected,
                    'maxDuration':2,'metadataDuration':2,'probe':probes[name],'fullDecode':expected is None,'ownedCleanup':bool(expected)})
for target in ('meta','mp4'):
    for kind in ('direct','wrapped','protocol'):
        mode='body-'+kind+'-'+target;folder,control=job(mode if target=='meta' else 'normal')
        rc,a=call('analyze',folder,files['equal'])
        if target=='mp4':
            assert rc==0
            (control/'mode.json').write_text(json.dumps({'mode':mode}))
            rc,a=call('prepare',folder,files['equal'],a['formats'][0]['id'])
        expected='CONTENT_UNAVAILABLE' if kind=='protocol' else 'SOURCE_TIMEOUT'
        assert rc==1 and a['error']==expected,(mode,rc,a)
        assert not any((folder/n).exists() for n in ('media.mp4','media.mp4.part','media.mp4.ytdl'))
        events=[json.loads(x) for x in (control/'events.jsonl').read_text().splitlines()]
        results.append({'case':'CLI-'+mode,'actualExit':rc,'error':expected,'observedStatus':200,
                        'metadataGET':sum(e['event']=='metadata_GET' for e in events),'MP4GET':sum(e['event']=='MP4_GET' for e in events),'ownedCleanup':True})
folder,control=job('normal');rc,a=call('analyze',folder,files['above']);assert rc==0
for name in ('media.mp4','media.mp4.part','media.mp4.ytdl'):(folder/name).write_bytes(b'PREEXISTING')
rc,b=call('prepare',folder,files['above'],a['formats'][0]['id'])
assert rc==1 and b['error']=='INVALID_ASSET_PATH'
assert all((folder/name).read_bytes()==b'PREEXISTING' for name in ('media.mp4','media.mp4.part','media.mp4.ytdl'))
assert not any(json.loads(x)['event']=='MP4_GET' for x in (control/'events.jsonl').read_text().splitlines())
results.append({'case':'all-preexisting-preserved','actualExits':[0,1],'MP4GET':0})
OUT.joinpath('fixes-result.json').write_text(json.dumps({'status':'PASS','sourceCalls':0,'versions':versions(),'native':native,'results':results},indent=2))
print('PASS targeted duration/body-timeout fixtures; native decode and CLI exits; source0')
