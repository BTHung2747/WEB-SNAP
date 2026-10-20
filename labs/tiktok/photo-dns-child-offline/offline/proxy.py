"""Test entry only: explicit OS-DNS/TCP/CA fixture, no source entry imports this module."""
import sys,os,socket,json,pathlib,http.server,threading,ssl,time,base64,hashlib
sys.path[:0]=['/lab','/repo/apps/egress/src','/repo/apps/egress/vendor']
import egress
from tiktok_policy import runtime
from proxy_collect import install
OUT=pathlib.Path('/control');counts=dict(metadata=0,JPEG=0);lock=threading.RLock()
def mode():
    try:return json.loads((OUT/'mode.json').read_text())['mode']
    except FileNotFoundError:return 'startup'
def body():
    dims=32 if mode()=='changed-structure' else 64
    images=[dict(imageWidth=dims,imageHeight=64,imageURL={'urlList':[f'https://media.tiktokcdn.com/FAKE_PATH_TOKEN/{i}.jpeg?token=FAKE_QUERY_TOKEN']}) for i in range(5)]
    item=dict(id='7000000000000000001',desc='Offline only',author=dict(uniqueId='fixture'),privateItem=False,video=dict(duration=2,width=64,height=64,playAddr='https://media.tiktokcdn.com/unused'),imagePost=dict(images=images),music=dict(playUrl='https://media.tiktokcdn.com/unused'))
    value={'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}}
    return ('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps(value)+'</script>').encode()
def challenge():
    seed=b'executor-fixture';value=base64.b64encode(json.dumps({'v':{'a':base64.b64encode(seed).decode(),'c':base64.b64encode(hashlib.sha256(seed+b'0').digest()).decode()}}).encode()).decode()
    return ('<html>Please wait...<div id="cs" class="'+value+'"></div><div id="wci" class="fixture_cookie"></div></html>').encode()
class Origin(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def do_GET(self):
        assert not self.headers.get('Proxy-Authorization') and not self.headers.get('Authorization')
        image=self.headers.get('host')=='media.tiktokcdn.com'
        data=(OUT/'input.jpg').read_bytes() if image else body() if 'fixture_cookie=' in self.headers.get('cookie','') else challenge()
        with lock:
            counts['JPEG' if image else 'metadata']+=1
            temp=OUT/'counts.tmp';temp.write_text(json.dumps(counts));os.replace(temp,OUT/'counts.json')
        self.send_response(200);self.send_header('Content-Type','image/jpeg' if image else 'text/html');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
    def log_message(self,*a):pass
original=socket.getaddrinfo
def dns(host,port,*a,**kw):
    if host in ('www.tiktok.com','media.tiktokcdn.com'):return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
    return original(host,port,*a,**kw)
socket.getaddrinfo=dns
origin=http.server.ThreadingHTTPServer(('127.0.0.1',0),Origin)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(OUT/'fixture-cert.pem',OUT/'fixture-key.pem');origin.socket=ctx.wrap_socket(origin.socket,server_side=True)
ot=threading.Thread(target=origin.serve_forever,kwargs={'poll_interval':.02});ot.start()
class Loop(runtime.ObservedLoop):
    async def sock_connect(self,sock,address):return await super().sock_connect(sock,('127.0.0.1',origin.server_address[1]))
runtime.ObservedLoop=Loop
server=egress.Server(('0.0.0.0',8888),egress.Handler);install(server,OUT)
real=server.phase_broker.finish
def finish(ctx,result):
    if mode()!='missing-proof':return real(ctx,result)
server.phase_broker.finish=finish
thread=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.02});thread.start();(OUT/'ready').write_text('ready');end=time.monotonic()+320
try:
    while not (OUT/'stop').exists() and time.monotonic()<end:time.sleep(.05)
finally:
    server.shutdown();server.server_close();thread.join(2);origin.shutdown();origin.server_close();ot.join(2)
    (OUT/'proxy-result.json').write_text(json.dumps(dict(mode='offline',counts=counts,listenerClosed=server.socket.fileno()==-1,serveThreadClosed=not thread.is_alive(),originClosed=not ot.is_alive(),connections=list(server.completed))))
