import hashlib,json,os,pathlib,subprocess,sys,time,uuid
sys.path.insert(0,'/app/apps/media/src')
from parent import pipeline
from worker import contract
from tiktok.prepare_operations import Operations
from tiktok.core import Budget,BoundedBody,versions
OUT=pathlib.Path('/out');fixture=OUT/'fixture.jpg'
p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc=size=64x64','-frames:v','1','-threads','1',
                  '-c:v','mjpeg',str(fixture)],capture_output=True,timeout=10);assert p.returncode==0
os.environ.update(TIKTOK_APP_FIXTURE='1',FIXTURE_MEDIA_FILE=str(fixture),FIXTURE_CONTROL='/out/control',
                  PYTHONPATH='/app/apps/media/src/tiktok/photo_lab:/app/apps/media/src',PYTHONWARNINGS='ignore')
URL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';ID='7678209751167110421';results=[]
for mode,expected in [('normal',None),('wrong-body','PHOTO_METADATA_UNAVAILABLE'),('private','PHOTO_METADATA_UNAVAILABLE'),
 ('age','PHOTO_METADATA_UNAVAILABLE'),('redirect','CONTENT_UNAVAILABLE'),('metadata-oversize','LIMIT_EXCEEDED'),
 ('metadata-timeout','SOURCE_TIMEOUT'),('image-timeout','SOURCE_TIMEOUT'),('image-html','JPEG_REQUIRED'),
 ('image-oversize','LIMIT_EXCEEDED'),('body-oversize','LIMIT_EXCEEDED'),('preexisting','PREEXISTING_OUTPUT')]:
 folder=OUT/str(uuid.uuid4());folder.mkdir()
 control=OUT/'control'/folder.name;control.mkdir(parents=True)
 (control/'mode.json').write_text(json.dumps({'mode':'normal' if mode=='preexisting' else mode}))
 if mode=='preexisting':
  (folder/'image.jpg').write_bytes(b'PREEXISTING');(folder/'image.jpg.part').write_bytes(b'PREEXISTING')
 start=time.monotonic()
 r,rc=pipeline(URL,ID,prepare=True,worker_argv=['python3','/app/apps/media/src/tiktok/photo_lab/worker.py','analyze',URL,str(folder),ID],
               prepare_seconds=60,output_dir=str(folder))
 assert rc==(0 if expected is None else 20),(mode,r)
 if expected:
  packet=r.get('preparePacket') or r.get('metadataPacket');assert packet['error']==expected,(mode,r)
  if mode!='preexisting':assert not (folder/'image.jpg').exists() and not (folder/'image.jpg.part').exists()
  else:assert all((folder/name).read_bytes()==b'PREEXISTING' for name in ('image.jpg','image.jpg.part'))
 else:
  assert r['workerActualExit']==0 and r['metadataPacket']['summary']['id']==ID
  assert [i['index'] for i in r['metadataPacket']['summary']['images']]==[1,2]
  assert hashlib.sha256((folder/'image.jpg').read_bytes()).digest()==hashlib.sha256(fixture.read_bytes()).digest()
  assert r['preparePacket']['contract']['fullDecode']=='PASS'
 events=[json.loads(x) for x in (control/'events.jsonl').read_text().splitlines()]
 assert sum(e['event']=='metadata_GET' for e in events)<=2 and sum(e['event']=='MP4_GET' for e in events)<=1
 encoded=json.dumps(r);assert all(s not in encoded for s in ('FAKEPATH','FAKESIGNED','fixture_cookie','FIXTURE_SECRET','__UNIVERSAL'))
 results.append({'case':mode,'parentActualExit':rc,'seconds':time.monotonic()-start,'metadataGET':sum(e['event']=='metadata_GET' for e in events),
                 'imageGET':sum(e['event']=='MP4_GET' for e in events),'result':r})
valid=contract(fixture,'image/jpeg',Operations(root=OUT,sink='direct-contract.jsonl'));assert valid['frames']==1
huge=OUT/'huge.jpg'
p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=size=8200x2','-frames:v','1','-threads','1','-c:v','mjpeg',str(huge)],
 capture_output=True,timeout=10);assert p.returncode==0
try:contract(huge,'image/jpeg',Operations(root=OUT,sink='huge-contract.jsonl'))
except RuntimeError as e:assert e.args==('PIXEL_LIMIT',)
else:raise AssertionError('pixel cap')
results.append({'case':'dimension-cap','error':'PIXEL_LIMIT','generatorActualExit':p.returncode})
pixels=OUT/'pixels.jpg'
p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=size=4096x4096','-frames:v','1','-threads','1','-c:v','mjpeg',str(pixels)],
 capture_output=True,timeout=10);assert p.returncode==0
try:contract(pixels,'image/jpeg',Operations(root=OUT,sink='pixels-contract.jsonl'))
except RuntimeError as e:assert e.args==('PIXEL_LIMIT',)
else:raise AssertionError('total pixel cap')
results.append({'case':'total-pixel-cap','error':'PIXEL_LIMIT','generatorActualExit':p.returncode})
# Independent parent deadline, packet PASS followed by nonzero, hung worker and owned partial cleanup.
for mode,code in [('exit20',"print('{\"stage\":\"metadata\",\"status\":\"PASS\"}',flush=True);input();print('{\"stage\":\"prepare\",\"status\":\"PASS\"}',flush=True);raise SystemExit(20)"),
                  ('hang',"import time;time.sleep(10)")]:
 folder=OUT/str(uuid.uuid4());folder.mkdir()
 code="import pathlib;pathlib.Path("+repr(str(folder/'image.jpg.part'))+").write_bytes(b'OWNED');"+code
 r,rc=pipeline(URL,ID,prepare=True,worker_argv=['python3','-c',code],metadata_seconds=.3,prepare_seconds=.3,output_dir=str(folder))
 assert rc==20 and not(folder/'image.jpg.part').exists()
 results.append({'case':'parent-'+mode,'result':r,'parentActualExit':rc})
# Actual decompressed read caps in the unchanged tested core, not Content-Length trust.
import io,types
for phase in ('response','aggregate'):
 b=Budget(deadline=time.monotonic()+30);b.network_total=b.total=0 if phase=='response' else 16*1024*1024
 class Raw:
  def read(self,n,decode_content=True):return b'X'*n
 body=BoundedBody(types.SimpleNamespace(raw=Raw(),close=lambda:None),b,{'decodedBytes':0})
 try:body.read()
 except Exception:assert b.failure=='BYTE_LIMIT'
 else:raise AssertionError('decoded cap')
 results.append({'case':'metadata-decoded-'+phase,'failure':b.failure,'total':b.total,'networkBytes':b.network_total})
OUT.joinpath('offline-result.json').write_text(json.dumps({'status':'PASS','sourceCalls':0,'versions':versions(),'results':results},indent=2))
core=pathlib.Path('/app/apps/media/src/tiktok')
inventory=[{'path':str(p.relative_to(core)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
           for p in core.rglob('*') if p.is_file() and 'photo_lab' not in p.parts and 'node_modules' not in p.parts and '__pycache__' not in p.parts]
OUT.joinpath('runtime-inventory.json').write_text(json.dumps(inventory,indent=2))
version=subprocess.run(['ffmpeg','-version'],capture_output=True,text=True,timeout=5)
assert version.returncode==0 and '5.1.9' in version.stdout.splitlines()[0]
print('PASS photo fixtures/ordered Cobalt picker/full JPEG decode/caps/timeout/ownership/parent exits; source0')
