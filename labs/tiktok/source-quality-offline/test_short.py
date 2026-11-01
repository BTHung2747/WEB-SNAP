"""Short-link delta; real Requests preparation/parser/core with in-memory HTTP replies."""
import hashlib,io,json,os,pathlib,subprocess,sys,time,types,uuid
sys.path.insert(0,'/app/apps/media/src');sys.path.insert(0,'/app/apps/egress/src')
import requests,urllib3
from tiktok.shortlink import route,resolve_short,analyze_short,ShortError
from tiktok import adapter
from tiktok.core import versions
from tiktok_policy.control import Broker
OUT=pathlib.Path('/out');ROOT=OUT/'media';ID='7678642036060228885'
CANON=f'https://www.tiktok.com/@fixture/video/{ID}'
PHOTO=CANON.replace('/video/','/photo/');SHORT='https://vt.tiktok.com/FAKEcode'
MEDIA='https://media.tiktokcdn.com/FAKE_media'

def factory(redirects,kind='video',fail_read=False):
    events=[];sessions=[];replies=[]
    class Session(requests.Session):
        def __init__(self):super().__init__();sessions.append(self)
        def get_adapter(self,url):return types.SimpleNamespace(send=self.reply)
        def reply(self,prepared,**options):
            assert prepared.method=='GET' and options['verify'] and options['stream'] and not self.trust_env
            assert options['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
            events.append(prepared.url)
            if prepared.url in redirects:
                headers=urllib3.HTTPHeaderDict({'Location':redirects[prepared.url]});body=b'UNREAD_REDIRECT_BODY';status=302
            elif prepared.url==CANON:
                item={'id':ID,'desc':'Short fixture','author':{'uniqueId':'fixture'},
                      'video':{'duration':2,'width':576,'height':576,'playAddr':MEDIA}}
                if kind=='photo':item['imagePost']={'images':[{'imageWidth':64,'imageHeight':64,'imageURL':{'urlList':['https://media.tiktokcdn.com/FAKE.jpeg?x=1']}}]}
                body=('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps({'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}})+'</script>').encode()
                headers={'content-type':'text/html','content-length':str(len(body))};status=200
            elif prepared.url==MEDIA:
                body=pathlib.Path('/inputs/h264.mp4').read_bytes();headers={'content-type':'video/mp4','content-length':str(len(body))};status=200
            else:raise RuntimeError('FAKE_UNEXPECTED_REQUEST')
            raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers=headers,preload_content=False,decode_content=False)
            if status==302:
                raw.read=lambda *a,**k: (_ for _ in ()).throw(AssertionError('redirect body consumed'))
            response=types.SimpleNamespace(status_code=status,headers=headers,raw=raw,closed=False)
            def close():response.closed=True;raw.close()
            response.close=close;replies.append(response);return response
    return Session,events,sessions,replies

def authorization(url):
    os.environ.update(WED_MEDIA_PROFILE='tiktok-short-analyze',WED_MEDIA_SELECTION='ts1_'+hashlib.sha256(route(url)['url'].encode()).hexdigest())

def child():
    phase,kind,folder,selected=sys.argv[2:6];target=PHOTO if kind=='photo' else CANON
    Session,events,sessions,replies=factory({SHORT:'https://vm.tiktok.com/FAKEnext','https://vm.tiktok.com/FAKEnext':target+'/?sender_device=pc#track'},kind)
    authorization(SHORT)
    if phase=='prepare':os.environ.pop('WED_MEDIA_PROFILE');os.environ.pop('WED_MEDIA_SELECTION')
    try:
        result=analyze_short(SHORT,folder,Session) if phase=='analyze' else adapter.execute('prepare',CANON,folder,selected,Session)
        print(json.dumps(result));return 0
    except Exception as error:
        print(json.dumps({'error':adapter.error_code(error)}));return 1
    finally:(OUT/(pathlib.Path(folder).name+'-'+phase+'.json')).write_text(json.dumps({'pid':os.getpid(),'gets':len(events),
        'shortGets':sum(route(u)['kind']=='short' for u in events if '.tiktok.com' in u and 'tiktokcdn' not in u),
        'allClosed':all(r.closed for r in replies),'cookiesCleared':all(not s.cookies for s in sessions)}))

