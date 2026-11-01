"""Offline preview delta. Real extractor, Cobalt photo parser and FFmpeg;
only source HTTP responses and parent control channel are fixtures.
"""
import hashlib, io, json, multiprocessing, os, pathlib, subprocess, sys, time, types, uuid
sys.path.insert(0, '/app/apps/media/src'); sys.path.insert(0, '/app/apps/egress/src')
import requests, urllib3
from tiktok import adapter, photo_core, preview_cache as cache
from tiktok.photo_contract import PhotoError
from tiktok_policy.control import Broker
OUT=pathlib.Path('/out'); ROOT=OUT/'media'; ID='7678642036060228885'
VIDEO=f'https://www.tiktok.com/@fixture/video/{ID}'; PHOTO=VIDEO.replace('/video/','/photo/')
IMAGE='https://media.tiktokcdn.com/FAKE_path_token/image.jpeg?token=FAKE_query_token'
SECOND='https://media.tiktokcdn.com/FAKE_second_path/image.jpeg?token=FAKE_query_token'
POSTER='https://media.tiktokcdn.com/FAKE_poster_token/cover.jpeg?token=FAKE_query_token'

class Events:
    """Single writer at a time (main or owned fork), bounded fixture counters."""
    names=['metadata','image','response-open','response-close','session-open','session-close']
    def __init__(self):self.values=multiprocessing.RawArray('i',513)
    def record(self,value):
        n=self.values[0];assert n<512;self.values[n+1]=self.names.index(value)+1;self.values[0]=n+1
    def all(self):return [self.names[self.values[n+1]-1] for n in range(self.values[0])]
    def append(self,value):self.record(value)
    def __iter__(self):return iter([v for v in self.all() if v in ('metadata','image')])
    def __len__(self):return len(list(iter(self)))
class Closures:
    def __init__(self,events,kind):self.events=events;self.kind=kind
    def __iter__(self):
        values=self.events.all();closed=values.count(self.kind+'-open')==values.count(self.kind+'-close')
        return iter([types.SimpleNamespace(closed=closed,cookies=[] if closed else ['UNCLOSED'])])

def factory(kind='photo', mode='ok'):
    events=Events(); replies=Closures(events,'response'); sessions=Closures(events,'session')
    class Session(requests.Session):
        def __init__(self): super().__init__();self.fake_closed=False;events.record('session-open')
        def close(self):
            if not self.fake_closed:
                super().close();self.fake_closed=True;events.record('session-close')
        def get_adapter(self,url): return types.SimpleNamespace(send=self.reply)
        def reply(self,prepared,**options):
            assert prepared.method=='GET' and options['verify'] is True and options['stream'] is True and not self.trust_env
            assert options['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
            assert options['timeout'].connect_timeout<=10 and options['timeout'].read_timeout<=20
            events.append('metadata' if prepared.url==VIDEO else 'image')
            status=200
            if prepared.url==VIDEO:
                item={'id':ID,'desc':'Preview fixture','author':{'uniqueId':'fixture'},
                    'video':{'duration':2,'width':576,'height':576,'playAddr':'https://media.tiktokcdn.com/FAKE.mp4','cover':POSTER,'originCover':POSTER}}
                if kind=='photo':
                    item['imagePost']={'images':[{'imageWidth':64,'imageHeight':64,'imageURL':{'urlList':[u]}} for u in ([IMAGE,SECOND] if mode=='album' else [IMAGE])]}
                body=('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps({'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}})+'</script>').encode(); mime='text/html'
            elif prepared.url in (IMAGE,POSTER,SECOND):
                if mode=='hold':time.sleep(5)
                body=(OUT/('changed.jpg' if mode=='changed' or prepared.url==SECOND else 'fixture.jpg')).read_bytes();mime='image/jpeg'
                if mode=='oversize': body=b'x'*(cache.SOURCE_CAP+1)
                if mode=='redirect': status=302
                if mode=='html': body=b'<html>FAKE_source_token</html>';mime='text/html'
                if mode=='timeout': raise requests.exceptions.ReadTimeout('FAKE_sensitive_message')
            else: raise AssertionError('UNEXPECTED_FAKE_SOURCE')
            raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers={'Content-Type':mime},preload_content=False,decode_content=False)
            if mode=='slow-body' and prepared.url!=VIDEO:
                original=raw.read
                def delayed(*args,**kwargs):time.sleep(5);return original(*args,**kwargs)
                raw.read=delayed
            response=types.SimpleNamespace(status_code=status,headers={'Content-Type':mime},raw=raw,closed=False)
            events.record('response-open')
            def close():
                if not response.closed:response.closed=True;raw.close();events.record('response-close')
            response.close=close;return response
    return Session,events,replies,sessions

