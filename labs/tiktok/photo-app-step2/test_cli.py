import hashlib,json,os,pathlib,subprocess,uuid
import fixtures
out=pathlib.Path('/control');root=pathlib.Path('/media');rows=[]
p=subprocess.run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','color=c=blue:s=64x64','-frames:v','1','-threads','1','-filter_threads','1',str(out/'input.jpg')],timeout=10);assert p.returncode==0
env={**os.environ,'TIKTOK_ADAPTER_ENABLED':'1','TIKTOK_PHOTO_ENABLED':'1','VERIFIED_PLATFORMS':'youtube,tiktok'}
def call(phase,folder,selection=None,extra=None):
    p=subprocess.run(['python3','/app/infra/media_adapter.py',phase,fixtures.URL,str(folder)]+([selection] if selection else []),env={**env,**(extra or {})},capture_output=True,text=True,timeout=35)
    assert 'FAKE' not in p.stdout and 'FAKE' not in p.stderr
    data=json.loads(p.stdout.strip().splitlines()[-1]);return p.returncode,data
folder=root/str(uuid.uuid4());folder.mkdir();a,meta=call('analyze',folder);assert a==0 and meta['kind']=='photo' and meta['duration'] is None
b,p=call('prepare',folder,meta['formats'][1]['id']);assert b==0 and p['file']=='image.jpg' and p['selectedIndex']==2
assert p['sha256']==hashlib.sha256((out/'input.jpg').read_bytes()).hexdigest()
rows.append(dict(case='actual-cli-analyze-fresh-prepare-image2',exits=[a,b],sha256=p['sha256'],packet=p))
for extra in ({'TIKTOK_PHOTO_ENABLED':''},{'TIKTOK_PHOTO_ENABLED':'0'},{'TIKTOK_PHOTO_ENABLED':'true'},{'TIKTOK_ADAPTER_ENABLED':'0'},{'VERIFIED_PLATFORMS':'youtube'}):
    f=root/str(uuid.uuid4());f.mkdir();rc,d=call('analyze',f,extra=extra);assert rc and d['error']=='UNSUPPORTED_PLATFORM'
    events=[json.loads(s) for s in (out/f.name/'events.jsonl').read_text().splitlines()]
    assert not any(e['event']=='metadata_GET' for e in events);rows.append(dict(case='flags-reject-before-get',env=extra,actualExit=rc))
f=root/str(uuid.uuid4());f.mkdir();rc,d=call('analyze',f,extra={'ADAPTER_MAX_INPUT':'256'});assert rc and d['error']=='LIMIT_EXCEEDED';rows.append(dict(case='strict-small-input',actualExit=rc))
f=root/str(uuid.uuid4());f.mkdir();rc,d=call('prepare',f,meta['formats'][1]['id'],{'ADAPTER_PREPARE_TIMEOUT':'10'});assert rc and not (f/'image.jpg').exists();rows.append(dict(case='reserve-exhausted-cleanup',actualExit=rc))
(out/'cli-result.json').write_text(json.dumps(dict(status='PASS_OFFLINE_CLI',sourceCalls=0,cases=rows),indent=2))
print('PASS CLI fixture',len(rows),'cases')
