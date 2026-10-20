# Real library HTTPS through loopback proxy; errors/delay/reuse/origin scopes, no source.
import json,pathlib,subprocess,time
import requests,urllib3
from connection_boundaries import BoundaryObserver,ObservedAdapter,ConnectionObserverMixin,configure
from send_diagnostics import observed_send,classify
CERT='/lab/src/fixtures/stages-cert.pem';results=[]
def safe_uncaught(kind,value,tb):print(json.dumps({'code':'BOUNDARY_OFFLINE_FAILURE'}))
import sys;sys.excepthook=safe_uncaught
server=subprocess.Popen(['node','/lab/src/boundary_loopback.mjs'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
ports=json.loads(server.stdout.readline());proxy='http://127.0.0.1:'+str(ports['proxy'])
def mode(value):server.stdin.write(value+'\n');server.stdin.flush();assert server.stdout.readline().strip()=='OK'
def session(observed):
    s=requests.Session();s.trust_env=False;s.mount('https://',ObservedAdapter(max_retries=0) if observed else requests.adapters.HTTPAdapter(max_retries=0));return s
def request(s,observer,port,verify=CERT):
    row={};url='https://localhost:'+str(port)+'/FAKEPATH?token=FAKEQUERY'
    prepared=s.prepare_request(requests.Request('GET',url,headers={'Cookie':'FAKECOOKIE'}))
    error=None;status=None;body=None
    with observer.request(row,'metadata'):
        try:
            response=observed_send(s.get_adapter(url),prepared,row,'metadata',stream=True,
                timeout=urllib3.util.Timeout(total=2,connect=.25,read=.3),verify=verify,
                proxies={'http':proxy,'https':proxy})
            status=response.status_code;body=response.raw.read();response.close()
        except Exception as caught:error=classify(caught)[0]
    assert 'FAKE' not in json.dumps(row)
    return row,status,body,error
try:
    mode('success');s=session(True);observer=BoundaryObserver('loopback-reuse.jsonl')
    rows=[]
    for port in (ports['a'],ports['a'],ports['b']):
        row,status,body,error=request(s,observer,port);assert status==200 and body==b'FIXTURE' and error is None;rows.append(row)
    assert rows[0]['boundaries']['connectionID']==rows[1]['boundaries']['connectionID']!=rows[2]['boundaries']['connectionID']
    assert not rows[0]['boundaries']['reused'] and rows[1]['boundaries']['reused'] and not rows[2]['boundaries']['reused']
    assert [x['boundary'] for x in rows[0]['boundaries']['terminal']]==['CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS']
    assert [x['boundary'] for x in rows[1]['boundaries']['terminal']]==['REQUEST_SEND','RESPONSE_HEADERS']
    assert rows[0]['boundaries']['requestID']!=rows[1]['boundaries']['requestID'];s.close()
    results.append({'case':'reuse-cross-origin','rows':rows,'status':200,'bodyUnchanged':True})
    for name,m,port,verify,expected in [
      ('proxy-setup-timeout','setup-delay',ports['a'],CERT,'CONNECTION_SETUP'),
      ('tls-setup-timeout','success',ports['tls'],CERT,'CONNECTION_SETUP'),
      ('certificate-failure','success',ports['a'],True,'CONNECTION_SETUP'),
      ('response-headers-timeout','headers-delay',ports['a'],CERT,'RESPONSE_HEADERS')]:
        mode(m);s=session(True);observer=BoundaryObserver(name+'.jsonl')
        row,status,body,error=request(s,observer,port,verify);s.close()
        terminal=row['boundaries']['terminal'];assert error is not None and status is None and body is None
        assert terminal[-1]['boundary']==expected and terminal[-1]['event']=='ERROR'
        assert terminal[-1]['elapsed']>=.2 or name=='certificate-failure'
        stock=session(False);unused=BoundaryObserver('unused-stock.jsonl')
        _,stock_status,stock_body,stock_error=request(stock,unused,port,verify);stock.close()
        assert stock_status==status and stock_body==body and stock_error==error
        results.append({'case':name,'row':row,'code':error,'boundary':expected,'stockBehaviorEqual':True})
    mode('success');plain=session(False);_,status,body,error=request(plain,BoundaryObserver('unused-stock-success.jsonl'),ports['a']);plain.close()
    assert status==200 and body==b'FIXTURE' and error is None
finally:
    server.stdin.write('STOP\n');server.stdin.flush();server.communicate(timeout=3);assert server.returncode==0

# Delegating mixin rethrows the exact object, not a new wrapper; no private monkeypatch.
sentinel=TimeoutError('FAKEPAYLOAD')
class Base:
    timeout=.25;is_closed=True
    def __init__(self):pass
    def connect(self):raise sentinel
    def request(self,*args,**kwargs):raise sentinel
    def getresponse(self):raise sentinel
class Identity(ConnectionObserverMixin,Base):pass
identity=Identity();observer=BoundaryObserver('identity.jsonl')
for method in (identity.connect,identity.request,identity.getresponse):
    row={}
    with observer.request(row,'prepare'):
        try:method();raise AssertionError('Expected sentinel')
        except TimeoutError as caught:assert caught is sentinel
    assert 'FAKE' not in json.dumps(row)
# Shared manager mapping is untouched, default stock classes remain defaults.
from urllib3.poolmanager import pool_classes_by_scheme
assert pool_classes_by_scheme['https'] is urllib3.HTTPSConnectionPool
pathlib.Path('/out/connection-boundary-fixtures.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,
    'environment':'network-none; Node library HTTPS/proxy loopback and real Requests2.34.2/urllib3-2.8.0; scaled fixture timeouts only',
    'exceptionIdentityPreserved':True,'reuseAndCrossOrigin':True,'stockBehaviorEqual':True,
    'privateMonkeypatch':False,'setupScope':'proxy TCP/CONNECT/TLS grouped; DNS/TCP/TLS not individually measured',
    'serverActualExit':server.returncode,'results':results},indent=2),encoding='utf8')
print('PASS real loopback setup/proxy/TLS/headers failure, reuse/cross-origin IDs, stock HTTP behavior, exact exception identity; no source/private patch')
