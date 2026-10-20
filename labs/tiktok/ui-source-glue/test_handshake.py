"""Source-schema filesystem delta, using only OFFLINE_TEST_ONLY vectors."""
import copy,datetime,hashlib,importlib.util,json,pathlib,sys,tempfile
spec=importlib.util.spec_from_file_location('source_handshake',pathlib.Path(__file__).with_name('handshake.py'))
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
ev=pathlib.Path(sys.argv[1]).resolve();evidence=pathlib.Path('docs/evidence').resolve()
assert ev.is_relative_to(evidence) and ev.relative_to(evidence).parts[0].startswith('ui-source-glue-') and ev.is_dir()
receipt=ev/(sys.argv[2] if len(sys.argv)>2 else 'python-tests.json');assert receipt.parent==ev and not receipt.exists()
rows=[];BASE=10_000_000_000;clock=lambda:BASE+1_000_000
def raw(value):return json.dumps(value,separators=(',',':')).encode()
def setup(root):
    budget=pathlib.Path(__file__).with_name('budget-policy.json').read_bytes()
    c=dict(schema='wed-ui-photo-source-contract-v1',mode='OFFLINE_TEST_ONLY',runID='OFFLINE_TEST_ONLY_VECTOR',origin=h.io.ORIGIN,path='/',approvedURL='https://www.tiktok.com/@offline_vector/photo/7000000000000000007',expectedPostID='7000000000000000007',selectedIndex=2,decisionSHA256='',budgetSHA256=h.io.digest(budget),startMonoNs=str(BASE),observationDeadlineMonoNs=str(BASE+100_000_000_000),cleanupDeadlineMonoNs=str(BASE+120_000_000_000),runDeadlineMonoNs=str(BASE+121_000_000_000))
    d=dict(schema='wed-ui-photo-source-decision-v1',mode=c['mode'],state='OFFLINE_TEST_ONLY',runID=c['runID'],approvedURL=c['approvedURL'],expectedPostID=c['expectedPostID'],selectedIndex=2,budgetSHA256=c['budgetSHA256'],expiresAt='2099-01-01T00:00:00Z')
    (root/'source-decision.json').write_bytes(raw(d));c['decisionSHA256']=h.io.digest(raw(d));(root/'source-budget.json').write_bytes(budget)
    # Accepted atomic helper; vector publishing is not source authorization.
    h.io.publish_atomic(root,h.io.CONTRACT,c)
    screenshot=b'OFFLINE_TEST_ONLY_SCREENSHOT_VECTOR';(root/'browser.jpg').write_bytes(screenshot)
    o=dict(schema='wed-ui-photo-source-observation-v1',**h.binding(c),status='PASS',tabCleanup='CLOSED',screenshot=dict(status='SAVED',file='browser.jpg',sha256=h.io.digest(screenshot)))
    return c,d,o
def reject(fn):
    try:fn()
    except (h.Rejected,FileExistsError):return
    raise AssertionError('INVALID_VECTOR_ACCEPTED')
def case(name,fn):
    with tempfile.TemporaryDirectory(prefix='OFFLINE_TEST_ONLY-',dir=ev) as tmp:
        root=pathlib.Path(tmp).resolve();assert root.parent==ev
        c,d,o=setup(root);fn(root,c,d,o)
    rows.append(dict(case=name,status='PASS'))
def publish(root,o,**kw):return h.publish_observation(root,o,offline=True,clock=clock,**kw)
def accept(root,o):
    publish(root,o);decision=h.wait_decision(root,offline=True,clock=clock);assert decision['status']=='ACCEPTED';return decision
