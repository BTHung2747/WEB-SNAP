# Offline fake transport: execute real installed high-level TikTok extractor and native challenge path.
import base64,copy,hashlib,io,json,pathlib,time,types
import brotli,requests,urllib3
from yt_candidate import Budget,BoundedBody,Candidate,choose,versions
from yt_candidate_driver import pipeline
URL='https://www.tiktok.com/@fixture/video/7692808825228807442';ID='7692808825228807442'
PLAY='https://media.tiktokcdn.com/FAKEPATH?token=FAKEQUERY'
DOWNLOAD='https://media.tiktokcdn.com/FAKEDOWNLOAD?token=FAKEQUERY'
seed=b'fixture-only'
base=hashlib.sha256(seed);base.update(b'0') # Construct one known fixture expectation, not a solver.
payload=base64.b64encode(json.dumps({'v':{'a':base64.b64encode(seed).decode(),'c':base64.b64encode(base.digest()).decode()}}).encode()).decode()
CHALLENGE='<html>Please wait...<div id="cs" class="'+payload+'"></div><div id="wci" class="fixture_challenge"></div></html>'
def metadata(download_only=False,wrong_id=False):
    video={'duration':27,'width':720,'height':1280,'downloadAddr':DOWNLOAD}
    if not download_only:video['playAddr']=PLAY
    detail={'id':'7692808825228807443' if wrong_id else ID,'desc':'fixture','author':{'uniqueId':'fixture'},'video':video,'stats':{}}
    return '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps({'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':detail}}}})+'</script>'
class FakeResponse:
    def __init__(self,body,status=200):
        self.status_code=status;self.headers={'content-type':'text/html','content-encoding':'br'}
        if status==302:self.headers['location']='https://host.invalid/FAKEQUERY'
        self.raw=urllib3.HTTPResponse(body=io.BytesIO(brotli.compress(body.encode())),headers=self.headers,preload_content=False,decode_content=False)
        self.closed=False
    def close(self):self.closed=True;self.raw.close()
