"""Network-none bootstrap entry: imports only; never enters source main."""
import json,os,pathlib,sys,threading,time,datetime
sys.excepthook=lambda *args:print('BOOTSTRAP_PROBE_FAIL',flush=True)
from common import stage_policy,inventory,versions,trust_hash
from bootstrap_contract import binding,rawsha
from evidence_contract import load

def fd_count():
    # /proc/self/fd includes the transient listing descriptor consistently.
    return len(os.listdir('/proc/self/fd'))

def main():
    begin=time.monotonic();assert stage_policy()=='bootstrap'
    a=binding(load(pathlib.Path('/control/control.json')))
    before=fd_count();threads=len(threading.enumerate())
    assert os.getuid()==65534
    import proxy_entry,worker_entry,album_worker,finalize
    from source_isolation import validate_environment
    assert validate_environment()
    sys.excepthook=lambda *args:print('BOOTSTRAP_PROBE_FAIL',flush=True)
    fixtures=[n for n in sys.modules if n in ('owned_fixture','album_fixture','offline_glue','fixture','test_photo','test_album','fixture_helper','inspection_fixture')]
    assert not fixtures and threads==len(threading.enumerate())==1 and before==fd_count()
    checks=[]
    if a['scope']=='OFFLINE_BOOTSTRAP_SELF_TEST_V1':
        from album_parent import pipeline
        for name,fn in [('proxy',proxy_entry.main),('parent',worker_entry.main),('worker',album_worker.main),('pipeline',lambda:pipeline('/out'))]:
            try:fn()
            except RuntimeError as error:assert error.args==('COLD_ONLY_NO_CAPABILITY',)
            else:raise AssertionError('BOOTSTRAP_CAPABILITY')
            checks.append(name+'_DENIED')
        from live_admission import cold_guard_collections
        for key,value in [('CapDrop','ALL'),('SecurityOpt','no-new-privileges:true')]:
            h=dict(CapDrop=['ALL'],SecurityOpt=['no-new-privileges:true'],CapAdd=None,ExtraHosts=None);h[key]=value
            try:cold_guard_collections(h)
            except RuntimeError:checks.append(key+'_SCALAR_DENIED')
            else:raise AssertionError('BOOTSTRAP_GUARD')
    row=dict(scope=a['scope'],controlSHA=rawsha(pathlib.Path('/control/control.json')),uid=os.getuid(),python=sys.version.split()[0],versions=versions(),trustSHA=trust_hash(),sources=inventory(),fixtureModules=fixtures,threadsBefore=threads,threadsAfter=len(threading.enumerate()),fdBefore=before,fdAfter=fd_count(),fdDelta=fd_count()-before,sourceMainInvoked=False,sourceCalls=0,dnsCalls=0,httpCalls=0,networkCalls=0,elapsed=time.monotonic()-begin,utc=datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00','Z'))
    row['selfTestChecks']=checks
    data=json.dumps(row,sort_keys=True).encode();assert len(data)<=2*1048576
    with pathlib.Path('/out/cold-report.json').open('xb') as f:f.write(data);f.flush();os.fsync(f.fileno())
    print('BOOTSTRAP_IMPORTS_PASS',flush=True)

if __name__=='__main__':main()
