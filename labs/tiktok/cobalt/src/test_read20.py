# Public Requests/urllib3 timeout forwarding + remaining phase and OS parent checks.
import io,json,pathlib,time
from unittest.mock import Mock
import requests,urllib3
from yt_candidate import Budget,Candidate
from yt_candidate_driver import pipeline
URL='https://fixture.invalid/FAKEPATH?token=FAKEQUERY'
results=[]
class Adapter(requests.adapters.HTTPAdapter):
    def __init__(self,pool):super().__init__(max_retries=0);self.pool=pool
    def get_connection_with_tls_context(self,request,verify,proxies=None,cert=None):
        assert verify is True and proxies=={'http':'http://egress:8888','https':'http://egress:8888'}
        return self.pool
for phase,seconds in [('metadata',30),('prepare',180),('metadata',.05),('prepare',.05)]:
    pool=urllib3.HTTPSConnectionPool('fixture.invalid')
    pool.urlopen=Mock(return_value=urllib3.HTTPResponse(body=io.BytesIO(b'X'),status=200,preload_content=False))
    session=requests.Session();session.mount('https://',Adapter(pool));budget=Budget()
    if phase=='prepare':budget.prepare()
    budget.deadline=time.monotonic()+seconds
    with Candidate(session_factory=lambda:session,budget=budget) as c:
        c.ydl.allowed_url=URL;r=c.ydl.urlopen(URL);r.close()
        row=budget.rows[0];t=row['effectiveTimeout'];sent=pool.urlopen.call_args.kwargs
        forwarded=sent['timeout'];assert type(forwarded) is urllib3.util.Timeout
        assert 0<t['connectSeconds']<=10 and 0<t['readCeilingSeconds']<=20
        assert forwarded.connect_timeout==t['connectSeconds']<=t['phaseRemainingSeconds']<=seconds
        assert forwarded.total==t['totalSeconds']==t['phaseRemainingSeconds']
        forwarded.start_connect();time.sleep(.002)
        assert 0<forwarded.read_timeout<=min(t['readCeilingSeconds'],t['totalSeconds'])
        assert sent['redirect'] is False and sent['preload_content'] is False and sent['retries'].total==0
        assert pool.urlopen.call_count==1
        results.append({'case':'forward-'+phase+'-'+str(seconds),'effectiveTimeout':t,'dynamicReadAfterConnect':forwarded.read_timeout})

budget=Budget();budget.deadline=time.monotonic()-1
session=requests.Session();adapter=Adapter(urllib3.HTTPSConnectionPool('fixture.invalid'));adapter.pool.urlopen=Mock()
session.mount('https://',adapter)
with Candidate(session_factory=lambda:session,budget=budget) as c:
    c.ydl.allowed_url=URL
    try:c.ydl.urlopen(URL);raise AssertionError('Expired send allowed')
    except Exception:assert budget.failure=='DEADLINE' and adapter.pool.urlopen.call_count==0 and budget.requests==0
results.append({'case':'expired-before-send','sendCalls':0,'code':'DEADLINE'})

# A blocking adapter can ignore timeout; parent still enforces both absolute phases.
for phase in ('metadata','prepare'):
    start=time.monotonic()
    r,code=pipeline('fixture','7692288554839313682',prepare=phase=='prepare',
        worker_argv=['python3','/lab/src/read20_blocking_worker.py',phase],
        metadata_seconds=1.5 if phase=='metadata' else 3,prepare_seconds=.15)
    assert code==20 and r['workerActualExit']==-9 and r['workerSignal']==9
    assert r['error']==('METADATA_EXTERNAL_DEADLINE_30s' if phase=='metadata' else 'PREPARE_EXTERNAL_DEADLINE_180s')
    entered=json.loads(pathlib.Path('/out/read20-entered-'+phase+'.json').read_text())
    assert entered['adapterEntered'] and entered['phase']==phase
    results.append({'case':'absolute-'+phase,'parentExit':code,'workerExit':r['workerActualExit'],
                    'phaseFixtureDeadline':1.5 if phase=='metadata' else .15,'adapterEntered':True,
                    'elapsed':time.monotonic()-start,'productionDeadline':30 if phase=='metadata' else 180})
assert 'FAKE' not in json.dumps(results)
pathlib.Path('/out/read20-fixtures.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,
  'connectCeiling':10,'readCeiling':20,'absoluteDeadlineIndependent':True,
  'realLibraryForwarding':True,'expiredBeforeSendRejected':True,'absoluteDeadlineAdapterEntered':True,'results':results,
  'environment':'network-none; real HTTPAdapter/urllib3 forwarding with fakepool and ignored-timeout child; shortened OS fixtures'},indent=2),encoding='utf8')
print('PASS read20 exact Timeout forwarding/full+low remaining/expired reject/real library dynamic read; absolute metadata30 and prepare180 paths independent; no source')
