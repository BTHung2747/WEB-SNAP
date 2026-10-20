"""Cold source policy in network-none; no source main or claims."""
import asyncio,json,os,pathlib,sys,threading
from unittest.mock import patch
OUT=pathlib.Path('/out');CONTROL=pathlib.Path('/control/control.json');PHASE='START'
def main():
    global PHASE
    PHASE='BASE_POLICY'
    from common import stage_policy,isolation,inventory,versions,trust_hash
    from source_policy import validate
    before=len(os.listdir('/proc/self/fd'));threads=threading.active_count();checks=[]
    assert stage_policy()=='source' and os.getuid()==65534 and sys.version.split()[0]=='3.11.2'
    PHASE='COLD_IMPORT';import proxy_entry,worker_entry,finalize
    isolation(OUT/'cold-isolation.json','source');checks.append('COLD_SOURCE_IMPORTS_TRUST')
    from tiktok.core import Budget,GuardedYDL
    import requests,time
    ydl=GuardedYDL(Budget(deadline=time.monotonic()+30),OUT)
    assert ydl.session.trust_env is False and ydl.params.get('cookiefile') is None and ydl.params.get('cookiesfrombrowser') is None and ydl.params['usenetrc'] is False
    ydl.cookiejar.set_cookie(requests.cookies.create_cookie('anonymous','FAKE_RAM_ONLY',domain='www.tiktok.com',secure=True))
    ydl.close();assert len(ydl.cookiejar)==0;checks.append('NO_ACCOUNT_ENV_NETRC_COOKIE_RAM_CLEAR')
    good={'summary':{'id':'7678209751167110421','type':'photo','imageCount':1,'images':[{'index':1,'width':64,'height':64}]}}
    assert worker_entry.source_metadata_valid(good)
    import copy
    for key,value in (('type','video'),('id','1')):
        bad=copy.deepcopy(good);bad['summary'][key]=value;assert not worker_entry.source_metadata_valid(bad)
    bad=copy.deepcopy(good);bad['summary']['images'][0]['width']=8193;assert not worker_entry.source_metadata_valid(bad)
    checks.append('SOURCE_METADATA_TYPE_ID_DIMENSIONS_BEFORE_PREPARE')
    PHASE='CONTROL_NEGATIVES'
    for value in ({},{'stage':'offline','phaseDeadline':0},{'stage':'source','phaseDeadline':True},
                  {'stage':'source','phaseDeadline':float('nan')},{'stage':'source','phaseDeadline':-1},
                  {'stage':'source','phaseDeadline':0,'mode':'normal'},{'stage':'source','phaseDeadline':0,'headers':{}},
                  {'stage':'source','phaseDeadline':0,'cookies':[]}):
        try:validate(value)
        except RuntimeError:checks.append('CONTROL_REJECT')
        else:raise AssertionError('CONTROL')
    PHASE='ENV_NEGATIVES'
    for key in ('FIXTURE_TEST','TIKTOK_APP_FIXTURE','SSL_CERT_FILE','SSL_CERT_DIR','REQUESTS_CA_BUNDLE','CURL_CA_BUNDLE',
                'HTTP_PROXY','https_proxy','ALL_PROXY','NO_PROXY','NETRC','COOKIEFILE','COOKIESFROMBROWSER','TIKTOK_COOKIE',
                'TIKTOK_HEADERS','YTDLP_COOKIES','SOURCE_HEADERS','BROWSER_PROFILE'):
        with patch.dict(os.environ,{key:'FAKE_SECRET'}):
            try:stage_policy()
            except RuntimeError:checks.append('ENV_REJECT')
            else:raise AssertionError('ENV')
    PHASE='IMPORT_NEGATIVES'
    for name in ('owned_fixture','offline_glue','fixture','photo_fixture_provider','sitecustomize'):
        with patch.dict(sys.modules,{name:object()}):
            try:stage_policy()
            except RuntimeError:checks.append('IMPORT_REJECT')
            else:raise AssertionError('IMPORT')
    with patch('common.trust_hash',return_value='UNKNOWN'):
        try:stage_policy()
        except RuntimeError:checks.append('TRUST_REJECT')
        else:raise AssertionError('TRUST')
    # Three inherited DNS cases only; helper receives numeric fixture, no Internet DNS.
    PHASE='DNS';from test_diagnostics import dns_case,RESULTS
    async def dns():
        await dns_case('cold_dns_numeric')
        await dns_case('cold_dns_error',mode='error',expected='OSError')
        await dns_case('cold_dns_trace_primary',fault='raise',primary=True,expected='OSError')
    asyncio.run(dns())
    from dns_diagnostic import validate_receipt
    for r in RESULTS:assert validate_receipt(r['receipt'])['accepted']==(r['exception'] is None)
    PHASE='FD_THREAD';assert before==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    result=dict(status='PASS_COLD_SOURCE_POLICY_NETWORK_NONE',actualExit=0,checks=checks,dnsCases=RESULTS,
                fdBefore=before,fdAfter=len(os.listdir('/proc/self/fd')),threadsBefore=threads,threadsAfter=threading.active_count(),
                sources=inventory(),versions=versions(),python=sys.version.split()[0],trustSHA=trust_hash(),
                sourceCalls=0,internetDNS=0,realClaims=0,sourceMainInvoked=False)
    (OUT/'cold-result.json').write_text(json.dumps(result,indent=2));print('PASS_COLD_SOURCE_POLICY checks='+str(len(checks)),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException as error:
        fixed=error.args[0] if type(error) is RuntimeError and error.args and error.args[0] in ('SOURCE_CONTROL_POLICY','SOURCE_ENV_POLICY','SOURCE_IMPORT_POLICY','SOURCE_TRUST_POLICY','STAGE_POLICY') else 'UNKNOWN'
        (OUT/'cold-failure.json').write_text(json.dumps(dict(code='COLD_POLICY_FAIL',cause=fixed,phase=PHASE,actualExit=20)))
        print('COLD_POLICY_FAIL',flush=True);sys.exit(20)
