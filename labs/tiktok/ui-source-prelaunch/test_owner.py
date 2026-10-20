"""Prelaunch delta only. Actual producer filesystem I/O, fake runtime callbacks."""
import contextlib,copy,io,json,pathlib,shutil,sys,tempfile,time
import owner,publisher
ev=pathlib.Path(sys.argv[1]).resolve();workspace=pathlib.Path.cwd().resolve()
assert ev.is_relative_to(workspace/'docs/evidence') and ev.is_dir()
plan=json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8-sig'));rows=[]
def write(path,value):
    with path.open('x',encoding='utf-8') as f:json.dump(value,f)
def producer(root,c,**change):
    (root/'browser.jpg').write_bytes(b'OFFLINE_TEST_ONLY_SCREENSHOT_NOT_AN_IMAGE')
    o=dict(schema='wed-ui-photo-source-observation-v1',**publisher.protocol.binding(c),status='PASS',tabCleanup='CLOSED',screenshot=dict(status='SAVED',file='browser.jpg',sha256=publisher.protocol.io.digest((root/'browser.jpg').read_bytes())))
    o.update(change);write(root/'producer-input.json',o)
    with contextlib.redirect_stdout(io.StringIO()):return publisher.main(['--root',str(root),'--input',str(root/'producer-input.json'),'--offline-test-only'])
class FakeRuntime:
    offline_test_only=True
    def __init__(self,fail_step=None,wrong_owner=False,cleanup_fail=False):self.calls=[];self.inventory={};self.removals=[];self.fail_step=fail_step;self.wrong_owner=wrong_owner;self.cleanup_fail=cleanup_fail
    def step(self,name,root,c,plan):
        self.root=root;self.run=c['runID'];self.calls.append(name);value=dict(mode='OFFLINE_TEST_ONLY',simulatedExit=0)
        if name=='allocate_owned_resources':
            resources=[dict(id='OFFLINE_TEST_ONLY_INTERNAL',kind='network',owner=self.run),dict(id='OFFLINE_TEST_ONLY_APP',kind='container',owner=self.run),dict(id='OFFLINE_TEST_ONLY_INGRESS',kind='network',owner=self.run)]
            self.inventory={r['id']:r for r in resources};value['resources']=resources
        if name=='browser_handoff':
            value['simulatedExit']=producer(root,c);assert not (root/publisher.protocol.io.DECISION).exists();assert not (root/publisher.protocol.io.COMPLETION).exists()
        if name=='wait_native_runtime':value.update(exits=dict(app=0,gateway=0,proxy=0),signals=dict(app=None,gateway=None,proxy=None))
        if name=='final_runtime_gate':value['proof']='SIMULATED_RUNTIME_GATE_ONLY'
        if name==self.fail_step:value.update(packet='PASS',simulatedExit=20)
        return value
    def inspect(self,r):return dict(mode='OFFLINE_TEST_ONLY',simulatedExit=0,id=r['id'],owner='OFFLINE_TEST_ONLY_FOREIGN' if self.wrong_owner and r['kind']=='container' else r['owner'])
    def remove(self,r):
        assert not (self.root/publisher.protocol.io.COMPLETION).exists();self.removals.append(r['id'])
        if self.cleanup_fail and r['kind']=='container':return dict(mode='OFFLINE_TEST_ONLY',simulatedExit=20)
        self.inventory.pop(r['id'],None);return dict(mode='OFFLINE_TEST_ONLY',simulatedExit=0)
    def remaining(self,run):return dict(mode='OFFLINE_TEST_ONLY',simulatedExit=0,ids=[r['id'] for r in self.inventory.values() if r['owner']==run])
def reject(fn):
    try:fn()
    except (owner.NotReady,FileExistsError):return
    raise AssertionError('INVALID_ACCEPTED')