def final(root,cleanup='CLOSED',execution='PASS',**kw):return h.complete(root,cleanup,execution,offline=True,clock=clock,**kw)
def main():
    def missing_entry(root,c,d,o):
        import os
        entry_spec=importlib.util.spec_from_file_location('source_passive_entry',pathlib.Path(__file__).with_name('entry.py'))
        entry=importlib.util.module_from_spec(entry_spec);entry_spec.loader.exec_module(entry)
        before={k:os.environ.get(k) for k in ('STEP5_EXECUTE_SOURCE','STEP5_OFFLINE_TEST')}
        try:
            os.environ.pop('STEP5_EXECUTE_SOURCE',None);os.environ.pop('STEP5_OFFLINE_TEST',None);assert entry.main()==78
            os.environ['STEP5_EXECUTE_SOURCE']='1';os.environ['STEP5_OFFLINE_TEST']='1';assert entry.main()==78
        finally:
            for k,v in before.items():
                if v is None:os.environ.pop(k,None)
                else:os.environ[k]=v
    case('PASSIVE_ENTRY_MISSING_OR_FIXTURE_ENV_DENY',missing_entry)
    def foreign(root,c,d,o):
        d['expiresAt']=(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(seconds=121)).isoformat()
        (root/'source-decision.json').write_bytes(raw(d));c['decisionSHA256']=h.io.digest(raw(d));(root/h.io.CONTRACT).write_bytes(raw(c))
        assert h.contract(root,offline=True,check_owner_clock=False)['mode']=='OFFLINE_TEST_ONLY'
        reject(lambda:h.contract(root,check_owner_clock=False))
    case('FOREIGN_OWNER_TICKS_ONLY_DURATIONS_NO_LIVE_CAPABILITY',foreign)
    def happy(root,c,d,o):
        accept(root,o);r=final(root);assert r['status']=='PASS_OFFLINE_HANDSHAKE';assert r['sourceRequests']=='UNKNOWN';assert (root/h.io.CLEANUP).exists()
        before=(root/h.io.COMPLETION).read_bytes();reject(lambda:final(root));assert (root/h.io.COMPLETION).read_bytes()==before
    case('BOUND_OFFLINE_PASS_CLEANUP_BEFORE_COMPLETION_NO_OVERWRITE',happy)
    for key,value in [('mode','COMBINED_FIXTURE_SOURCE_OFF'),('runID','OFFLINE_TEST_ONLY_WRONG'),('expectedPostID','7000000000000000008'),('selectedIndex',3),('decisionSHA256','0'*64),('budgetSHA256','0'*64),('observationDeadlineMonoNs',str(BASE+99_000_000_000)),('origin','http://127.0.0.1:5207'),('path','/wrong')]:
        def bad(root,c,d,o,key=key,value=value):
            o[key]=value;reject(lambda:publish(root,o));assert not (root/h.io.OBSERVATION).exists()
            h.io.publish_atomic(root,h.io.OBSERVATION,o)
            r=h.wait_decision(root,offline=True,clock=clock);assert r['status']=='REJECTED';assert final(root)['status']=='FAIL'
        case('REJECT_OBSERVATION_'+key,bad)
    def old(root,c,d,o):
        fixture=dict(schema='wed-combined-browser-observation-v1',runID=c['runID'],fixtureID='7000000000000000001',status='PASS');reject(lambda:publish(root,fixture))
    case('OLD_FIXTURE_OBSERVATION_REJECT',old)
    def role(root,c,d,o):
        reject(lambda:publish(root,o,role='owner'));reject(lambda:h.wait_decision(root,offline=True,clock=clock,role='producer'));reject(lambda:final(root,role='producer'))
        assert not (root/h.io.OBSERVATION).exists() and not (root/h.io.DECISION).exists() and not (root/h.io.CLEANUP).exists()
    case('PRODUCER_OWNER_ROLES',role)
    def repeated(root,c,d,o):
        publish(root,o);before=(root/h.io.OBSERVATION).read_bytes();reject(lambda:publish(root,o));assert before==(root/h.io.OBSERVATION).read_bytes()
        h.wait_decision(root,offline=True,clock=clock);reject(lambda:h.wait_decision(root,offline=True,clock=clock))
    case('OBSERVATION_DECISION_ATOMIC_NOOVERWRITE',repeated)
    def unknown(root,c,d,o):
        o['tabCleanup']='UNKNOWN';publish(root,o);r=h.wait_decision(root,offline=True,clock=clock);assert r['status']=='REJECTED' and r['code']=='CLEANUP_UNKNOWN'
    case('TAB_CLEANUP_UNKNOWN_REJECT',unknown)
    for state in ('UNKNOWN','CLOSED'):
        def cleanup(root,c,d,o,state=state):
            accept(root,o);r=final(root,cleanup=state,execution='FAIL' if state=='CLOSED' else 'PASS');assert r['status']=='FAIL'
        case('FINAL_'+('EXECUTION_FAIL' if state=='CLOSED' else 'CLEANUP_UNKNOWN'),cleanup)
    def late(root,c,d,o):
        publish(root,o);r=h.wait_decision(root,offline=True,clock=lambda:int(c['observationDeadlineMonoNs']));assert r['status']=='LATE';assert final(root)['status']=='FAIL'
    case('OBSERVATION_CUTOFF_EXACT',late)
    def cleanup_late(root,c,d,o):
        accept(root,o);r=h.complete(root,'CLOSED','PASS',offline=True,clock=lambda:int(c['cleanupDeadlineMonoNs']));assert r['status']=='FAIL' and r['code']=='CLEANUP_DEADLINE'
    case('CLEANUP_CUTOFF_EXACT',cleanup_late)
    def changed(root,c,d,o):
        accept(root,o);(root/'browser.jpg').write_bytes(b'OFFLINE_TEST_ONLY_CHANGED');assert final(root)['status']=='FAIL'
    case('SCREENSHOT_CHANGED_AFTER_ACCEPT',changed)
    def changed_obs(root,c,d,o):
        accept(root,o);o['selectedIndex']=3;(root/h.io.OBSERVATION).write_bytes(raw(o));assert final(root)['status']=='FAIL'
    case('OBSERVATION_CHANGED_AFTER_ACCEPT',changed_obs)
    def no_observation(root,c,d,o):
        r=h.wait_decision(root,offline=True,clock=lambda:int(c['observationDeadlineMonoNs']));assert r['status']=='NOT_OBSERVED';assert final(root)['status']=='FAIL'
    case('MISSING_OBSERVATION_NO_PASS',no_observation)
    for key in ('source-decision.json','source-budget.json'):
        def mismatch(root,c,d,o,key=key):
            (root/key).write_bytes(b'OFFLINE_TEST_ONLY_CHANGED');reject(lambda:h.contract(root,offline=True,clock=clock))
        case('EXACT_DOCUMENT_HASH_'+key,mismatch)
    for state in ('CONSUMED','APPROVED_OLD','COMBINED_FIXTURE_SOURCE_OFF'):
        def consumed(root,c,d,o,state=state):
            d['state']=state;(root/'source-decision.json').write_bytes(raw(d));c['decisionSHA256']=h.io.digest(raw(d));(root/h.io.CONTRACT).write_bytes(raw(c));reject(lambda:h.contract(root,offline=True,clock=clock))
        case('AUTHORITY_STATE_REJECT_'+state,consumed)
    def expired(root,c,d,o):
        d['expiresAt']='2000-01-01T00:00:00Z';(root/'source-decision.json').write_bytes(raw(d));c['decisionSHA256']=h.io.digest(raw(d));(root/h.io.CONTRACT).write_bytes(raw(c));reject(lambda:h.contract(root,offline=True,clock=clock))
    case('EXPIRED_AUTHORITY_REJECT',expired)
    def policy(root,c,d,o):
        b=json.loads((root/'source-budget.json').read_bytes());b['dnsUnique']=65;(root/'source-budget.json').write_bytes(raw(b));c['budgetSHA256']=h.io.digest(raw(b));d['budgetSHA256']=c['budgetSHA256'];(root/'source-decision.json').write_bytes(raw(d));c['decisionSHA256']=h.io.digest(raw(d));(root/h.io.CONTRACT).write_bytes(raw(c));reject(lambda:h.contract(root,offline=True,clock=clock))
    case('BUDGET_POLICY_NOT_ONLY_HASH',policy)
    case('OFFLINE_VECTOR_CANNOT_PASS_SOURCE_GATE',lambda root,c,d,o:reject(lambda:h.contract(root,clock=clock)))
    result=dict(status='PASS_OFFLINE_SOURCE_HANDSHAKE_DELTA',python=sys.version.split()[0],caseCount=len(rows),cases=rows,sourceCalls=0,claimsCreated=0,atomicImplementation='REUSED_ACCEPTED_HELPER',screenshot='SYNTHETIC_HASH_VECTOR_NOT_IMAGE_REVIEW',utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    with receipt.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
    print(json.dumps(dict(status=result['status'],cases=len(rows))))
if __name__=='__main__':main()
