"""Dedicated owner flow, exercised only through explicitly offline callbacks.

Live entry stays closed: human instruction/claim verification and environment
proofs cannot be manufactured from target selection or self-declared files.
"""
import datetime,hashlib,importlib.util,json,pathlib,re,time
_spec=importlib.util.spec_from_file_location('owner_publisher',pathlib.Path(__file__).with_name('publisher.py'))
_publisher=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(_publisher)
protocol=_publisher.protocol
class NotReady(ValueError):pass
def require(ok,code):
    if not ok:raise NotReady(code)
def deny_live(context,launch_callback):
    # No issuer of a live capability in this offline successor.
    raise NotReady('PRELAUNCH_HOLD_NEW_INSTRUCTION_AND_ENVIRONMENT_REQUIRED')
def checked_plan(plan):
    require(plan['schema']=='wed-ui-source-prelaunch-plan-v1' and plan['staticStatus']=='PASS_STATIC_PLAN_ONLY','PLAN_SCHEMA')
    require(plan['sourceGate'] is False and plan['launchReady'] is False and plan['liveEngineEnabled'] is False,'LIVE_GATE')
    require(len(plan['mounts'])==123 and len(plan['buildPins'])==3,'MOUNT_COVERAGE')
    require(sum(r['memoryMiB'] for r in plan['resources']['roles'])==928,'MEMORY')
    require(bool(plan['requiredNotRun']),'UNMEASURED_ENVIRONMENT_MUST_REMAIN_UNKNOWN')
    root=pathlib.Path.cwd().resolve()
    for pin in plan['pins']:
        p=(root/pin['path']).resolve();require(p.is_relative_to(root) and p.is_file(),'PIN_PATH')
        require(hashlib.sha256(p.read_bytes()).hexdigest()==pin['sha256'],'PIN_DRIFT')
    return plan
def schedule(total=320,browser_minimum=10):
    require(type(total) is int and 0<total<=320,'LOWER_WATCHDOG')
    require(type(browser_minimum) is int and browser_minimum>0,'BROWSER_BUDGET')
    require(total>=60+30+180+20+1+browser_minimum,'INSUFFICIENT_BUDGET')
    return total
def offline_documents(root,run_id,total=320):
    require(re.fullmatch('OFFLINE_TEST_ONLY_[A-Z0-9_]{1,40}',run_id) is not None,'OFFLINE_ID')
    budget=protocol.io.read_raw(pathlib.Path(__file__).resolve().parent.parent/'ui-source-glue'/'budget-policy.json')
    now=time.monotonic_ns();end=now+total*1_000_000_000
    c=dict(schema='wed-ui-photo-source-contract-v1',mode='OFFLINE_TEST_ONLY',runID=run_id,origin=protocol.io.ORIGIN,path='/',approvedURL='https://www.tiktok.com/@offline_vector/photo/7000000000000000007',expectedPostID='7000000000000000007',selectedIndex=2,decisionSHA256='',budgetSHA256=protocol.io.digest(budget),startMonoNs=str(now),observationDeadlineMonoNs=str(end-21_000_000_000),cleanupDeadlineMonoNs=str(end-1_000_000_000),runDeadlineMonoNs=str(end))
    utc_end=datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(seconds=total)
    decision=dict(schema='wed-ui-photo-source-decision-v1',mode='OFFLINE_TEST_ONLY',state='OFFLINE_TEST_ONLY',runID=run_id,approvedURL=c['approvedURL'],expectedPostID=c['expectedPostID'],selectedIndex=2,budgetSHA256=c['budgetSHA256'],expiresAt=utc_end.isoformat())
    raw=json.dumps(decision,separators=(',',':')).encode();c['decisionSHA256']=protocol.io.digest(raw)
    for name,data in [('source-budget.json',budget),('source-decision.json',raw)]:
        with (root/name).open('xb') as f:f.write(data)
    protocol.io.publish_atomic(root,protocol.io.CONTRACT,c)
    return c
STEPS=('cache_import_preflight','allocate_owned_resources','guard_owned_resources','start_private_services','verify_backend_readiness','connect_owned_egress','start_gateway_host_ready','browser_handoff','wait_native_runtime','final_runtime_gate')
def fake_response(value):
    require(type(value) is dict and value.get('mode')=='OFFLINE_TEST_ONLY','FAKE_CALLBACK_REQUIRED')
    require(type(value.get('simulatedExit')) is int and value['simulatedExit']==0,'SIMULATED_CHILD_NONZERO')
    return value
