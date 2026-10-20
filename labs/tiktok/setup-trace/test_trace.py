"""Network-none offline tests. Explicit dependency fixtures, never a production resolver/socket patch."""
import hashlib,http.server,importlib.util,inspect,io,json,pathlib,socket,ssl,subprocess,sys,threading,time,types
import egress_trace as traced
from trace import TraceSink,CURRENT
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import versions
from tiktok.connection_boundaries import BoundaryObserver,ObservedAdapter,ConnectionObserverMixin
from tiktok.send_diagnostics import classify
import requests,urllib3
OUT=pathlib.Path('/out');results=[]
def safe_failure(kind,value,tb):print('OFFLINE_TRACE_TEST_FAILURE')
sys.excepthook=safe_failure
spec=importlib.util.spec_from_file_location('stock_egress','/stock/egress.py')
stock=importlib.util.module_from_spec(spec);spec.loader.exec_module(stock)
REAL_SOCKET=socket;REAL_SELECT=traced.select
PUBLIC4=(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))
PUBLIC6=(socket.AF_INET6,socket.SOCK_STREAM,6,'',('2606:4700:4700::1111',443,0,0))

class Client:
    def __init__(self,fail=False):self.sent=[];self.timeouts=[];self.fail=fail
    def settimeout(self,t):self.timeouts.append(t)
    def sendall(self,data):
        if self.fail and data.startswith(b'HTTP/1.1 200'):raise BrokenPipeError('SECRET_CONNECT')
        self.sent.append(data)
    def recv(self,n):return b''
class FakeUpstream:
    def __init__(self,api):self.api=api;self.t=None;self.closed=False
    def settimeout(self,t):self.t=t;self.api.timeouts.append(t)
    def gettimeout(self):return self.t
    def connect(self,addr):
        self.api.attempts.append(addr)
        if self.api.delays:time.sleep(self.api.delays)
        index=len(self.api.attempts)-1
        if index<len(self.api.errors) and self.api.errors[index] is not None:raise self.api.errors[index]
    def close(self):self.closed=True
    def recv(self,n):return b''
class FakeAPI:
    AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM
    def __init__(self,addresses=None,dns_error=None,errors=(),delay=0,connect_delay=0):
        self.addresses=addresses if addresses is not None else [PUBLIC6,PUBLIC4]
        self.dns_error=dns_error;self.errors=errors;self.delay=delay;self.delays=connect_delay
        self.attempts=[];self.timeouts=[];self.dns_calls=0
    def getaddrinfo(self,*a,**k):
        self.dns_calls+=1
        if self.delay:time.sleep(self.delay)
        if self.dns_error is not None:raise self.dns_error
        return self.addresses
    def socket(self,*a,**k):return FakeUpstream(self)
