"""Actual production proxy and TLS server. Only DNS/TCP destinations are mapped."""
import base64,hashlib,http.server,json,os,pathlib,socket,ssl,threading,time
from tiktok_policy import runtime
import egress
OUT=pathlib.Path('/control');counts={'metadata':0,'videoMetadata':0,'JPEG':0};lock=threading.RLock()
def mode():
    try:return json.loads((OUT/'mode.json').read_text())['mode']
    except FileNotFoundError:return 'happy'
def challenge():
    seed=b'photo-core-fixture';value=base64.b64encode(json.dumps({'v':{'a':base64.b64encode(seed).decode(),'c':base64.b64encode(hashlib.sha256(seed+b'0').digest()).decode()}}).encode()).decode()
    return ('<html>Please wait...<div id="cs" class="'+value+'"></div><div id="wci" class="fixture_cookie"></div></html>').encode()
def body(video=False):
    images=[dict(imageWidth=64,imageHeight=64,imageURL={'urlList':[f'https://media.tiktokcdn.com/FAKE_PATH_TOKEN/image{i}.jpeg?token=FAKE_QUERY_TOKEN']}) for i in range(2)]
    item={'id':'7000000000000000001','desc':'Fixture only','author':{'uniqueId':'fixture'},'privateItem':False,'video':{'duration':2,'width':64,'height':64,'playAddr':'https://media.tiktokcdn.com/unused'},'imagePost':{'images':images},'music':{'playUrl':'https://media.tiktokcdn.com/unused'}}
    if video:item['id']='7000000000000000002';del item['imagePost']
    value={'__DEFAULT_SCOPE__':{'webapp.video-detail':{'statusCode':0,'itemInfo':{'itemStruct':item}}}}
    return ('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+json.dumps(value)+'</script>').encode()
class Origin(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def do_GET(self):
        assert not self.headers.get('Proxy-Authorization') and not self.headers.get('Authorization')
        image=self.headers.get('host')=='media.tiktokcdn.com'
        video=self.path.endswith('/7000000000000000002')
        data=(OUT/'input.jpg').read_bytes() if image else body(video) if 'fixture_cookie=' in self.headers.get('cookie','') else challenge()
        with lock:counts['JPEG' if image else 'videoMetadata' if video else 'metadata']+=1
        with lock:
            temp=OUT/'counts.tmp';temp.write_text(json.dumps(counts));os.replace(temp,OUT/'counts.json')
        self.send_response(200);self.send_header('Content-Type','image/jpeg' if image else 'text/html');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
    def log_message(self,*_):pass
origin=http.server.ThreadingHTTPServer(('127.0.0.1',0),Origin)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(OUT/'fixture-cert.pem',OUT/'fixture-key.pem');origin.socket=ctx.wrap_socket(origin.socket,server_side=True)
tls_thread=threading.Thread(target=origin.serve_forever,kwargs={'poll_interval':.01});tls_thread.start()
class Loop(runtime.ObservedLoop):
    async def sock_connect(self,sock,address):return await super().sock_connect(sock,('127.0.0.1',origin.server_address[1]))
runtime.ObservedLoop=Loop
proxy=egress.Server(('0.0.0.0',8888),egress.Handler);thread=threading.Thread(target=proxy.serve_forever,kwargs={'poll_interval':.01});thread.start()
baseRequest=runtime.Request
class FaultRequest(baseRequest):
    def connect(self,host):self.fixture_host=host;return super().connect(host)
    def finish(self):
        super().finish()
        current=mode()
        if current=='late-CDN' and getattr(self,'fixture_host','')=='media.tiktokcdn.com' or current=='late-analyze':self.trace.mark_incomplete()
        if current=='crash' and getattr(self,'fixture_host','')=='media.tiktokcdn.com':
            (OUT/'crash.json').write_text(json.dumps(dict(code='AFTER_CDN_BYTES',actualExit=33)));os._exit(33)
runtime.Request=FaultRequest
broker=proxy.phase_broker;realCommand=broker.command;realFinish=broker.finish
def command(p):
    answer=realCommand(p);current=mode()
    if p.get('op')=='open' and answer.get('state')=='OPEN':broker.entries[p['id']]['fixture_case']=current
    if p.get('op') in ('seal','poll','take'):
        if current=='unknown':answer['state']='UNKNOWN'
        if current=='cross-phase':answer['phase']='prepare' if p['phase']=='analyze' else 'analyze'
        if current=='cross-job':answer['job']='0'*64
        if current=='channel-error':answer['extra']='invalid'
    return answer
def finish(ctx,result):
    entry=broker.entries.get(getattr(ctx,'_phase_key',None),{})
    with (OUT/'completions.jsonl').open('a') as f:f.write(json.dumps(dict(case=entry.get('fixture_case','ungated'),phase=entry.get('phase','ungated'),ownerID=ctx.cid,accepted=result.get('accepted'),threadClosed=result.get('workerThreadClosed'),clientClosed=result.get('clientClosed'),traceIncomplete=result.get('traceIncomplete')))+'\n')
    if mode()!='missing':realFinish(ctx,result)
broker.command=command;broker.finish=finish
(OUT/'ready').write_text('ready')
end=time.monotonic()+220
try:
    while not (OUT/'stop').exists() and time.monotonic()<end:
        temp=OUT/'service.tmp';temp.write_text(json.dumps(dict(active=len(proxy.policy_contexts),pending=len(proxy.policy_pending))));os.replace(temp,OUT/'service.json');time.sleep(.02)
finally:
    proxy.shutdown();proxy.server_close();thread.join(2)
    origin.shutdown();origin.server_close();tls_thread.join(2)
    result=dict(status='FIXTURE_CLOSURE_OBSERVED',
      counts=counts,connections=list(proxy.completed),sourceCalls=0,listenerClosed=proxy.socket.fileno()==-1,serveThreadClosed=not thread.is_alive(),tlsThreadClosed=not tls_thread.is_alive())
    (OUT/'proxy-result.json').write_text(json.dumps(result,indent=2))