def main():
    ROOT.mkdir();os.environ.update(MEDIA_ROOT=str(ROOT),TIKTOK_ADAPTER_ENABLED='1',TIKTOK_VIDEO_ENABLED='1',TIKTOK_PHOTO_ENABLED='1',VERIFIED_PLATFORMS='tiktok')
    versions();results=[]
    for source in ('https://vt.tiktok.com/FAKEcode/','https://vm.tiktok.com/FAKEcode/',
                   'https://www.tiktok.com/t/FAKEcode/','https://tiktok.com/t/FAKEcode/'):
        for target in (CANON,PHOTO):
            authorization(source);Session,events,sessions,replies=factory({route(source)['url']:target+'/?is_from_webapp=1#tracking'})
            result=resolve_short(source,time.monotonic()+30,Session)
            assert result['url']==target and result['id']==ID and len(events)==1
            assert all(r.closed for r in replies) and all(not s.cookies for s in sessions)
    results.append({'case':'vt-vm-www-t-apex-t-to-video-photo','cases':8,'redirectBodyReads':0,'allClosed':True})
    for target in ('http://www.tiktok.com/@fixture/video/'+ID,'https://127.0.0.1/video/'+ID,
                   'https://www.tiktok.com.evil.invalid/@fixture/video/'+ID,'https://user@www.tiktok.com/@fixture/video/'+ID,
                   'https://www.tiktok.com:443/@fixture/video/'+ID,'https://www.tiktok.com/live',
                   'https://www.tiktok.com/t/FAKE/extra','/bad%2fpath','https://www.tiktok.com/\nBAD'):
        authorization(SHORT);Session,events,sessions,replies=factory({SHORT:target})
        try:resolve_short(SHORT,time.monotonic()+30,Session)
        except ShortError:pass
        else:raise AssertionError('bad redirect accepted')
        assert len(events)==1 and all(r.closed for r in replies)
    for chain in ({SHORT:SHORT},{SHORT:'https://vm.tiktok.com/FAKEtwo','https://vm.tiktok.com/FAKEtwo':'https://vt.tiktok.com/FAKEthree'}):
        authorization(SHORT);Session,events,sessions,replies=factory(chain)
        try:resolve_short(SHORT,time.monotonic()+30,Session)
        except ShortError:pass
        else:raise AssertionError('redirect budget')
        assert len(events)<=2 and all(r.closed for r in replies)
    results.append({'case':'bad-location-IP-userinfo-port-loop-overflow','cases':11,'noDisallowedFollow':True})
    authorization(SHORT);os.environ['WED_MEDIA_SELECTION']='ts1_'+'0'*64
    Session,events,_,_=factory({SHORT:CANON})
    try:resolve_short(SHORT,time.monotonic()+30,Session)
    except ShortError:pass
    else:raise AssertionError('profile hash')
    assert not events;results.append({'case':'short-profile-source-binding-deny-before-send','gets':0})
    for kind in ('video','photo'):
        folder=ROOT/str(uuid.uuid4());folder.mkdir()
        p=subprocess.run([sys.executable,__file__,'--child','analyze',kind,str(folder),'-'],capture_output=True,text=True,timeout=35)
        assert p.returncode==0,(kind,p.stdout)
        data=json.loads(p.stdout);receipt=json.loads((OUT/(folder.name+'-analyze.json')).read_text())
        assert data['resolved']['kind']==kind and data['resolved']['url']==(PHOTO if kind=='photo' else CANON)
        assert receipt['gets']==3 and receipt['shortGets']==2 and receipt['allClosed'] and receipt['cookiesCleared']
        (OUT/(kind+'-metadata.json')).write_text(json.dumps(data))
        if kind=='video':
            selected=data['formats'][0]['id']
            p=subprocess.run([sys.executable,__file__,'--child','prepare',kind,str(folder),selected],capture_output=True,text=True,timeout=185)
            assert p.returncode==0,p.stdout
            ready=json.loads(p.stdout);prepared=json.loads((OUT/(folder.name+'-prepare.json')).read_text())
            assert prepared['shortGets']==0 and prepared['gets']==2 and prepared['pid']!=receipt['pid']
            assert hashlib.sha256((folder/'media.mp4').read_bytes()).digest()==hashlib.sha256(pathlib.Path('/inputs/h264.mp4').read_bytes()).digest()
        results.append({'case':'short-analyze-canonical-'+kind,'analyzeExit':0,'GET':3,'prepareCanonicalNoResolve':kind=='video'})
    os.environ.update(TIKTOK_VIDEO_ENABLED='0');authorization(SHORT)
    Session,events,_,_=factory({SHORT:CANON})
    try:analyze_short(SHORT,str(ROOT/str(uuid.uuid4())),Session)
    except ShortError as error:assert error.args==('UNSUPPORTED_PLATFORM',)
    else:raise AssertionError('video gate')
    assert events==[SHORT];results.append({'case':'resolved-kind-gate-before-metadata','gets':1})
    os.environ.update(TIKTOK_VIDEO_ENABLED='1',TIKTOK_EGRESS_CONTROL_SECRET='a'*64,TIKTOK_EGRESS_CONTROL_NETWORKS='127.0.0.0/8')
    broker=Broker();p=dict(op='open',id='a'*64,job='b'*64,phase='analyze',deadline=int(time.time()*1000+25000),v=2,profile='tiktok-short-analyze',selection='ts1_'+hashlib.sha256(SHORT.encode()).hexdigest())
    reply=broker.command(p)
    for n in range(4):broker.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid=str(n)))
    try:broker.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid='extra'))
    except ValueError:pass
    else:raise AssertionError('short connect cap')
    request={**p,'op':'seal','epoch':reply['epoch'],'selection':'ts1_'+'0'*64};request.pop('deadline')
    assert broker.command(request)['state']=='REJECTED'
    try:broker.command({**p,'id':'c'*64,'phase':'prepare'})
    except ValueError:pass
    else:raise AssertionError('short prepare forbidden')
    results.append({'case':'short-profile-cap4-tamper-phase','canonicalBudgetsUnchanged':True})
    (OUT/'short-result.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,'results':results},indent=2))
    print('PASS short-link delta '+str(len(results))+' groups')
if __name__=='__main__':
    if '--child' in sys.argv:raise SystemExit(child())
    main()