def child():
    phase,url,folder,*rest=sys.argv[2:]; kind='photo' if '/photo/' in url else 'video'
    Session,events,replies,sessions=factory(kind,os.environ.get('FAKE_PREVIEW_MODE','ok'))
    code=0
    try:
        if kind=='photo':
            result=photo_core.analyze_album(url,folder,session_factory=Session) if phase=='analyze' else photo_core.prepare_photo(url,folder,rest[0],session_factory=Session)
        else: result=adapter.execute(phase,url,folder,rest[0] if rest else None,Session)
        if os.environ.get('FAKE_PREVIEW_MODE')=='exit20': code=20
        print(json.dumps(result),flush=True)
    except Exception as error:
        print(json.dumps({'error':error.code if isinstance(error,PhotoError) else adapter.error_code(error)}),flush=True);code=1
    finally:
        (OUT/(pathlib.Path(folder).name+'-'+phase+'-receipt.json')).write_text(json.dumps(dict(gets=list(events),allClosed=all(r.closed for r in replies),cookiesCleared=all(not s.cookies for s in sessions),actualExit=code)))
    return code

def fixture_media():
    for name,color in [('fixture.jpg','red'),('changed.jpg','blue')]:
        p=subprocess.run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i',f'color={color}:s=64x64','-frames:v','1','-threads','1',str(OUT/name)],capture_output=True,timeout=8)
        assert p.returncode==0