def simulate(root,plan,run_id,ops,*,browser_minimum=10):
    checked_plan(plan);schedule(browser_minimum=browser_minimum)
    require(getattr(ops,'offline_test_only',False) is True,'FAKE_ENGINE_REQUIRED')
    require(re.fullmatch('OFFLINE_TEST_ONLY_[A-Z0-9_]{1,40}',run_id) is not None,'OFFLINE_ID')
    root=pathlib.Path(root).resolve();require(root.name.startswith('OFFLINE_TEST_ONLY_'),'OFFLINE_NAMESPACE')
    require(root.is_relative_to((pathlib.Path.cwd()/'docs/evidence').resolve()),'EVIDENCE_ROOT')
    root.mkdir() # Exclusive namespace once, like the accepted source-once owner.
    with (root/'simulation-once.json').open('x',encoding='utf-8') as f:json.dump(dict(mode='OFFLINE_TEST_ONLY',runID=run_id,notSourceClaim=True),f)
    c=offline_documents(root,run_id);resources=[];steps=[];success=False;cleanup_ok=True;fault='';decision=None
    try:
        for step in STEPS:
            require(time.monotonic_ns()<protocol.io.ns(c['observationDeadlineMonoNs']),'OWNER_DEADLINE')
            raw=ops.step(step,root,c,plan)
            # Record owned IDs even when a simulated child returns packet PASS
            # with a nonzero exit; never remove a foreign resource.
            for r in raw.get('resources',[]) if type(raw) is dict else []:
                require(type(r) is dict and r.get('owner')==run_id and r.get('kind') in ('container','network') and type(r.get('id')) is str and r['id'].startswith('OFFLINE_TEST_ONLY_'),'RESOURCE_OWNER')
                require(r['id'] not in [v['id'] for v in resources] and len(resources)<16,'RESOURCE_REGISTRY')
                resources.append(r)
            value=fake_response(raw);steps.append(step)
            if step=='browser_handoff':
                decision=protocol.wait_decision(root,role='owner',offline=True)
                require(decision['status']=='ACCEPTED','BROWSER_NOT_ACCEPTED')
                with (root/'browser-accepted').open('x') as f:f.write('OFFLINE_TEST_ONLY')
            if step=='wait_native_runtime':require(value.get('exits')==dict(app=0,gateway=0,proxy=0) and value.get('signals')==dict(app=None,gateway=None,proxy=None),'NATIVE_EXIT_PROOF')
            if step=='final_runtime_gate':require(value.get('proof')=='SIMULATED_RUNTIME_GATE_ONLY','FINAL_GATE_PROOF')
        success=True
    except Exception:fault='STOPPED_OFFLINE_SIMULATION'
    finally:
        # Mirrors accepted owner inspect-label-before-remove and absent query.
        cleanup_end=min(time.monotonic()+20,protocol.io.ns(c['cleanupDeadlineMonoNs'])/1e9)
        ordered=[r for kind in ('container','network') for r in reversed(resources) if r['kind']==kind]
        for resource in ordered:
            try:
                require(time.monotonic()<cleanup_end,'CLEANUP_DEADLINE')
                seen=fake_response(ops.inspect(resource))
                require(seen.get('owner')==run_id and seen.get('id')==resource['id'],'CLEANUP_OWNER')
                fake_response(ops.remove(resource))
            except Exception:cleanup_ok=False
        try:
            remaining=fake_response(ops.remaining(run_id));require(remaining.get('ids')==[],'OWN_RESOURCES_REMAIN')
        except Exception:cleanup_ok=False
        if not (root/protocol.io.DECISION).exists():
            protocol.io.publish_atomic(root,protocol.io.DECISION,dict(schema='wed-ui-photo-source-browser-decision-v1',**protocol.binding(c),decisionMonoNs=str(time.monotonic_ns()),status='NOT_OBSERVED',code='DEADLINE',observationSHA256=None))
        completion=protocol.complete(root,'CLOSED' if cleanup_ok else 'UNKNOWN','PASS' if success else 'FAIL',role='owner',offline=True)
        with (root/'simulation-consumed.json').open('x',encoding='utf-8') as f:json.dump(dict(mode='OFFLINE_TEST_ONLY',runID=run_id,notSourceClaim=True),f)
    result=dict(status='PASS_OWNER_SIMULATION_ONLY' if completion['status']=='PASS_OFFLINE_HANDSHAKE' else 'FAIL_OWNER_SIMULATION',mode='OFFLINE_TEST_ONLY',steps=steps,simulationResources=len(resources),simulationCleanupOK=cleanup_ok,fault=fault,sourceCalls=0,liveClaimsCreated=0,completion=completion['status'])
    with (root/'simulation-result.json').open('x',encoding='utf-8') as f:json.dump(result,f)
    return result
if __name__=='__main__':raise SystemExit(78)
