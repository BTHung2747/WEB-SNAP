import hashlib,json,os,pathlib,subprocess,sys,uuid
OUT=pathlib.Path('/out');ROOT=OUT/'media';ROOT.mkdir(exist_ok=True)
fixture=OUT/'input.mp4'
p=subprocess.run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','testsrc=size=64x64:rate=25',
 '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','2','-c:v','libx264','-preset','ultrafast',
 '-threads','1','-filter_threads','1','-pix_fmt','yuv420p','-c:a','aac','-b:a','32k',str(fixture)],
 stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10);assert p.returncode==0
env={**os.environ,'MEDIA_ROOT':str(ROOT),'TIKTOK_ADAPTER_ENABLED':'1','TIKTOK_APP_FIXTURE':'1',
 'FIXTURE_MEDIA_FILE':str(fixture),'FIXTURE_CONTROL':'/out/control','PYTHONPATH':'/fixture:/app/apps/media/src',
 'ADAPTER_ANALYZE_TIMEOUT':'30','ADAPTER_PREPARE_TIMEOUT':'180'}
URL='https://www.tiktok.com/@fixture/video/7692288554839313682';results=[]
def call(phase,folder,format=None,extra=None,url=URL):
    args=['python3','/app/infra/media_adapter.py',phase,url,str(folder)]+([format] if format else [])
    p=subprocess.run(args,env={**env,**(extra or {})},capture_output=True,text=True,timeout=35 if phase=='analyze' else 185)
    data=json.loads(p.stdout.strip().splitlines()[-1])
    assert 'FAKE' not in p.stdout and 'FAKE' not in p.stderr
    return p.returncode,data
def job(mode='normal'):
    folder=ROOT/str(uuid.uuid4());folder.mkdir()
    control=OUT/'control'/folder.name;control.mkdir(parents=True)
    (control/'mode.json').write_text(json.dumps({'mode':mode}))
    return folder,control
folder,control=job();rc,a=call('analyze',folder);assert rc==0 and set(a)=={'title','duration','formats'} and a['formats'],(rc,a)
assert not (folder/'media.mp4').exists()
selected=a['formats'][0]['id'];rc,b=call('prepare',folder,selected);assert rc==0 and set(b)=={'file','size','inputBytes'} and b['file']=='media.mp4'
assert hashlib.sha256((folder/'media.mp4').read_bytes()).digest()==hashlib.sha256(fixture.read_bytes()).digest()
events=[json.loads(x) for x in (control/'events.jsonl').read_text().splitlines()]
assert len({e['pid'] for e in events if e['event']=='child_begin'})==2
assert len([e for e in events if e['event']=='metadata_GET'])==4
assert len([e for e in events if e['event']=='MP4_GET'])==1
assert b['inputBytes']>fixture.stat().st_size
results.append({'case':'separate-analyze-prepare','actualExits':[0,0],'metadataGET':[2,2],'MP4GET':1,
                'distinctChildren':True,'schemaUnchanged':True,'output':'media.mp4','bytes':b['size'],
                'sha256':hashlib.sha256(fixture.read_bytes()).hexdigest()})
for mode,expected in [('wrong-body','CONTENT_UNAVAILABLE'),('private','AUTH_REQUIRED'),('age','AUTH_REQUIRED'),
                      ('redirect','CONTENT_UNAVAILABLE'),('metadata-oversize','LIMIT_EXCEEDED'),
                      ('watermark-only','CONTENT_UNAVAILABLE')]:
    folder,control=job(mode);rc,data=call('analyze',folder);assert rc!=0 and data['error']==expected,(mode,rc,data)
    assert not (folder/'media.mp4').exists();results.append({'case':mode,'actualExit':rc,'error':data['error']})
