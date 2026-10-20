"""Explicit offline fixtures only; pinned FakeSession challenge and Reply are reused."""
import hashlib,json,pathlib,re,subprocess,types,urllib.parse,time
def wrap(owner,base,control):
    # Synthetic JPEGs with distinct dimensions/content, no downloaded source.
    count=control.get('imageCount',2);media={}
    for i in range(1,min(count,5)+1):
        w=64+16*(i-1);h=64
        path=pathlib.Path(f'/tmp/fixture-{i}.jpg')
        if not path.exists():
            begin=time.monotonic()
            p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i',f'testsrc=size={w}x{h}','-frames:v','1','-threads','1','-c:v','mjpeg',str(path)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
            with (owner.out/'fixture-native.jsonl').open('a') as f:f.write(json.dumps(dict(index=i,operation='SYNTHETIC_JPEG',elapsed=time.monotonic()-begin,timeout=10,returncode=p.returncode))+'\n')
            assert p.returncode==0
        media[i]=path
    old=base.send_fixture
    def send(prepared,**opts):
        url=urllib.parse.urlsplit(prepared.url)
        if url.hostname=='www.tiktok.com':
            reply=old(prepared,**opts)
            if base.pages!=2 or reply.status_code!=200:return reply
            body=reply.raw.read(decode_content=True);reply.close()
            match=re.search(rb'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">(.*?)</script>',body)
            value=json.loads(match.group(1));item=value['__DEFAULT_SCOPE__']['webapp.video-detail']['itemInfo']['itemStruct']
            item['imagePost']['images']=[dict(imageWidth=64+16*(i-1),imageHeight=64,imageURL=dict(urlList=[f'https://media.tiktokcdn.com/FAKEPATH_{i}.jpeg?token=FAKESIGNED'])) for i in range(1,count+1)]
            mode=control['mode']
            if mode=='tail-missing':item['imagePost']['images'][-1]['imageURL']['urlList']=[]
            if mode=='bad-dimension':item['imagePost']['images'][-1]['imageWidth']=True
            if mode=='same-bytes':
                for row in item['imagePost']['images']:row['imageWidth']=64
            html=b'<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps(value).encode()+b'</script>'
            return type(reply)(html)
        assert url.hostname=='media.tiktokcdn.com' and opts['stream'] is True and opts['verify'] is True
        assert opts['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
        assert 'fixture_cookie=' not in prepared.headers.get('Cookie','')
        index=int(re.fullmatch('/FAKEPATH_(\d+)\.jpeg',url.path).group(1))
        mode=control['mode']
        # Reply class is reached from the already captured metadata response, not a new request.
        Reply=base._album_reply
        if mode=='fail-second' and index==2:return Reply(b'FIXTURE_ERROR','image/jpeg',503)
        if mode=='redirect-image':return Reply(b'X','image/jpeg',302)
        if mode=='image-html':return Reply(b'<html>invalid</html>','image/jpeg')
        data=media[1 if mode=='same-bytes' else index].read_bytes()
        return Reply(data,'image/jpeg')
    def wrapped(prepared,**opts):
        if urllib.parse.urlsplit(prepared.url).hostname=='www.tiktok.com':
            # Save the existing Reply class before adapting the fixture data.
            reply=send(prepared,**opts);base._album_reply=type(reply);return reply
        return send(prepared,**opts)
    base.send_fixture=wrapped
    return base
