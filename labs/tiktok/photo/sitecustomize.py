# LAB ONLY, mounted by its runner; no fixture code is part of apps/media runtime.
import os,sys
if os.environ.get('TIKTOK_APP_FIXTURE')=='1' and sys.argv[0].endswith('worker.py'):
    import atexit,base64,hashlib,io,json,pathlib,signal,subprocess,time,types,urllib.parse
    import requests,urllib3
    phase=sys.argv[1];url=sys.argv[2].replace('/photo/','/video/');folder=pathlib.Path(sys.argv[3]);job=folder.name
    control=pathlib.Path(os.environ.get('FIXTURE_CONTROL','/control'))/job;control.mkdir(parents=True,exist_ok=True)
    def event(name,**detail):
        with (control/'events.jsonl').open('a') as f:f.write(json.dumps({'event':name,'phase':phase,'pid':os.getpid(),'pgid':os.getpgrp(),**detail})+'\n')
    event('child_begin');atexit.register(lambda:event('child_exit'))
    try:mode=json.loads((control/'mode.json').read_text()).get('mode','normal')
    except FileNotFoundError:mode='normal'
    if 'youtube.com' in url:
        # Fixture only; validates untouched legacy branch/JSON/native probe, not real YouTube extraction.
        import yt_dlp,shutil
        def fake_extract(self,*args,**kwargs):
            return {'id':'fixture','title':'YouTube fixture','duration':2,
                    'formats':[{'format_id':'18','ext':'mp4','protocol':'https','vcodec':'h264','acodec':'aac','height':64,'filesize':None}]}
        def fake_process(self,info,download=True):
            shutil.copyfile(os.environ['FIXTURE_MEDIA_FILE'],folder/'media.mp4');return info
        yt_dlp.YoutubeDL.extract_info=fake_extract;yt_dlp.YoutubeDL.process_ie_result=fake_process
    else:
        ID=urllib.parse.urlsplit(url).path.rsplit('/',1)[-1]
        PLAY='https://media.tiktokcdn.com/FAKEPATH_'+str(os.getpid())+'.jpeg?token=FAKESIGNED_'+str(os.getpid())
        class Reply:
            def __init__(self,body,mime='text/html',status=200):
                self.status_code=status;self.headers={'content-type':mime,'content-length':str(len(body))}
                if status==302:self.headers['location']='https://media.tiktokcdn.com/FAKEREDIRECT'
                self.raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers=self.headers,preload_content=False,decode_content=False)
            def close(self):self.raw.close()
        Base=requests.Session
        class FakeSession(Base):
            def __init__(self):super().__init__();self.pages=0;self.media=0
            def get_adapter(self,request_url):return types.SimpleNamespace(send=self.send_fixture)
            def send_fixture(self,prepared,**opts):
                assert prepared.method=='GET' and opts['stream'] is True and opts['verify'] is True
                assert opts['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'} and not self.trust_env
                if prepared.url==url:
                    self.pages+=1;assert self.pages<=2
                    event('metadata_GET',index=self.pages)
                    if mode=='redirect':return Reply(b'X',status=302)
                    if mode=='metadata-oversize':return Reply(b'X'*(8*1024*1024+32))
                    if self.pages==1:
                        seed=b'app-integration';h=hashlib.sha256(seed);h.update(b'0')
                        data=base64.b64encode(json.dumps({'v':{'a':base64.b64encode(seed).decode(),'c':base64.b64encode(h.digest()).decode()}}).encode()).decode()
                        return Reply(('<html>Please wait...<div id="cs" class="'+data+'"></div><div id="wci" class="fixture_cookie"></div></html>').encode())
                    assert 'fixture_cookie=' in prepared.headers.get('Cookie','')
                    duration=3 if phase=='prepare' and mode=='format-change' else 2
                    item={'id':ID if mode!='wrong-body' else str(int(ID)+1),'desc':'Fixture video',
                          'author':{'uniqueId':'fixture'},'privateItem':mode=='private',
                          'video':{'duration':duration,'width':64,'height':64,'playAddr':PLAY,
                                   'downloadAddr':'https://media.tiktokcdn.com/FAKEDOWNLOAD'}}
                    item['imagePost']={'images':[{'imageWidth':64,'imageHeight':64,'imageURL':{'urlList':[PLAY]}},{'imageWidth':64,'imageHeight':64,'imageURL':{'urlList':[PLAY.replace('FAKEPATH','SECOND')]}}]}
                    if mode=='watermark-only':item['video'].pop('playAddr')
                    if mode=='photo':item['imagePost']={'images':[]}
                    if mode=='age':item['isContentClassified']=True
                    html='<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps({'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}})+'</script>'
                    return Reply(html.encode())
                if prepared.url==PLAY:
                    self.media+=1;assert self.media==1 and self.pages==2
                    assert 'fixture_cookie=' not in prepared.headers.get('Cookie','')
                    event('MP4_GET',index=1)
                    if mode=='hang':
                        (folder/'media.mp4.part').write_bytes(b'OWNED_FIXTURE_PART')
                        signal.signal(signal.SIGTERM,signal.SIG_IGN)
                        helper=subprocess.Popen(['python3','-c','import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(180)'])
                        event('helper_started',helperPid=helper.pid)
                        time.sleep(180)
                    media=os.environ['FIXTURE_WRONG_MEDIA_FILE'] if mode=='wrong-media-dimensions' else os.environ['FIXTURE_MEDIA_FILE']
                    if mode=='image-html':return Reply(b'<html>not image</html>','image/jpeg')
                    if mode=='image-oversize':return Reply(b'X'*(16*1024*1024+1),'image/jpeg')
                    return Reply(pathlib.Path(media).read_bytes(),'image/jpeg')
                raise AssertionError('Unexpected fixture request')
        requests.Session=FakeSession

if os.environ.get('TIKTOK_APP_FIXTURE')=='1' and sys.argv[0].endswith('worker.py'):
    old_init=Reply.__init__
    def injected(self,body,mime='text/html',status=200):
        old_init(self,body,mime,status)
        if mode in ('metadata-timeout','image-timeout') and ((mode=='metadata-timeout' and mime=='text/html') or (mode=='image-timeout' and mime=='image/jpeg')):
            def read(*a,**k):raise urllib3.exceptions.ReadTimeoutError(None,None,'FIXTURE_SECRET')
            self.raw.read=read
        if mode=='body-oversize' and mime=='image/jpeg':
            self.headers.pop('content-length',None)
            self.raw=urllib3.HTTPResponse(body=io.BytesIO(b'X'*(16*1024*1024+1)),preload_content=False)
    Reply.__init__=injected
