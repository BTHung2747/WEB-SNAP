# Offline library error mapping: real HTTPAdapter.send/Response + fake pool.urlopen only.
import io,json,pathlib,time,types
from unittest.mock import Mock
import requests,urllib3
import urllib3.exceptions as ue
from yt_candidate import Candidate,versions
from send_diagnostics import observed_send,classify,worker_class
SECRET='https://FAKEUSER:FAKEPASS@fixture.invalid/FAKEPATH?token=FAKEQUERY Cookie: FAKECOOKIE'
URL='https://fixture.invalid/FAKEPATH?token=FAKEQUERY'
results=[];versions()

class LibraryAdapter(requests.adapters.HTTPAdapter):
    def __init__(self,pool):super().__init__(max_retries=0);self.fixture_pool=pool
    def get_connection_with_tls_context(self,request,verify,proxies=None,cert=None):
        assert verify is True and proxies=={'http':'http://egress:8888','https':'http://egress:8888'}
        return self.fixture_pool

def run(name,reason=None,expected=None,status=None,phase='prepare'):
    pool=urllib3.HTTPSConnectionPool('fixture.invalid')
    if reason is not None:
        raw_error=reason(pool)
        def delayed(**kwargs):time.sleep(.003);raise raw_error
        pool.urlopen=Mock(side_effect=delayed)
    else:
        raw=urllib3.HTTPResponse(body=io.BytesIO(b'fixture'),status=status,
             headers={'content-type':'video/mp4','set-cookie':'FAKECOOKIE','location':URL},preload_content=False)
        def delayed(**kwargs):time.sleep(.003);return raw
        pool.urlopen=Mock(side_effect=delayed)
    session=requests.Session();session.mount('https://',LibraryAdapter(pool))
    with Candidate(session_factory=lambda:session) as candidate:
        candidate.ydl.allowed_url=URL
        if phase=='prepare':candidate.budget.prepare()
        error=None;response=None
        try:response=candidate.ydl.urlopen(URL)
        except Exception as caught:error=caught
        if response is not None:response.close()
        row=candidate.budget.rows[0];diag=row['sendDiagnostic']
        assert diag['phase']==phase and diag['seconds']>=.002
        assert all(diag[k]=='UNKNOWN' for k in ('proxyConnect','originTLS','headerWait'))
        assert diag['code']==expected,(name,diag['code'])
        assert diag['status']==(status if status is not None else 'UNKNOWN')
        assert candidate.budget.requests==1 and candidate.budget.total==0
        if status is not None:
            assert row['status']==status
            if 300<=status<400:assert candidate.budget.failure=='REDIRECT_DENIED'
            elif status>=400:assert candidate.budget.failure=='HTTP_STATUS'
        else:assert error is not None and 'status' not in row and candidate.budget.failure is None
        sent=pool.urlopen.call_args.kwargs
        assert pool.urlopen.call_count==1 and sent['redirect'] is False and sent['preload_content'] is False
        assert sent['timeout'].connect_timeout==10 and sent['retries'].total==0
        sent['timeout'].start_connect()
        assert 19<sent['timeout'].read_timeout<=20 and sent['timeout'].total==row['effectiveTimeout']['totalSeconds']
        assert 'FAKE' not in json.dumps(row)
        results.append({'case':name,'diagnostic':diag,'libraryMappingReal':True,'poolSendCalls':1,
                        'timeoutConnect':10,'timeoutReadCeiling':20,'decodedBytes':0})
    print('PASS send diagnostics '+name+'; fake pool, real Requests/urllib3, no source')

run('connect-timeout',lambda p:ue.MaxRetryError(p,SECRET,ue.ConnectTimeoutError(SECRET)),'CONNECT_TIMEOUT')
run('read-timeout',lambda p:ue.ReadTimeoutError(p,SECRET,SECRET),'READ_TIMEOUT')
run('proxy-connect-failure',lambda p:ue.MaxRetryError(p,SECRET,ue.ProxyError(SECRET,ue.NewConnectionError(None,SECRET))),'PROXY_ERROR')
run('tls-failure',lambda p:ue.MaxRetryError(p,SECRET,ue.SSLError(SECRET)),'TLS_ERROR')
run('new-connection-is-not-timeout',lambda p:ue.MaxRetryError(p,SECRET,ue.NewConnectionError(None,SECRET)),'NEW_CONNECTION_ERROR')
for status in (200,302,403,404,500):run('http-status-'+str(status),expected='HTTP_RESPONSE',status=status,phase='metadata')

# Exact original error identity survives the observer; poisoning cannot leak names/text/repr.
class FAKECLASS(RuntimeError):
    def __str__(self):raise AssertionError('String conversion forbidden')
    def __repr__(self):raise AssertionError('Repr conversion forbidden')
poison=FAKECLASS(SECRET);poison.__cause__=poison
row={};adapter=types.SimpleNamespace(send=Mock(side_effect=poison))
try:observed_send(adapter,None,row,'prepare');raise AssertionError('Expected error')
except FAKECLASS as caught:assert caught is poison
assert row['sendDiagnostic']['code']=='UNKNOWN' and row['sendDiagnostic']['classes']==[] and worker_class(poison)=='UNKNOWN'
assert 'FAKE' not in json.dumps(row) and adapter.send.call_count==1
known=requests.exceptions.ReadTimeout(SECRET);known.__cause__=ue.ReadTimeoutError(None,SECRET,SECRET)
row={};adapter=types.SimpleNamespace(send=Mock(side_effect=known))
try:observed_send(adapter,None,row,'prepare');raise AssertionError('Expected timeout')
except requests.exceptions.ReadTimeout as caught:assert caught is known
assert row['sendDiagnostic']['code']=='READ_TIMEOUT' and 'FAKE' not in json.dumps(row)
chain=RuntimeError(SECRET)
for _ in range(100):wrapped=RuntimeError(SECRET);wrapped.__cause__=chain;chain=wrapped
assert classify(chain)==('UNKNOWN',[])
print('PASS bounded cyclic/long exception graph, exact rethrow, poisoned repr/name/header/URL strings never exported')
pathlib.Path('/out/send-diagnostics-fixtures.json').write_text(json.dumps({
    'status':'PASS','environment':'network-none real Requests2.34.2/urllib3-2.8.0 Adapter.send; fake delayed pool.urlopen',
    'sourceRequests':0,'originalExceptionsPreserved':True,'unknownSubStagesPreserved':True,
    'results':results,'poisonedPayloadRejected':True,'boundedGraph':True},indent=2),encoding='utf8')
