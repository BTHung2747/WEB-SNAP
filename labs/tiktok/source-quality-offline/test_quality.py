"""Offline only: real pinned extractor/downloader + synthetic MP4 through a RAM Session double."""
import copy,hashlib,io,json,os,pathlib,subprocess,sys,time,types,uuid
sys.path.insert(0,'/app/apps/media/src')
import requests,urllib3
from tiktok import adapter
from tiktok.core import versions
from tiktok.candidate_file import validate_contract

OUT=pathlib.Path('/out');ROOT=OUT/'media'
ID='7678642036060228885';URL=f'https://www.tiktok.com/@fixture/video/{ID}'

def worker():
    phase,folder,mode,selected=sys.argv[2:6];folder=pathlib.Path(folder)
    events=[];media_count=0
    # Different ephemeral URLs in every child must yield the same public identity.
    urls={kind:f'https://media.tiktokcdn.com/FAKE_PATH_{os.getpid()}/{kind}?token=FAKE_TOKEN'
          for kind in ('h264','hevc','low')}
    if mode=='marked-video-only':urls['hevc']+='&/media-video-hvc1/'
    class Reply:
        def __init__(self,body,mime):
            self.status_code=200
            self.headers={'content-type':mime,'content-length':str(len(body))}
            self.raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers=self.headers,preload_content=False,decode_content=False)
        def close(self):self.raw.close()
    class FakeSession(requests.Session):
        def get_adapter(self,url):return types.SimpleNamespace(send=self.reply)
        def reply(self,prepared,**kwargs):
            nonlocal media_count
            assert prepared.method=='GET' and kwargs['stream'] and kwargs['verify']
            assert kwargs['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
            assert not self.trust_env
            if prepared.url==URL:
                events.append('METADATA_GET');assert events.count('METADATA_GET')<=2
                def bitrate(key,height,size):
                    codec='h264' if key=='h264' else 'bytevc1'
                    codec='h264' if phase=='prepare' and mode=='changed-codec' and key=='hevc' else codec
                    return {'PlayAddr':{'UrlKey':f'vfixture_{codec}_{height}p_1000000',
                        'UrlList':[urls[key]],'DataSize':size}}
                item={'id':ID,'desc':'Synthetic quality fixture','author':{'uniqueId':'fixture'},
                      'video':{'duration':2,'width':576,'height':576,'playAddr':urls['h264'],
                       'downloadAddr':'https://media.tiktokcdn.com/FAKE_DOWNLOAD',
                       'bitrateInfo':[bitrate('h264',540,(OUT/'h264.mp4').stat().st_size),
                                      bitrate('hevc',720,(OUT/'hevc.mp4').stat().st_size),
                                      bitrate('low',360,None)]}}
                if mode=='marked-video-only':
                    # Use a path recognized by the official extractor, not a fake codec flag.
                    item['video']['bitrateInfo'][1]['PlayAddr']['UrlList']=[f'https://media.tiktokcdn.com/FAKE_PATH_{os.getpid()}/media-video-hvc1/']
                if phase=='prepare' and mode=='changed-duration':item['video']['duration']=3
                body={'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}}
                return Reply(('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'
                              +json.dumps(body)+'</script>').encode(),'text/html')
            media_count+=1;assert media_count==1 and prepared.url in urls.values()
            events.append('MP4_GET')
            kind=next(key for key,value in urls.items() if value==prepared.url)
            name='h264' if kind=='h264' or mode=='actual-wrong-codec' else 'hevc'
            if mode=='actual-silent':name='silent'
            if mode=='actual-wrong-dimensions':name='small'
            return Reply((OUT/(name+'.mp4')).read_bytes(),'video/mp4')
    try:
        result=adapter.execute(phase,URL,str(folder),None if selected=='-' else selected,FakeSession)
        print(json.dumps(result));return 0
    except Exception as error:
        print(json.dumps({'error':adapter.error_code(error)}));return 1
    finally:
        (OUT/(folder.name+'-'+phase+'.json')).write_text(json.dumps({
            'phase':phase,'pid':os.getpid(),'metadataGET':events.count('METADATA_GET'),'mediaGET':media_count}))

def tests():
    ROOT.mkdir();os.environ['MEDIA_ROOT']=str(ROOT)
    v=versions();native=[];results=[]
    def run(args,timeout=30):
        start=time.monotonic();p=subprocess.run(args,capture_output=True,timeout=timeout)
        native.append({'tool':args[0],'actualExit':p.returncode,'elapsed':round(time.monotonic()-start,3)})
        assert p.returncode==0,('NATIVE_FAIL',args[0],p.returncode)
        return p.stdout
    ffmpeg=run(['ffmpeg','-version'],5).decode().splitlines()[0];assert '5.1.9' in ffmpeg
    def generate(name,codec,width):
        options=['-c:v','libx264','-preset','ultrafast','-threads','1'] if codec=='h264' else [
            '-c:v','libx265','-preset','ultrafast','-x265-params','pools=none:frame-threads=1:wpp=0','-threads','1','-tag:v','hvc1']
        run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i',f'testsrc2=size={width}x{width}:rate=10',
             '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','2',*options,
             '-filter_threads','1','-pix_fmt','yuv420p','-c:a','aac','-b:a','32k',str(OUT/(name+'.mp4'))])
    generate('h264','h264',576);generate('hevc','hevc',720);generate('small','hevc',64)
    run(['ffmpeg','-v','error','-nostdin','-i',str(OUT/'hevc.mp4'),'-map','0:v:0','-an','-c:v','copy',str(OUT/'silent.mp4')])
    run(['ffmpeg','-v','error','-nostdin','-i',str(OUT/'hevc.mp4'),'-c','copy','-f','matroska',str(OUT/'wrong-container.mp4')])
    def probe(path):
        return json.loads(run(['ffprobe','-v','error','-show_entries',
            'stream=codec_type,codec_name,width,height,duration:format=format_name,duration:format_tags=major_brand',
            '-of','json',str(path)],10))
    hevc_probe=probe(OUT/'hevc.mp4')
    # Native MP4 data is used; only the stated negative field is synthetic below.
    for case,data,code in [
        ('other-container-mp4-extension',probe(OUT/'wrong-container.mp4'),'MP4_CONTAINER_REQUIRED'),
        ('audio-missing',probe(OUT/'silent.mp4'),'HEVC_AUDIO_REQUIRED')]:
        try:validate_contract(data,2,expected_vcodec='h265',expected_acodec='aac')
        except RuntimeError as error:assert error.args==(code,)
        else:raise AssertionError(case)
        results.append({'case':case,'error':code,'realFile':True})
    for case,field,value,code in [('audio-codec','codec_name','mp3','AUDIO_CODEC_MISMATCH'),
                                   ('audio-truncated','duration','0.2','FILE_METADATA_DURATION_MISMATCH')]:
        data=copy.deepcopy(hevc_probe);next(s for s in data['streams'] if s['codec_type']=='audio')[field]=value
        try:validate_contract(data,2,expected_vcodec='h265',expected_acodec='aac')
        except RuntimeError as error:assert error.args==(code,)
        else:raise AssertionError(case)
        assert adapter.error_code(RuntimeError(code))=='FORMAT_UNAVAILABLE'
        results.append({'case':case,'error':code,'probeFieldFixture':True})
    def call(phase,folder,mode='normal',selected='-'):
        p=subprocess.run([sys.executable,__file__,'--worker',phase,str(folder),mode,selected],
            capture_output=True,text=True,timeout=35 if phase=='analyze' else 185)
        assert 'FAKE_' not in p.stdout+p.stderr and '__UNIVERSAL' not in p.stdout+p.stderr
        packet=json.loads(p.stdout.strip().splitlines()[-1])
        receipt=json.loads((OUT/(folder.name+'-'+phase+'.json')).read_text())
        return p.returncode,packet,receipt
    for kind in ('h264','hevc'):
        folder=ROOT/str(uuid.uuid4());folder.mkdir()
        rc,info,a=call('analyze',folder);assert rc==0 and not (folder/'media.mp4').exists()
        assert set(info)=={'title','duration','formats'}
        assert info['formats'][0]['id'].startswith('tt1_h264_') and info['formats'][0]['height']==576
        assert any(f['height']==360 and 'HEVC' in f['label'] for f in info['formats'])
        selected=next(f for f in info['formats'] if f['height']==(576 if kind=='h264' else 720))
        rc,prepared,b=call('prepare',folder,selected=selected['id']);assert rc==0,(kind,prepared)
        assert set(prepared)=={'file','size','inputBytes'} and a['pid']!=b['pid']
        assert a['metadataGET']==b['metadataGET']==1 and a['mediaGET']==0 and b['mediaGET']==1
        file=folder/'media.mp4';sha=hashlib.sha256(file.read_bytes()).hexdigest()
        assert sha==hashlib.sha256((OUT/(kind+'.mp4')).read_bytes()).hexdigest()
        ops=[json.loads(x) for x in (folder/'tiktok-operations.jsonl').read_text().splitlines()]
        assert any(x['operation']=='DECODE' and x['event']=='END' and x['returncode']==0 for x in ops)
        assert any(x['operation']=='HASH' and x['event']=='END' for x in ops)
        results.append({'case':kind+'-two-fresh-children','actualExits':[0,0],'metadataGET':[1,1],
                        'mediaGET':1,'sha256':sha,'byteIdenticalNoConversion':True,'fullDecodeExit':0,
                        'firstDefaultH264Unchanged':True,'schemaUnchanged':True})
    for mode in ('marked-video-only','changed-codec','changed-duration','actual-wrong-codec','actual-silent','actual-wrong-dimensions'):
        folder=ROOT/str(uuid.uuid4());folder.mkdir()
        rc,info,a=call('analyze',folder);assert rc==0
        selected=next(f['id'] for f in info['formats'] if f['height']==720)
        rc,packet,b=call('prepare',folder,mode,selected)
        assert rc==1 and packet=={'error':'FORMAT_UNAVAILABLE'},(mode,rc,packet)
        expected_get=0 if mode in ('marked-video-only','changed-codec','changed-duration') else 1
        assert b['mediaGET']==expected_get
        assert not any((folder/name).exists() for name in ('media.mp4','media.mp4.part','media.mp4.ytdl'))
        results.append({'case':mode,'actualExit':rc,'error':packet['error'],'mediaGET':b['mediaGET'],'ownedOutputRemoved':True})
    (OUT/'result.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,'versions':v,'ffmpeg':ffmpeg,
        'scope':'Session-double transport, real pinned yt-dlp/Cobalt parser/downloader/FFprobe/full decode; no API/phaseproof/browser/source',
        'native':native,'results':results},indent=2))
    print('PASS source-quality offline; synthetic media only; cases='+str(len(results)))

if __name__=='__main__':
    if '--worker' in sys.argv:raise SystemExit(worker())
    tests()