def direct_case(name,api,fail_send=False,request=None):
    responses=[];calls=[];trace_path=OUT/(name+'.jsonl')
    for module in (stock,traced):
        # Fixture-only public dependency injection. No installed-library/private-method monkeypatch.
        module.socket=api.__class__(addresses=api.addresses,dns_error=api.dns_error,errors=api.errors,delay=api.delay,connect_delay=api.delays)
        module.select=types.SimpleNamespace(select=lambda sources,*a:([sources[0]],[],[]))
        if module is traced:module.TRACE=TraceSink(trace_path)
        handler=object.__new__(module.Handler);client=Client(fail_send);handler.connection=client
        handler.rfile=io.BytesIO(request or b'CONNECT fixture.tiktok.com:443 HTTP/1.1\r\nCookie: SECRET_COOKIE\r\n\r\n')
        handler.handle()
        responses.append(client.sent);calls.append((module.socket.attempts,module.socket.timeouts,module.socket.dns_calls,client.timeouts))
    assert responses[0]==responses[1] and calls[0]==calls[1],name
    rows=[json.loads(x) for x in trace_path.read_text().splitlines()]
    assert len({r['connectionID'] for r in rows})==1
    assert all(r['event'] in ('BEGIN','END','ERROR') for r in rows)
    if name in ('dns-failure','public-ip-denied','empty-dns'):
        assert not any(r['boundary']=='UPSTREAM_TCP_CONNECT' for r in rows)
        assert responses[0][0].startswith(b'HTTP/1.1 403')
    if name=='fallback':
        terminals=[r for r in rows if r['boundary']=='UPSTREAM_TCP_CONNECT' and r['event']!='BEGIN']
        assert [(r['attemptIndex'],r['family'],r['event']) for r in terminals]==[(1,'IPv6','ERROR'),(2,'IPv4','END')]
        assert all(r['timeoutSeconds']==10 and r['deadlineMonotonicSeconds']>0 for r in terminals)
    if name=='dns-delay':
        assert any(r['boundary']=='DNS_LOOKUP' and r['event']=='END' and r['elapsed']>=.02 for r in rows)
    if name=='tcp-delay':
        assert any(r['boundary']=='UPSTREAM_TCP_CONNECT' and r['event']=='END' and r['elapsed']>=.02 for r in rows)
    if name=='connect-send-failure':
        assert any(r['boundary']=='CONNECT_200_SENT' and r['event']=='ERROR' for r in rows)
        assert not any(r['boundary']=='CONNECT_200_SENT' and r['event']=='END' for r in rows)
    dns=[r for r in rows if r['boundary']=='DNS_LOOKUP' and r['event']=='END']
    if dns:assert dns[0]['ipv4Count']==sum(a[0]==socket.AF_INET for a in api.addresses)
    after200=any(r['boundary']=='CONNECT_200_SENT' and r['event']=='END' for r in rows)
    results.append({'case':name,'fixture':True,'stockOutcomeEqual':True,'addressOrderUnchanged':True,
        'actualTimeouts':calls[0][1],'proxy200Observed':after200,'traceRows':len(rows)})
for name,api,fail in [
 ('success-close',FakeAPI(),False),('dns-delay',FakeAPI(delay=.03),False),
 ('dns-failure',FakeAPI(dns_error=socket.gaierror(-2,'SECRET_DNS')),False),
 ('public-ip-denied',FakeAPI(addresses=[PUBLIC4,(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))]),False),
 ('empty-dns',FakeAPI(addresses=[]),False),
 ('tcp-delay',FakeAPI(connect_delay=.03),False),
 ('tcp-failure',FakeAPI(errors=[ConnectionRefusedError('SECRET'),TimeoutError('SECRET')]),False),
 ('fallback',FakeAPI(errors=[TimeoutError('SECRET'),None]),False),
 ('connect-send-failure',FakeAPI(),True)]:
 direct_case(name,api,fail)
traced.socket=socket;traced.select=REAL_SELECT;stock.socket=socket;stock.select=REAL_SELECT

# Exact delegated exception identity and diagnostic I/O/cap failure must not alter outcome.
for name,error in [('dns',socket.gaierror(-2,'SECRET')),('tcp',TimeoutError('SECRET'))]:
 sink=TraceSink(OUT/(name+'-identity.jsonl'));con=sink.connection()
 def raises():raise error
 try:con.call('DNS_LOOKUP' if name=='dns' else 'UPSTREAM_TCP_CONNECT',raises)
 except Exception as got:assert got is error
 else:raise AssertionError('identity')
 results.append({'case':name+'-identity','sameException':True})
sink=TraceSink(OUT/'cap.jsonl',total_cap=6,connection_cap=4);con=sink.connection()
for i in range(100):assert con.call('DNS_LOOKUP',lambda:1)==1
assert sink.count==4 and sink.incomplete
other=sink.connection();other.call('DNS_LOOKUP',lambda:1);assert sink.count==6
results.append({'case':'trace-caps','totalCap':6,'perConnectionCap':4,'incomplete':sink.incomplete})
broken=TraceSink(OUT/'nonexistent'/'trace.jsonl');con=broken.connection();error=TimeoutError('SECRET')
try:con.call('UPSTREAM_TCP_CONNECT',lambda:(_ for _ in ()).throw(error))
except TimeoutError as got:assert got is error and broken.incomplete
else:raise AssertionError('io identity')
results.append({'case':'trace-IO-failure-preserves-error','sameException':True})

