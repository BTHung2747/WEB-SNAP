"""Companion successor fixtures only, no source network or historical suite."""
import ast,copy,hashlib,io,json,os,pathlib,resource,subprocess,sys,time,types,uuid
sys.path.insert(0,'/app/apps/media/src');sys.path.insert(0,'/app/apps/egress/src')
import requests,urllib3
from video_policy import full_hd
from tiktok import adapter
from tiktok.video_selection import selections
from tiktok.core import Budget,GuardedYDL,versions
from tiktok.candidate_file import copy_pair,validate_contract
from tiktok.prepare_operations import Operations
from tiktok_policy.control import Broker

OUT=pathlib.Path('/out');ROOT=OUT/'media';INPUT=pathlib.Path('/inputs')
ID='7678642036060228885';URL=f'https://www.tiktok.com/@fixture/video/{ID}'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run(args,timeout=35):
    p=subprocess.run(args,capture_output=True,timeout=timeout)
    assert p.returncode==0,('NATIVE_FAIL',args[0],p.returncode)
    return p.stdout
def worker():
    phase,folder,mode,selected=sys.argv[2:6];folder=pathlib.Path(folder);gets=[];closed=[]
    urls={key:f'https://media.tiktokcdn.com/FAKE_{os.getpid()}/{key}' for key in ('play','hevc')}
    urls['hevc']+='/media-video-hvc1/'
    class Reply:
        def __init__(self,body,mime):
            self.status_code=200;self.headers={'content-type':mime,'content-length':str(len(body))}
            self.raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers=self.headers,preload_content=False,decode_content=False)
        def close(self):closed.append(1);self.raw.close()
    class Session(requests.Session):
        def get_adapter(self,url):return types.SimpleNamespace(send=self.reply)
        def reply(self,prepared,**opts):
            assert prepared.method=='GET' and opts['verify'] and opts['stream']
            assert opts['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
            if prepared.url==URL:
                gets.append('metadata')
                donor_codec='bytevc1' if phase=='prepare' and mode=='donor-changed' else 'h264'
                item={'id':ID,'desc':'Pair fixture','author':{'uniqueId':'fixture'},'video':{
                    'duration':2,'width':576,'height':576,'playAddr':urls['play'],
                    'bitrateInfo':[{'PlayAddr':{'UrlKey':f'vtest_{donor_codec}_540p_1000000','DataSize':(INPUT/'h264.mp4').stat().st_size,'UrlList':[urls['play']]}},
                                   {'PlayAddr':{'UrlKey':'vtest_bytevc1_720p_900000','DataSize':(INPUT/'silent.mp4').stat().st_size,'UrlList':[urls['hevc']]}}]}}
                if phase=='prepare' and mode=='wrong-body':item['id']=str(int(ID)+1)
                body={'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}}
                return Reply(('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps(body)+'</script>').encode(),'text/html')
            assert prepared.url in urls.values();key=next(k for k,v in urls.items() if v==prepared.url)
            gets.append(key);assert gets.count(key)==1
            if key=='play' and mode=='download-error':raise requests.exceptions.ReadTimeout('FAKE_SECRET')
            path=INPUT/('silent.mp4' if key=='hevc' else 'h264.mp4')
            if key=='play' and mode=='offset':path=OUT/'offset.mp4'
            return Reply(path.read_bytes(),'video/mp4')
    try:
        result=adapter.execute(phase,URL,str(folder),None if selected=='-' else selected,Session)
        print(json.dumps(result));return 0
    except Exception as error:
        print(json.dumps({'error':adapter.error_code(error)}));return 1
    finally:
        (OUT/(folder.name+'-'+phase+'.json')).write_text(json.dumps({'pid':os.getpid(),'gets':gets,'closed':len(closed)}))

def main():
    start=time.monotonic();ROOT.mkdir();os.environ['MEDIA_ROOT']=str(ROOT);v=versions();results=[]
    run(['ffmpeg','-v','error','-nostdin','-i',str(INPUT/'h264.mp4'),'-c','copy','-output_ts_offset','1',str(OUT/'offset.mp4')])
    def call(phase,folder,mode='normal',selected='-',profile=True):
        env={**os.environ}
        env.pop('WED_MEDIA_PROFILE',None);env.pop('WED_MEDIA_SELECTION',None)
        if phase=='prepare' and profile:env.update(WED_MEDIA_PROFILE='hevc-copy-pair',WED_MEDIA_SELECTION=selected)
        p=subprocess.run([sys.executable,__file__,'--worker',phase,str(folder),mode,selected],capture_output=True,text=True,env=env,timeout=185)
        assert 'FAKE_' not in p.stdout+p.stderr
        packet=json.loads(p.stdout.strip().splitlines()[-1]);r=json.loads((OUT/(folder.name+'-'+phase+'.json')).read_text())
        return p.returncode,packet,r
    folder=ROOT/str(uuid.uuid4());folder.mkdir();rc,info,a=call('analyze',folder);assert rc==0
    default=next(f for f in info['formats'] if f['sourceDefault']);pair=next(f for f in info['formats'] if f['selection']['audioSource'])
    assert default['height']==576 and pair['height']==720 and pair['highest']
    assert default['selection']['video']['id'].startswith('h264_') # play row deduped by the real extractor.
    (OUT/'metadata.json').write_text(json.dumps(info))
    rc,data,b=call('prepare',folder,selected=pair['id']);assert rc==0,(data,b)
    assert a['pid']!=b['pid'] and b['gets']==['metadata','hevc','play']
    assert not any(folder.glob('source-*'))
    def stream_hash(path,stream):
        output=run(['ffmpeg','-v','error','-i',str(path),'-map',stream,'-c','copy','-f','hash','-hash','sha256','-'])
        return output.decode().strip()
    assert stream_hash(folder/'media.mp4','0:v:0')==stream_hash(INPUT/'silent.mp4','0:v:0')
    assert stream_hash(folder/'media.mp4','0:a:0')==stream_hash(INPUT/'h264.mp4','0:a:0')
    ops=[json.loads(line) for line in (folder/'tiktok-operations.jsonl').read_text().splitlines()]
    assert all(any(e['operation']==op and e['event']=='END' and e['returncode']==0 for e in ops) for op in ('MUX','DECODE'))
    results.append({'case':'pair-real-extractor-two-children-stream-copy','exits':[0,0],'mediaGET':2,'inputBytes':data['inputBytes'],
                    'outputBytes':data['size'],'fileSHA256':digest(folder/'media.mp4'),'videoPacketHashSame':True,'audioPacketHashSame':True,'stagingRemoved':True})
    truncated=OUT/'truncated.mp4'
    try:copy_pair(INPUT/'silent.mp4',INPUT/'h264.mp4',truncated,2,
                  pair['selection']['video'],pair['selection']['audioSource'],
                  Operations(time.monotonic()+30,root=OUT,sink='truncation-operations.jsonl'),max(1024,data['size']//2),600)
    except RuntimeError as error:assert error.args[0] in ('STREAM_COPY_MISMATCH','DECODE_FAIL','MUX_FAIL')
    else:raise AssertionError('silent fs truncation accepted')
    results.append({'case':'mux-output-cap-no-silent-truncation','realSyntheticFiles':True,'refused':True})
    for mode,profile in [('normal',False),('donor-changed',True),('wrong-body',True),('offset',True),('download-error',True)]:
        folder=ROOT/str(uuid.uuid4());folder.mkdir();rc,_,_=call('analyze',folder);assert rc==0
        rc,packet,r=call('prepare',folder,mode,pair['id'],profile)
        assert rc==1 and 'error' in packet,(mode,rc,packet)
        media=len([g for g in r['gets'] if g!='metadata'])
        assert media== (2 if mode in ('offset','download-error') else 0),(mode,r)
        assert not any((folder/(n+s)).exists() for n in ('media.mp4','source-video.mp4','source-audio.mp4') for s in ('','.part','.ytdl'))
        results.append({'case':'pair-'+mode+('-no-profile' if not profile else ''),'exit':rc,'error':packet['error'],'mediaGET':media,'cleanup':True})
    # Single rendition still uses exactly one request, even if pair profile env exists.
    folder=ROOT/str(uuid.uuid4());folder.mkdir();rc,_,_=call('analyze',folder);assert rc==0
    rc,data,r=call('prepare',folder,selected=default['id']);assert rc==0 and r['gets']==['metadata','play']
    results.append({'case':'single-no-second-media','exit':rc,'mediaGET':1})
    folder=ROOT/str(uuid.uuid4());folder.mkdir();(folder/'source-audio.mp4').write_bytes(b'PREEXISTING')
    rc,packet,r=call('prepare',folder,selected=pair['id'])
    assert rc==1 and packet['error']=='INVALID_ASSET_PATH' and r['gets']==['metadata']
    assert (folder/'source-audio.mp4').read_bytes()==b'PREEXISTING'
    results.append({'case':'preexisting-staging-preserved','mediaGET':0,'exit':1})
    # Runtime request guard, not just schema: duplicate/third URL denied before Adapter.send.
    budget=Budget(deadline=time.monotonic()+180);dummy=ROOT/str(uuid.uuid4());dummy.mkdir()
    ydl=GuardedYDL(budget,dummy,requests.Session)
    budget.prepare(2);ydl.media_urls={'https://media.tiktokcdn.com/a','https://media.tiktokcdn.com/b'}
    ydl.used_media_urls.add('https://media.tiktokcdn.com/a')
    for url in ('https://media.tiktokcdn.com/a','https://media.tiktokcdn.com/c'):
        try:ydl.urlopen(url)
        except Exception:assert budget.failure=='REQUEST_POLICY' and budget.requests==0
        else:raise AssertionError('URL policy')
    ydl.close();results.append({'case':'exact-urls-duplicate-and-third-denied','adapterSends':0})
    # Native-format boundaries, including portrait; no 2K, no scale.
    for dims,allowed in [((1920,1080),True),((1080,1920),True),((1080,1080),True),((2560,1440),False),((1440,2560),False),((1921,1080),False)]:assert full_hd(*dims)==allowed
    results.append({'case':'full-HD-orientation-boundaries','landscapePortraitSquare':True,'reject1440':True})
    # Projection of native metadata/probe boundaries, not a source1080 acceptance.
    formats=[dict(format_id=f'h264_{i}p_1000',vcodec='h264',acodec='aac',ext='mp4',protocol='https',
                  url=f'https://media.tiktokcdn.com/{i}',width=w,height=h,filesize=100)
             for i,(w,h) in enumerate(((1920,1080),(1080,1920),(1080,1080),(2560,1440),(1440,2560)))]
    native_rows,_=selections(dict(id=ID,duration=2,formats=formats),ID,1000)
    assert len(native_rows)==3 and all(not r['sourceDefault'] for r in native_rows)
    probe=json.loads(run(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name,width,height,duration:format=format_name,duration:format_tags=major_brand','-of','json',str(INPUT/'h264.mp4')]))
    for dims,accepted in [((1920,1080),True),((1080,1920),True),((1080,1080),True),((2560,1440),False)]:
        data_probe=copy.deepcopy(probe);video=next(s for s in data_probe['streams'] if s['codec_type']=='video')
        video.update(width=dims[0],height=dims[1])
        try:validate_contract(data_probe,2,expected_acodec='aac')
        except RuntimeError as error:assert not accepted and error.args==('VIDEO_DIMENSION_POLICY',)
        else:assert accepted
    results.append({'case':'TikTok-native-and-probe-FullHD','projectionOnly':True,'accepted':3,'unknownDefaultHonest':True})
    # Reuse the actual YouTube formatter definition without executing its CLI/network branch.
    source=pathlib.Path('/app/infra/media_adapter.py').read_text();tree=ast.parse(source)
    fmt=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='formats')
    namespace={'full_hd':full_hd,'max_output':200*1024*1024,'max_input':250*1024*1024}
    exec(compile(ast.Module(body=[fmt],type_ignores=[]),'youtube-formats','exec'),namespace)
    fs=[dict(format_id=str(i),ext='mp4',protocol='https',vcodec='avc1',acodec='aac',width=w,height=h,filesize=100) for i,(w,h) in enumerate(((576,576),(1920,1080),(1080,1920),(2560,1440)))]
    rows=namespace['formats']({'formats':fs,'format_id':'0'})
    assert not any(r['sourceDefault'] for r in rows) and len(rows)==3 and sum(r['highest'] for r in rows)==2
    results.append({'case':'YouTube-native-formatter-default-and-HD','projectionOnly':True,'accepted':len(rows)})
    # Strict broker v2 profile/selection/epoch binding, legacy caps preserved.
    os.environ.update(TIKTOK_EGRESS_CONTROL_SECRET='a'*64,TIKTOK_EGRESS_CONTROL_NETWORKS='127.0.0.0/8')
    for profile,phase,limit in [(False,'analyze',2),(False,'prepare',3),(True,'prepare',4)]:
        broker=Broker();p=dict(op='open',id=uuid.uuid4().hex*2,job='b'*64,phase=phase,deadline=int(time.time()*1000+20000))
        if profile:p.update(v=2,profile='hevc-copy-pair',selection=pair['id'])
        reply=broker.command(p);assert reply['state']=='OPEN'
        for n in range(limit):broker.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid=str(n)))
        try:broker.attach((p['id'],reply['connectKey']),types.SimpleNamespace(cid='overflow'))
        except ValueError:pass
        else:raise AssertionError('broker cap')
    broker=Broker();p=dict(op='open',id='c'*64,job='b'*64,phase='prepare',deadline=int(time.time()*1000+20000),v=2,profile='hevc-copy-pair',selection=pair['id'])
    reply=broker.command(p)
    for changed in ({'selection':'tt2_'+'0'*64},{'epoch':'0'*64},{'job':'0'*64}):
        request={**p,'op':'seal','epoch':reply['epoch'],**changed};request.pop('deadline')
        assert broker.command(request)['state']=='REJECTED'
    invalid={**p,'id':'d'*64,'phase':'analyze'}
    try:broker.command(invalid)
    except ValueError:pass
    else:raise AssertionError('pair-analyze')
    results.append({'case':'broker-profile-tamper-and-caps','analyze':2,'singlePhoto':3,'pair':4,'selectionEpochJobTamperRejected':True})
    result={'status':'PASS','sourceRequests':0,'versions':v,'results':results,'elapsedSeconds':time.monotonic()-start,
            'maxRssSelfKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'maxRssChildrenKiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss}
    (OUT/'pair-result.json').write_text(json.dumps(result,indent=2));print('PASS companion delta '+str(len(results))+' groups')

if __name__=='__main__':
    if '--worker' in sys.argv:raise SystemExit(worker())
    main()