folder,control=job('format-change');rc,a=call('analyze',folder);assert rc==0
rc,b=call('prepare',folder,a['formats'][0]['id']);assert rc!=0 and b['error']=='FORMAT_UNAVAILABLE'
assert not any(json.loads(x)['event']=='MP4_GET' for x in (control/'events.jsonl').read_text().splitlines())
results.append({'case':'fresh-format-changed','actualExit':rc,'error':b['error'],'MP4GET':0})
folder,control=job();rc,a=call('analyze',folder);assert rc==0
(folder/'media.mp4').write_bytes(b'PREEXISTING')
rc,b=call('prepare',folder,a['formats'][0]['id']);assert rc!=0 and (folder/'media.mp4').read_bytes()==b'PREEXISTING'
results.append({'case':'preexisting-preserved','actualExit':rc})
folder,control=job();rc,b=call('analyze',folder,extra={'TIKTOK_ADAPTER_ENABLED':'0'});assert rc!=0 and b['error']=='UNSUPPORTED_PLATFORM'
results.append({'case':'default-off','actualExit':rc})
folder,control=job();rc,b=call('analyze',folder,extra={'ADAPTER_MAX_DURATION':'1'});assert rc!=0 and b['error']=='LIMIT_EXCEEDED'
results.append({'case':'lower-duration-limit','actualExit':rc})
folder,control=job();rc,a=call('analyze',folder);assert rc==0
rc,b=call('prepare',folder,a['formats'][0]['id'],extra={'ADAPTER_PREPARE_TIMEOUT':'10'});assert rc!=0 and b['error']=='SOURCE_TIMEOUT'
assert not (folder/'media.mp4').exists();results.append({'case':'total10-reserve-exhausted','actualExit':rc})
folder,control=job();rc,a=call('analyze',folder);assert rc==0
rc,b=call('prepare',folder,a['formats'][0]['id'],extra={'ADAPTER_MAX_OUTPUT':'1024'});assert rc!=0 and b['error']=='LIMIT_EXCEEDED'
assert not (folder/'media.mp4').exists();results.append({'case':'lower-output-cap','actualExit':rc})
folder,control=job();rc,b=call('analyze',folder,extra={'ADAPTER_MAX_INPUT':'256'});assert rc!=0 and b['error']=='LIMIT_EXCEEDED'
results.append({'case':'lower-aggregate-input','actualExit':rc})
folder,control=job();alias=ROOT/str(uuid.uuid4());alias.symlink_to(folder,target_is_directory=True)
rc,b=call('analyze',alias);assert rc!=0 and b['error']=='INVALID_ASSET_PATH'
results.append({'case':'job-folder-symlink','actualExit':rc})
folder,control=job();rc,b=call('analyze',folder,url='https://vt.tiktok.com/FixtureShort');assert rc!=0 and b['error']=='UNSUPPORTED_CONTENT'
assert not any(json.loads(x)['event']=='metadata_GET' for x in (control/'events.jsonl').read_text().splitlines())
results.append({'case':'shortlink-not-supported-no-request','actualExit':rc})
folder,control=job();rc,a=call('analyze',folder);assert rc==0
(control/'mode.json').write_text(json.dumps({'mode':'wrong-body'}))
rc,b=call('prepare',folder,a['formats'][0]['id']);assert rc!=0 and b['error']=='CONTENT_UNAVAILABLE'
assert not any(json.loads(x)['event']=='MP4_GET' for x in (control/'events.jsonl').read_text().splitlines())
results.append({'case':'fresh-prepare-bodyID-mismatch','actualExit':rc,'MP4GET':0})
wrong=OUT/'wrong.mp4'
p=subprocess.run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','testsrc=size=32x32:rate=25',
 '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','2','-c:v','libx264','-preset','ultrafast',
 '-threads','1','-filter_threads','1','-pix_fmt','yuv420p','-c:a','aac','-b:a','32k',str(wrong)],
 stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10);assert p.returncode==0
folder,control=job('wrong-media-dimensions');rc,a=call('analyze',folder);assert rc==0
rc,b=call('prepare',folder,a['formats'][0]['id'],extra={'FIXTURE_WRONG_MEDIA_FILE':str(wrong)});assert rc!=0 and b['error']=='FORMAT_UNAVAILABLE'
assert not (folder/'media.mp4').exists()
results.append({'case':'actual-file-dimensions-mismatch-cleanup','actualExit':rc})
folder,control=job();rc,a=call('analyze',folder,url='https://www.youtube.com/watch?v=fixture0001');assert rc==0 and a['formats'][0]['id']=='18'
rc,b=call('prepare',folder,'18',url='https://www.youtube.com/watch?v=fixture0001');assert rc==0 and b['file']=='media.mp4'
results.append({'case':'legacy-youtube-branch-fixture','actualExits':[0,0],'realYouTubeSource':False})
OUT.joinpath('cli-result.json').write_text(json.dumps({'status':'PASS','sourceCalls':0,'results':results},indent=2))
print('PASS CLI two independent phases, workflow2+2+1GET, no secrets, fresh body/format, limits/output ownership/defaultoff/YouTube fixture')