# Real Requests/urllib3 HTTPS through this proxy in network-none.
# Validated public DNS stand-ins map only in the explicit fixture facade to a loopback TLS endpoint.
cert='/tmp/fixture-cert.pem';key='/tmp/fixture-key.pem'
p=subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1',
 '-subj','/CN=fixture.tiktok.com','-addext','subjectAltName=DNS:fixture.tiktok.com',
 '-keyout',key,'-out',cert],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
assert p.returncode==0
class HTTPS(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def do_GET(self):
        self.send_response(200);self.send_header('Content-Length','7');self.end_headers();self.wfile.write(b'FIXTURE')
    def log_message(self,*a):pass
class QuietHTTP(http.server.ThreadingHTTPServer):
    daemon_threads=True
    def handle_error(self,*a):pass
origin=QuietHTTP(('127.0.0.1',0),HTTPS)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(cert,key)
origin.socket=ctx.wrap_socket(origin.socket,server_side=True)
threading.Thread(target=origin.serve_forever,daemon=True).start()
class StallServer(stock.socketserver.ThreadingTCPServer):
    allow_reuse_address=True;daemon_threads=True
    def handle_error(self,*a):pass
class Stall(stock.socketserver.BaseRequestHandler):
    def handle(self):time.sleep(12) # Accept TCP but deliberately never respond to TLS.
stall=StallServer(('127.0.0.1',0),Stall);threading.Thread(target=stall.serve_forever,daemon=True).start()
class RoutedSocket:
    def __init__(self,inner,port):self.inner=inner;self.port=port
    def connect(self,addr):return self.inner.connect(('127.0.0.1',self.port))
    def __getattr__(self,name):return getattr(self.inner,name)
class RoutedAPI:
    AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM
    def __init__(self,port):self.port=port
    def getaddrinfo(self,*a,**k):return [PUBLIC4]
    def socket(self,*a,**k):return RoutedSocket(socket.socket(*a,**k),self.port)
class Proxy(stock.Server):
    def handle_error(self,*a):pass
def loopback(module,name,port,verify,repeat=1):
    module.socket=RoutedAPI(port)
    sink=TraceSink(OUT/(name+'-proxy.jsonl'))
    if module is traced:module.TRACE=sink
    proxy=Proxy(('127.0.0.1',0),module.Handler);threading.Thread(target=proxy.serve_forever,daemon=True).start()
    session=requests.Session();session.trust_env=False;session.mount('https://',ObservedAdapter(max_retries=0))
    observer=BoundaryObserver(name+'-client.jsonl',root=OUT);rows=[];outcomes=[]
    try:
        for _ in range(repeat):
            row={};url='https://fixture.tiktok.com/SECRET_PATH?token=SECRET_QUERY'
            req=session.prepare_request(requests.Request('GET',url,headers={'Cookie':'SECRET_COOKIE'}))
            start=time.monotonic()
            with observer.request(row,'prepare'):
                try:
                    response=session.get_adapter(url).send(req,stream=True,timeout=urllib3.util.Timeout(total=30,connect=10,read=20),
                       verify=verify,proxies={'https':'http://127.0.0.1:'+str(proxy.server_address[1])})
                    data=response.raw.read();status=response.status_code;response.close()
                    assert data==b'FIXTURE';outcome={'status':status,'error':None}
                except Exception as error:outcome={'status':'UNKNOWN','error':classify(error)[0]}
            outcomes.append(outcome);rows.append(row)
    finally:
        session.close();proxy.shutdown();proxy.server_close();module.socket=socket
    proxyrows=[json.loads(x) for x in sink.path.read_text().splitlines()] if module is traced else []
    if module is traced:
        assert any(r['boundary']=='CONNECT_200_SENT' and r['event']=='END' for r in proxyrows)
        if repeat==2:
            assert len({r['connectionID'] for r in proxyrows})==1 and rows[1]['boundaries']['reused']
            assert rows[0]['boundaries']['connectionID']==rows[1]['boundaries']['connectionID']
        assert all('SECRET' not in json.dumps(r) for r in rows+proxyrows)
    results.append({'case':name,'loopbackOnly':True,'proxy200Observed':bool(proxyrows),'rows':rows,'outcomes':outcomes,
         'clientProxyCorrelation':'FIXTURE_SINGLE_TUNNEL_ONLY; production UNKNOWN','TLSDetail':'UNKNOWN'})
    return outcomes
try:
 for label,port,verify,repeat in [('success-reuse',origin.server_address[1],cert,2),
                                 ('certificate-failure',origin.server_address[1],True,1),
                                 ('tls-stall',stall.server_address[1],cert,1)]:
    a=loopback(stock,label+'-stock',port,verify,repeat)
    b=loopback(traced,label+'-traced',port,verify,repeat)
    assert a==b,(label,a,b)
    if label=='certificate-failure':assert a[0]['error']=='TLS_ERROR'
    if label=='tls-stall':assert a[0]['error'] in ('READ_TIMEOUT','CONNECT_TIMEOUT','TIMEOUT_UNKNOWN')
finally:origin.shutdown();origin.server_close();stall.shutdown();stall.server_close()

# Existing observer keeps the exact exception and reuses only successful connections.
sentinel=TimeoutError('SECRET')
class Base:
    timeout=10;is_closed=True
    def __init__(self):pass
    def connect(self):raise sentinel
class Identity(ConnectionObserverMixin,Base):pass
observer=BoundaryObserver('client-identity.jsonl',root=OUT)
with observer.request({},'prepare'):
    try:Identity().connect()
    except TimeoutError as got:assert got is sentinel
    else:raise AssertionError('client identity')
results.append({'case':'client-exception-identity','sameException':True})
for path in OUT.glob('*.jsonl'):
 text=path.read_text()
 assert not any(s in text for s in ('SECRET','fixture.tiktok.com','1.1.1.1','127.0.0.1','2606:4700','https://','Cookie:'))
 for line in text.splitlines():
    row=json.loads(line)
    if 'boundary' in row and row['boundary']=='DNS_LOOKUP' and row['event']=='ERROR':
        assert 'ipv4Count' not in row and 'ipv6Count' not in row # no counts before public-IP guard PASS
api={'python':sys.version.split()[0],'requests':requests.__version__,'urllib3':urllib3.__version__,'pins':versions(),
     'socketSourceSHA':hashlib.sha256(pathlib.Path(inspect.getfile(socket)).read_bytes()).hexdigest(),
     'socketserverSourceSHA':hashlib.sha256(pathlib.Path(inspect.getfile(stock.socketserver)).read_bytes()).hexdigest(),
     'HTTPSConnectionSourceSHA':hashlib.sha256(pathlib.Path(inspect.getfile(urllib3.connection.HTTPSConnection)).read_bytes()).hexdigest(),
     'publicAPIs':['socket.getaddrinfo','socket.settimeout/gettimeout/connect/sendall','socketserver.StreamRequestHandler.handle',
                   'SSLContext.wrap_socket','HTTPAdapter.send','HTTPSConnection.connect','HTTPConnectionPool.ConnectionCls'],
     'opensslActualExit':p.returncode}
assert api['python']=='3.11.2' and api['requests']=='2.34.2' and api['urllib3']=='2.8.0'
OUT.joinpath('api-runtime.json').write_text(json.dumps(api,indent=2))
core=pathlib.Path('/app/apps/media/src/tiktok')
OUT.joinpath('runtime-core.json').write_text(json.dumps([
 {'path':str(f.relative_to(core)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
 for f in core.rglob('*') if f.is_file() and 'node_modules' not in f.parts and '__pycache__' not in f.parts],indent=2))
OUT.joinpath('test-result.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,'stockOutcomesPreserved':True,
  'exceptionIdentityPreserved':True,'timeoutsUnchanged':{'proxyPerAddress':10,'clientConnect':10,'clientRead':20,'total':30,
  'proxyTunnelMax':240,'proxyTunnelIdle':30},'TLSFineStages':'UNKNOWN','productionCorrelation':'UNKNOWN',
  'environment':'network-none; deterministic public-address stand-ins + loopback-only routing fixture; production guards not relaxed',
  'results':results},indent=2))
print('PASS bounded proxy DNS/TCP/CONNECT trace; stock responses/order/timeouts/TLS outcomes; network-none source0')