def test(name,fn):fn();rows.append(dict(case=name,status='PASS'))
def main():
    with tempfile.TemporaryDirectory(prefix='OFFLINE_TEST_ONLY-',dir=ev) as tmp:
        root=pathlib.Path(tmp).resolve();assert root.parent==ev
        def case_root(tag):return root/('OFFLINE_TEST_ONLY_'+tag)
        for name,payload in [('DEFAULT',{}),('MISSING_AUTHORITY',dict(instruction='')),('TARGET_ONLY',dict(targetSelectionConfirmed=True,executionPermittedByThisRecord=False)),('OLD',dict(state='APPROVED_OLD')),('CONSUMED',dict(state='CONSUMED')),('SELF_ATTESTATION',dict(state='SELF_ATTESTED')),('OFFLINE_FLAGS',dict(mode='OFFLINE_TEST_ONLY'))]:
            def denied(payload=payload):
                called=[];reject(lambda:owner.deny_live(payload,lambda:called.append('LIVE')));assert called==[]
            test('LIVE_DENY_'+name,denied)
        def static():
            owner.checked_plan(plan);assert len(plan['mounts'])==123 and len(plan['buildPins'])==3
            assert plan['workflowOwner']=='FRONTEND_BROWSER_ONLY' and len(plan['supervisorMirrors'])==len(plan['expectedSourceProjection'])
            assert len(plan['requiredNotRun'])==7 and plan['budget']['approvedBrowserMinimum'] is None
            roles={r['role']:r for r in plan['resources']['roles']};assert sum(r['memoryMiB'] for r in roles.values())==928
            for role,argv in plan['createArgvTemplates'].items():
                assert argv[0]=='create' and '--pull=never' in argv and '--read-only' in argv and '--cap-drop' in argv and 'ALL' in argv
                assert 'no-new-privileges:true' in argv and 'private' in argv
                assert argv[argv.index('--memory')+1]==argv[argv.index('--memory-swap')+1]
                assert not any('STEP5_OFFLINE_TEST=' in s or '/offline' in s or '/compat' in s for s in argv)
                if role=='gateway':assert argv[argv.index('-p')+1]=='127.0.0.1:5206:5206'
                else:assert '-p' not in argv
            controls=plan['controlMounts'];assert next(m for m in controls if m['target']=='/control')['readOnly'] is False
            assert all(m['readOnly'] for m in controls if m['target']!='/control')
        test('DRY_PLAN_ROLE_ARGV_PINS_CAPS_AND_CONTROL_OWNERSHIP',static)
        def happy():
            r=case_root('HAPPY');ops=FakeRuntime();result=owner.simulate(r,plan,'OFFLINE_TEST_ONLY_HAPPY',ops)
            assert result['status']=='PASS_OWNER_SIMULATION_ONLY' and result['sourceCalls']==0 and result['liveClaimsCreated']==0
            assert ops.calls==list(owner.STEPS);assert ops.removals[0]=='OFFLINE_TEST_ONLY_APP' and len(ops.removals)==3
            c=publisher.protocol.contract(r,offline=True);completion=publisher.protocol.io.load(r/publisher.protocol.io.COMPLETION)
            assert completion['status']=='PASS_OFFLINE_HANDSHAKE';assert publisher.protocol.io.load(r/publisher.protocol.io.CLEANUP)['resources']=='CLOSED'
            before=(r/publisher.protocol.io.OBSERVATION).read_bytes()
            with contextlib.redirect_stdout(io.StringIO()):code=publisher.main(['--root',str(r),'--input',str(r/'producer-input.json'),'--offline-test-only'])
            assert code==23 and before==(r/publisher.protocol.io.OBSERVATION).read_bytes()
            new_ops=FakeRuntime();reject(lambda:owner.simulate(r,plan,'OFFLINE_TEST_ONLY_HAPPY',new_ops));assert new_ops.calls==[]
        test('OWNER_PRODUCER_ATOMIC_ONCE_COMPLETION_AFTER_OWN_CLEANUP',happy)
        for step in ['allocate_owned_resources','browser_handoff','wait_native_runtime','final_runtime_gate']:
            def fails(step=step):
                ops=FakeRuntime(fail_step=step);result=owner.simulate(case_root(step.upper()),plan,'OFFLINE_TEST_ONLY_FAIL',ops)
                assert result['status']=='FAIL_OWNER_SIMULATION' and 'final_runtime_gate' not in ops.calls[:ops.calls.index(step)]
                assert result['simulationCleanupOK'] and ops.inventory=={}
            test('PACKET_PASS_SIMULATED_EXIT20_STOPS_'+step.upper(),fails)
        for foreign in [True,False]:
            def bad_cleanup(foreign=foreign):
                ops=FakeRuntime(wrong_owner=foreign,cleanup_fail=not foreign);result=owner.simulate(case_root('FOREIGN' if foreign else 'CLEANUP_ERROR'),plan,'OFFLINE_TEST_ONLY_CLEANUP',ops)
                assert result['status']=='FAIL_OWNER_SIMULATION' and not result['simulationCleanupOK']
                assert len(ops.removals)==(2 if foreign else 3)
                if foreign:assert 'OFFLINE_TEST_ONLY_APP' not in ops.removals
            test('CLEANUP_FAIL_NO_FOREIGN_REMOVE' if foreign else 'CLEANUP_ERROR_NOT_COMPLETION_PASS',bad_cleanup)
        def insufficient():
            ops=FakeRuntime();r=case_root('NO_BUDGET');reject(lambda:owner.simulate(r,plan,'OFFLINE_TEST_ONLY_BUDGET',ops,browser_minimum=30));assert not r.exists() and ops.calls==[]
        test('INSUFFICIENT_BROWSER_BUDGET_BEFORE_NAMESPACE',insufficient)
        def pin():
            altered=copy.deepcopy(plan);altered['pins'][0]['sha256']='0'*64;ops=FakeRuntime();r=case_root('PIN_DRIFT');reject(lambda:owner.simulate(r,altered,'OFFLINE_TEST_ONLY_PIN',ops));assert not r.exists() and ops.calls==[]
        test('PIN_DRIFT_BEFORE_SIMULATION_CALLBACK',pin)
        def live_id():
            ops=FakeRuntime();r=case_root('BAD_ID');reject(lambda:owner.simulate(r,plan,'0'*32,ops));assert not r.exists() and ops.calls==[]
        test('LIVE_SHAPED_ID_CANNOT_CREATE_OFFLINE_DOCUMENTS',live_id)
        def producer_binding():
            r=case_root('PUB_WRONG');r.mkdir();c=owner.offline_documents(r,'OFFLINE_TEST_ONLY_PUB')
            assert producer(r,c,selectedIndex=3)==20 and not (r/publisher.protocol.io.OBSERVATION).exists()
            with contextlib.redirect_stdout(io.StringIO()):code=publisher.main(['--root',str(r),'--input',str(r/'producer-input.json')])
            assert code==20 and not (r/publisher.protocol.io.DECISION).exists() and not (r/publisher.protocol.io.COMPLETION).exists()
        test('PUBLISHER_WRONG_BINDING_AND_OFFLINE_NOT_SOURCE',producer_binding)
    write(ev/'owner-tests.json',dict(status='PASS_PRELAUNCH_OFFLINE_OWNER_DELTA',caseCount=len(rows),cases=rows,allCallbacks='OFFLINE_TEST_ONLY',liveClaimsCreated=0,sourceCalls=0,ownTempRemoved=True))
    print(json.dumps(dict(status='PASS_PRELAUNCH_OFFLINE_OWNER_DELTA',cases=len(rows))))
if __name__=='__main__':main()