def unit():
    ROOT.mkdir(exist_ok=True);fixture_media();os.environ.update(WED_PREVIEW_REQUEST='1')
    cases=[]
    raw=cache.normalized(OUT/'fixture.jpg',time.monotonic()+5);jpg=cache.jpeg(raw,time.monotonic()+5)
    assert len(raw)==320*320*3 and len(jpg)<=131072 and jpg.startswith(b'\xff\xd8\xff')
    assert cache.normalized(OUT/'fixture.jpg',time.monotonic()+5)==raw
    assert cache.normalized(OUT/'changed.jpg',time.monotonic()+5)!=raw
    cases.append('FFmpeg-raster-normalization-deterministic-content-different')
    key='ttp1_01_'+'a'*64
    def grant(count,end): assert count==1;return (('a'*64,'b'*64),end)
    for mode in ('ok','oversize','redirect','html','timeout'):
        folder=ROOT/str(uuid.uuid4());folder.mkdir();Session,events,replies,sessions=factory(mode=mode)
        cache.generate(folder,[(key,IMAGE)],time.monotonic()+20,grant=grant,session_factory=Session)
        assert len(events)==1 and all(r.closed for r in replies) and all(not s.cookies for s in sessions)
        if mode=='ok':
            manifest=folder/'previews.pending.json';assert manifest.exists();manifest.rename(folder/'previews.json')
            p=json.loads((folder/'previews.json').read_bytes());e=p['entries'][0]
            assert e['normalizedSha256']==hashlib.sha256(raw).hexdigest() and 'FAKE' not in json.dumps(p)
            cache.verify_photo(folder,key,OUT/'fixture.jpg',time.monotonic()+5,16*1024*1024)
            try:cache.verify_photo(folder,key,OUT/'changed.jpg',time.monotonic()+5,16*1024*1024)
            except ValueError as error: assert error.args==('PREVIEW_CONTENT_CHANGED',)
            else:raise AssertionError('same-dimension reorder accepted')
        else: assert not list(folder.glob('preview*'))
        cases.append('optional-'+mode+'-close-and-owned-cleanup')
    # Default off: no grant, no HTTP; exhausted deadline: no HTTP.
    folder=ROOT/str(uuid.uuid4());folder.mkdir();Session,events,_,_=factory()
    os.environ.pop('WED_PREVIEW_REQUEST');cache.generate(folder,[(key,IMAGE)],time.monotonic()+5,grant=lambda *_:(_ for _ in ()).throw(AssertionError()),session_factory=Session)
    assert not events
    os.environ['WED_PREVIEW_REQUEST']='1';cache.generate(folder,[(key,IMAGE)],time.monotonic()-1,grant=lambda count,end:(('a'*64,'b'*64),end),session_factory=Session)
    assert not events
    cases.append('default-off-and-deadline-no-send')
    # A library raw.read can block beyond our soft budget despite socket timeout.
    # The HTTP-only fork has no decoder descendants, is killed/reaped directly.
    Session,events,_,_=factory(mode='slow-body');start=time.monotonic()
    try:cache.fetch(IMAGE,('a'*64,'b'*64),start+.2,cache.SOURCE_CAP,folder,Session)
    except ValueError as error:assert error.args==('PREVIEW_DEADLINE',)
    else:raise AssertionError('slow body escaped watchdog')
    elapsed=time.monotonic()-start;assert elapsed<1.5 and len(events)==1 and not multiprocessing.active_children()
    cases.append(dict(case='blocking-body-independent-deadline-kill-reap',elapsedSeconds=elapsed,liveChildren=0))
    # Existing cache cannot be overwritten/removed, symlink cannot be read.
    sentinel=folder/'preview-input.part';sentinel.write_bytes(b'owned-by-other')
    cache.generate(folder,[(key,IMAGE)],time.monotonic()+10,grant=grant,session_factory=Session)
    assert sentinel.read_bytes()==b'owned-by-other'
    sym=folder/'link';sym.symlink_to(OUT/'fixture.jpg')
    try:cache.normalized(sym,time.monotonic()+3)
    except OSError:pass
    else:raise AssertionError('symlink accepted')
    cases.append('preexisting-output-and-symlink-ownership')
    # Shared decoded aggregate cap and request count from the existing body API.
    from tiktok.core import Budget,BoundedBody
    b=Budget(cache.TOTAL_CAP,cache.JPEG_CAP,time.monotonic()+5);b.response_cap=4;b.total_cap=6;b.input_cap=6
    class Response:
        def __init__(self,data):self.raw=types.SimpleNamespace(read=io.BytesIO(data).read)
        def close(self):pass
    # urllib3-compatible decode_content argument, without a second transport.
    def body(data):
        stream=io.BytesIO(data);return types.SimpleNamespace(raw=types.SimpleNamespace(read=lambda n,decode_content=True:stream.read(n)),close=lambda:None)
    assert BoundedBody(body(b'abcd'),b,{}).read()==b'abcd'
    try:BoundedBody(body(b'efg'),b,{}).read()
    except Exception:assert b.network_total==7 and b.failure=='BYTE_LIMIT'
    else:raise AssertionError('aggregate bypass')
    cases.append('shared-streaming-response-and-aggregate-byte-cap')
    # Egress schema/count cap is opt-in and distinct from metadata's two.
    def packet(count):return dict(op='open',id=uuid.uuid4().hex*2,job='b'*64,phase='analyze',deadline=int((time.time()+20)*1000),v=2,profile='tiktok-preview-cache',selection=f'pv1_{count}_'+'c'*64)
    b=Broker();p=packet(3)
    os.environ.pop('TIKTOK_PREVIEW_ENABLED',None)
    try:b.command(p)
    except ValueError:pass
    else:raise AssertionError('disabled accepted')
    os.environ['TIKTOK_PREVIEW_ENABLED']='1';reply=b.command(p);b.enabled=True
    for i in range(3):b.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid=str(i)))
    try:b.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid='overflow'))
    except ValueError:pass
    else:raise AssertionError('preview count overflow')
    for count in (0,51):
        try:Broker().command(packet(count))
        except ValueError:pass
        else:raise AssertionError('bad count')
    canonical=Broker();p=dict(op='open',id='d'*64,job='e'*64,phase='analyze',deadline=int((time.time()+20)*1000));reply=canonical.command(p);canonical.enabled=True
    for i in range(2):canonical.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid=str(i)))
    try:canonical.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid='third'))
    except ValueError:pass
    else:raise AssertionError('metadata cap widened')
    cases.append('opt-in-counted-preview-broker-no-metadata-budget-widening')
    (OUT/'preview-python-result.json').write_text(json.dumps(dict(status='PASS',sourceRequests=0,cases=cases),indent=2));print('PASS preview Python groups'+str(len(cases)))

if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--child':sys.exit(child())
    unit()