class FakeSession(requests.Session):
    def __init__(self,mode='challenge'):
        super().__init__();self.mode=mode;self.sent=[];self.challenge_cookie_seen=False
    def get_adapter(self,url):return types.SimpleNamespace(send=self.fake_send)
    def fake_send(self,prepared,**opts):
        assert opts['verify'] is True and opts['stream'] is True and opts['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
        assert not self.trust_env;assert prepared.method=='GET';assert prepared.url==URL
        self.sent.append(prepared)
        if self.mode=='redirect':return FakeResponse('X'*100000,302)
        if self.mode=='unsupported':return FakeResponse('<html>Please wait...</html>')
        if self.mode=='wrong-id':return FakeResponse(metadata(wrong_id=True))
        if self.mode=='repeat':return FakeResponse(CHALLENGE)
        if self.mode=='slow':
            self.deadline_hook();time.sleep(.03);return FakeResponse(metadata())
        if self.mode=='challenge' and len(self.sent)==1:return FakeResponse(CHALLENGE)
        if self.mode=='challenge':
            # Read generated cookie only in RAM; only boolean result is written as evidence.
            value=next(c.value for c in self.cookies if c.name=='fixture_challenge')
            decoded=json.loads(base64.b64decode(value))
            assert decoded['d']==base64.b64encode(b'0').decode()
            assert 'fixture_challenge=' in prepared.headers.get('Cookie','')
            self.challenge_cookie_seen=True
        return FakeResponse(metadata(self.mode=='download-only'))

results=[]
def record(name,**data):
    results.append({'case':name,**data});print('PASS yt-dlp high API '+name+'; fixture only')

versions()
fake=FakeSession()
with Candidate(session_factory=lambda:fake) as candidate:
    summary=candidate.analyze(URL,ID)
    assert summary['metadata']=='PASS' and summary['requestCount']==2 and summary['format']['format_id']=='play'
    assert candidate.selected['url']==PLAY and fake.challenge_cookie_seen and summary['bodyIdAndTypeVerifiedByCobalt']
    assert all(c.name!='fixture_challenge' for c in candidate.ydl.cookiejar) # Extractor cleared its short-lived challenge cookie.
    assert candidate.ydl.cookiejar.filename is None
    assert candidate.ydl.params['cookiefile'] is None and candidate.ydl.params['cookiesfrombrowser'] is None
    assert not any(k in summary for k in ('url','formats','cookies'))
    assert 'FAKE' not in json.dumps(summary)
assert len(fake.cookies)==0
record('native-challenge-refetch',metadata='FIXTURE_PASS',requests=2,nativeCookieGenerated=True,nativeCookieCleared=True,playSelected=True,cookieFile=False,file='NOT_RUN')

for mode,expected in [('unsupported','YTDLP_FAILURE'),('repeat','YTDLP_FAILURE'),('redirect','REDIRECT_DENIED'),('download-only','NO_ALLOWED_PLAY_FORMAT'),('wrong-id','COBALT_BODY_VALIDATION_FAILED')]:
    fake=FakeSession(mode);candidate=Candidate(session_factory=lambda:fake)
    try:
        candidate.analyze(URL,ID);raise AssertionError('Unexpected metadata success '+mode)
    except AssertionError:raise
    except Exception:
        if mode=='redirect':assert candidate.budget.failure==expected and len(fake.sent)==1 and candidate.budget.total==0
        if mode=='repeat':assert len(fake.sent)==2
        if mode=='download-only':assert candidate.selected is None and len(fake.sent)==1
        if mode=='wrong-id':assert candidate.selected is None and len(fake.sent)==1
    finally:candidate.ydl.close()
    record(mode,requests=len(fake.sent),metadata='FIXTURE_REJECTED',file='NOT_RUN')

fake=FakeSession('plain')
with Candidate(session_factory=lambda:fake) as candidate:
    candidate.ydl.allowed_url=URL
    for _ in range(2):
        response=candidate.ydl.urlopen(URL);response.read();response.close()
    try:candidate.ydl.urlopen(URL);raise AssertionError('Third request escaped')
    except AssertionError:raise
    except Exception:assert candidate.budget.failure=='REQUEST_LIMIT' and len(fake.sent)==2
record('request-cap-before-send',sent=2,thirdDenied=True)

fake=FakeSession('slow');budget=Budget()
fake.deadline_hook=lambda:setattr(budget,'deadline',time.monotonic()+.005)
with Candidate(session_factory=lambda:fake,budget=budget) as candidate:
    try:candidate.analyze(URL,ID);raise AssertionError('Deadline accepted')
    except AssertionError:raise
    except Exception:assert budget.failure=='DEADLINE' and len(fake.sent)==1
record('deadline-after-blocking-adapter',rejected=True)

def body(raw,budget):
    row=budget.sent();response=types.SimpleNamespace(raw=raw,close=raw.close)
    return BoundedBody(response,budget,row)
b=Budget()
raw=urllib3.HTTPResponse(body=io.BytesIO(brotli.compress(b'A'*(8*1024*1024+100))),headers={'content-encoding':'br'},preload_content=False,decode_content=False)
try:body(raw,b).read();raise AssertionError('Decoded response cap not enforced')
except AssertionError:raise
except Exception:assert b.failure=='BYTE_LIMIT' and b.total==8*1024*1024+1
record('actual-eight-MiB-Brotli-cap',decoded=b.total,rejectedWhileReading=True)
b=Budget();b.max_requests=3 # Only fixture exercises aggregate, production constant remains2.
for _ in range(2):
    fp=body(urllib3.HTTPResponse(body=io.BytesIO(b'A'*(8*1024*1024)),preload_content=False),b);assert len(fp.read())==8*1024*1024;fp.close()
try:body(urllib3.HTTPResponse(body=io.BytesIO(b'X'*20),preload_content=False),b).read();raise AssertionError('Aggregate not enforced')
except AssertionError:raise
except Exception:assert b.failure=='BYTE_LIMIT' and b.total==16*1024*1024+1
record('actual-sixteen-MiB-aggregate-cap',decoded=b.total,rejectedWhileReading=True)

with Candidate() as candidate:
    try:candidate.analyze(URL,ID);raise AssertionError('Default source should be disabled')
    except AssertionError:raise
    except Exception:assert candidate.budget.failure=='SOURCE_DISABLED' and candidate.budget.requests==0
result,code=pipeline(URL,ID);assert code==30 and result['sourceAttempts']==0
record('default-source-disabled',sourceAttempts=0)

# Exercise parent protocol/deadline ownership with fake child, no cookies/URLs/media.
argv=['python3','-c','import json,sys;print(json.dumps({"stage":"metadata","status":"PASS","summary":{"file":"NOT_RUN"}}),flush=True);sys.stdin.readline()']
result,code=pipeline('fixture','fixture',worker_argv=argv)
assert code==0 and result['status']=='METADATA_ONLY' and result['workerActualExit']==0
record('parent-metadata-only-protocol',actualExit=result['workerActualExit'],file='NOT_RUN')
start=time.monotonic()
result,code=pipeline('fixture','fixture',worker_argv=['python3','-c','while True: pass'],metadata_seconds=.15)
assert code==20 and result['workerActualExit']==-9 and result['workerSignal']==9 and time.monotonic()-start<2
record('parent-CPU-starvation-deadline',actualExit=result['workerActualExit'],signal=result['workerSignal'],productionDeadline=30,fixtureDeadline=.15)
script='import json,sys;print(json.dumps({"stage":"metadata","status":"PASS","summary":{"file":"NOT_RUN"}}),flush=True);sys.stdin.readline();exec("while True: pass")'
result,code=pipeline('fixture','fixture',prepare=True,worker_argv=['python3','-c',script],prepare_seconds=.15)
assert code==20 and result['workerActualExit']==-9 and result['workerSignal']==9
record('parent-prepare-deadline',actualExit=result['workerActualExit'],signal=result['workerSignal'],productionDeadline=180,fixtureDeadline=.15)
pathlib.Path('/out/candidate-fixtures.json').write_text(json.dumps({'environment':'network-none; fake adapter; real pinned extractor/challenge/API','sourceAttempts':0,'fileDownloads':0,'results':results},indent=2),encoding='utf8')
