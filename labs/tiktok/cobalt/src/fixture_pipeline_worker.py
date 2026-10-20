# Offline-only adapter. Real extractor/native challenge/downloader/worker, fake HTTP responses.
import base64,hashlib,io,json,pathlib,sys,types
import requests,urllib3
from yt_candidate import worker
ID='7692288554839313682';URL='https://www.tiktok.com/@fixture/video/'+ID
LONG=sys.argv[1:]==['--long-fixture'];DURATION=486 if LONG else 2
PLAY='https://media.tiktokcdn.com/FAKEPATH?token=FAKEQUERY'
class Reply:
    def __init__(self,body,mime):
        self.status_code=200;self.headers={'content-type':mime,'content-length':str(len(body))}
        self.raw=urllib3.HTTPResponse(body=io.BytesIO(body),headers=self.headers,preload_content=False,decode_content=False)
    def close(self):self.raw.close()
class FakeSession(requests.Session):
    def __init__(self):super().__init__();self.pages=0;self.media=0
    def get_adapter(self,url):return types.SimpleNamespace(send=self.send_fixture)
    def send_fixture(self,prepared,**opts):
        assert not self.trust_env and opts['verify'] is True and opts['stream'] is True
        assert opts['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
        assert prepared.method=='GET'
        if prepared.url==URL:
            self.pages+=1;assert self.pages<=2
            if self.pages==1:
                seed=b'fixture-pipeline';h=hashlib.sha256(seed);h.update(b'0')
                payload=base64.b64encode(json.dumps({'v':{'a':base64.b64encode(seed).decode(),'c':base64.b64encode(h.digest()).decode()}}).encode()).decode()
                html='<html>Please wait...<div id="cs" class="'+payload+'"></div><div id="wci" class="fixture_challenge"></div></html>'
            else:
                assert 'fixture_challenge=' in prepared.headers.get('Cookie','')
                info={'id':ID,'desc':'synthetic pipeline','author':{'uniqueId':'fixture'},
                      'video':{'duration':DURATION,'width':1024 if LONG else 64,'height':576 if LONG else 64,'playAddr':PLAY,
                               'downloadAddr':'https://media.tiktokcdn.com/FAKEDOWNLOAD'}}
                html='<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps({'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':info}}}})+'</script>'
            return Reply(html.encode(),'text/html')
        if prepared.url==PLAY:
            self.media+=1;assert self.media==1 and self.pages==2
            assert 'fixture_challenge' not in prepared.headers.get('Cookie','')
            return Reply(pathlib.Path('/out/fixture-input.mp4').read_bytes(),'video/mp4')
        raise AssertionError('Unexpected fixture request')
if __name__=='__main__':sys.exit(worker(URL,ID,session_factory=FakeSession,fixture_debug=True))
