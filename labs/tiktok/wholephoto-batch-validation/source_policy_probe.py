"""Network-none probe of source cold imports/config. Does not call DNS or HTTP."""
import importlib,json,os,pathlib,sys
from common import stage_policy,isolation,inventory,versions,trust_hash
OUT=pathlib.Path('/out');CONTROL=pathlib.Path('/control/control.json')
def main():
    assert os.getuid()==65534 and stage_policy()=='source'
    import proxy_entry,worker_entry,finalize
    isolation(OUT/'policy-isolation.json','source')
    checks=['cold_source_imports','original_image_trust','network_none_no_requests']
    original=CONTROL.read_text()
    for settings in ({'stage':'offline','phaseDeadline':0},{'stage':'source','phaseDeadline':0,'mode':'normal'}):
        CONTROL.write_text(json.dumps(settings))
        try:stage_policy()
        except RuntimeError:checks.append('invalid_control_rejected')
        else:raise AssertionError('SOURCE_POLICY')
    CONTROL.write_text(original)
    for key in ('FIXTURE_TEST','TIKTOK_APP_FIXTURE','REQUESTS_CA_BUNDLE','SSL_CERT_FILE'):
        os.environ[key]='FAKE'
        try:
            try:stage_policy()
            except RuntimeError:checks.append('invalid_env_rejected')
            else:raise AssertionError('SOURCE_POLICY')
        finally:del os.environ[key]
    result={'status':'PASS_SOURCE_POLICY_OFFLINE','checks':checks,'sourceCalls':0,'uid':os.getuid(),
            'trustSHA':trust_hash(),'fixtureModulesLoaded':[],
            'python':sys.version.split()[0],'versions':versions(),'sources':inventory()}
    (OUT/'policy-result.json').write_text(json.dumps(result,indent=2))
    return 0
if __name__=='__main__':
    try:sys.exit(main())
    except Exception:print('POLICY_PROBE_FAIL',flush=True);sys.exit(20)
