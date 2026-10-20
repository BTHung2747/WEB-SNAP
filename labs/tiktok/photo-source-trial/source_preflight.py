"""Preparation only. No DNS/HTTP/source path; cold imports plus synthetic adapter probes."""
import hashlib,io,json,os,pathlib,socket,sys,threading,time
OUT=pathlib.Path('/out')
sys.excepthook=lambda *a:print('PREFLIGHT_FIXED_FAIL',flush=True)
def main():
    from source_policy_probe import main as cold_policy
    from common import inventory,versions,stage_policy,trust_hash
    before=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
    assert cold_policy()==0 and stage_policy()=='source'
    # Cold check above uses the reviewed source modules without calling main().
    checks=[]
    import requests,urllib3
    from tiktok.core import Budget,GuardedYDL,versions as core_versions
    from yt_dlp.networking import Request
    from candidate import guard
    import egress
    core_versions();checks.append('EXTRACTOR_AND_DEPENDENCY_PINS')
    class FakeAdapter(requests.adapters.HTTPAdapter):
        def __init__(self):super().__init__(max_retries=0);self.calls=0;self.cookieSeen=False;self.status=200
        def send(self,prepared,**kwargs):
            assert kwargs['verify'] is True and kwargs['stream'] is True
            assert kwargs['proxies']=={'http':'http://egress:8888','https':'http://egress:8888'}
            assert prepared.method=='GET' and prepared.body is None
            self.calls+=1;self.cookieSeen=self.cookieSeen or 'Cookie' in prepared.headers
            response=requests.Response();response.status_code=self.status
            response.headers={'Content-Type':'application/octet-stream'}
            response.raw=urllib3.response.HTTPResponse(body=io.BytesIO(b'OFFLINE'),headers=response.headers,status=self.status,preload_content=False)
            return response
    class FakeSession(requests.Session):
        def __init__(self):
            super().__init__();self.fake=FakeAdapter();self.mount('https://',self.fake)
    budget=Budget(input_cap=36*1024*1024,output_cap=16*1024*1024,deadline=time.monotonic()+30)
    ydl=GuardedYDL(budget,OUT,session_factory=FakeSession)
    # Token literals are RAM-only; only fixed codes/numbers/redacted rows survive.
    url='https://www.tiktok.com/FAKEPATH_TOKEN?sign=FAKEQUERY_TOKEN';ydl.allowed_url=url
    try:
        assert ydl.session.trust_env is False and ydl.session.cookies is ydl.cookiejar
        assert ydl.params.get('cookiefile') is None and ydl.params.get('cookiesfrombrowser') is None and ydl.params['usenetrc'] is False
        assert ydl.params['retries']==0 and ydl.params['fragment_retries']==0 and ydl.params['extractor_retries']==0
        checks.append('NO_ACCOUNT_BROWSER_NETRC_ENV_OR_RETRY')
        ydl.cookiejar.set_cookie(requests.cookies.create_cookie('anonymous','FAKECOOKIE_TOKEN',domain='www.tiktok.com',secure=True))
        for _ in range(2):
            with ydl.urlopen(Request(url)) as response:assert response.read()==b'OFFLINE'
        assert budget.requests==2 and ydl.session.fake.calls==2 and ydl.session.fake.cookieSeen
        try:ydl.urlopen(Request(url))
        except Exception:assert budget.failure=='REQUEST_LIMIT'
        else:raise AssertionError('QUOTA')
        assert ydl.session.fake.calls==2;checks.append('METADATA_PREPARED2_THIRD_DENIED')
        budget.phase_deadline=time.monotonic()+60;budget.prepare();budget.response_cap=20*1024*1024;budget.total_cap=20*1024*1024
        with ydl.urlopen(Request(url)) as response:assert response.read()==b'OFFLINE'
        try:ydl.urlopen(Request(url))
        except Exception:assert budget.failure=='REQUEST_LIMIT'
        else:raise AssertionError('QUOTA')
        assert ydl.session.fake.calls==3;checks.append('JPEG_PREPARED1_SECOND_DENIED')
        assert all(row['url']=='[url-redacted]' for row in budget.rows)
        assert not any(token in json.dumps(budget.rows) for token in ('FAKEPATH_TOKEN','FAKEQUERY_TOKEN','FAKECOOKIE_TOKEN'))
        checks.append('PATH_QUERY_COOKIE_REDACTION')
        # Policy rejects these before send; no adapter/body/source action occurs.
        for label,req in [('HEAD',Request(url,method='HEAD')),('AUTH',Request(url,headers={'Authorization':'FAKE'})),('COOKIE',Request(url,headers={'Cookie':'ACCOUNT_FAKE'})),('URL',Request('https://blocked.invalid/FAKE'))]:
            fresh=Budget(input_cap=36*1024*1024,output_cap=16*1024*1024)
            old=ydl.budget;ydl.budget=fresh
            try:
                try:ydl.urlopen(req)
                except Exception:pass
                else:raise AssertionError('REQUEST_POLICY')
                assert fresh.requests==0 and ydl.session.fake.calls==3
                checks.append('BEFORE_SEND_DENY_'+label)
            finally:ydl.budget=old
    finally:
        ydl.close();assert len(ydl.cookiejar)==0
    checks.append('COOKIE_RAM_CLEARED')
    public=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]
    assert guard(public)==public
    for addr in ('127.0.0.1','192.168.1.1','169.254.169.254'):
        try:guard(public+[(socket.AF_INET,socket.SOCK_STREAM,6,'',(addr,443))])
        except ValueError:pass
        else:raise AssertionError('ALL_DNS_GUARD')
    checks.append('ENTIRE_DNS_SET_PRIVATE_REJECTED_NO_SOCKET')
    assert egress.allowed('www.tiktok.com') and egress.allowed('media.tiktokcdn.com') and not egress.allowed('blocked.invalid')
    checks.append('STOCK_HOST_ALLOWLIST')
    # Do not invoke source CLI, even to see whether its guard rejects.
    runner=pathlib.Path('/integration/run.ps1').read_text()
    assert "$Stage='disabled'" in runner
    checks.append('SOURCE_DEFAULT_DISABLED_STATIC_ONLY')
    import copy
    from worker_entry import source_metadata_valid
    row={'summary':{'id':'7678209751167110421','type':'photo','imageCount':1,'images':[{'index':1,'width':64,'height':64}]}}
    assert source_metadata_valid(row);checks.append('FRESH_METADATA_CONTRACT_VALID')
    bad=copy.deepcopy(row);bad['summary']['images'][0]['width']=None
    assert not source_metadata_valid(bad);checks.append('METADATA_UNKNOWN_DIMENSION_DENIED')
    bad=copy.deepcopy(row);bad['summary']['id']='1'
    assert not source_metadata_valid(bad);checks.append('METADATA_WRONG_ID_DENIED')
    assert before==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    result={'status':'PASS_SOURCE_RUNNER_POLICY_OFFLINE','actualExit':0,'checks':checks,'sourceCalls':0,'internetDNS':0,'claimCreated':False,'claimConsumed':False,'sourcePathInvoked':False,'syntheticAdapterCalls':3,'syntheticPreparedAttempts':{'metadata':2,'prepare':1},'syntheticRows':budget.rows,'cookieRAMCleared':True,'fdBefore':before,'fdAfter':len(os.listdir('/proc/self/fd')),'threadsBefore':threads,'threadsAfter':threading.active_count(),'runner':'IMPLEMENTED_DEFAULT_DISABLED_ALLOCATION_GATED','trustSHA':trust_hash(),'fixtureModulesLoaded':[],'python':sys.version.split()[0],'versions':versions(),'reviewedRuntimeSources':inventory(),'preflightSHA':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()}
    (OUT/'preflight-result.json').write_text(json.dumps(result,indent=2));print('PASS source preparation offline; source0/claim0',flush=True);return 0
if __name__=='__main__':sys.exit(main())
