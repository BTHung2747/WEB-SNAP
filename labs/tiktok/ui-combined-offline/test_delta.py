"""Only new combined schema/budget; Windows filesystem, no browser/network."""
import importlib.util,pathlib,tempfile,json,sys,time
p=pathlib.Path(__file__).with_name('handshake.py');spec=importlib.util.spec_from_file_location('h',p);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
out=pathlib.Path(sys.argv[1]);out.mkdir(exist_ok=False)
rows=[]
def case(name,fn):
    fn();rows.append(dict(case=name,status='PASS'))
def reject(fn):
    try:fn()
    except h.Rejected:return
    raise AssertionError('EXPECTED_REJECTION')
r=out/'valid';r.mkdir();c=h.initialize(r,'a'*32,total=480,clock=lambda:1_000_000_000)
case('combined_scope_target_480',lambda: h.contract(r))
case('reserve20_seal1',lambda: h.require(int(c['runDeadlineMonoNs'])-int(c['cleanupDeadlineMonoNs'])==1_000_000_000 and int(c['cleanupDeadlineMonoNs'])-int(c['observationDeadlineMonoNs'])==20_000_000_000,'RESERVE'))
o=dict(schema='wed-combined-browser-observation-v1',runID=c['runID'],deadlineMonoNs=c['observationDeadlineMonoNs'],origin=c['origin'],path='/',workflow=c['workflow'],fixtureID=c['fixtureID'],status='FAIL',tabCleanup='CLOSED',screenshot=dict(status='UNKNOWN',file=None,sha256=None))
case('combined_observation_valid',lambda:h.validate_observation(o,c))
case('reject_old_marker_schema',lambda:reject(lambda:h.validate_observation({**o,'schema':'wed-browser-observation-v1'},c)))
case('reject_wrong_fixture',lambda:reject(lambda:h.validate_observation({**o,'fixtureID':'2'*19},c)))
case('reject_old_reachability',lambda:reject(lambda:h.validate_observation({**o,'path':'/reachability'},c)))
x=out/'over';x.mkdir();case('reject_over480',lambda:reject(lambda:h.initialize(x,'b'*32,total=480.1)))
h.publish_observation(r,o);d=h.wait_decision(r,clock=lambda:2_000_000_000);z=h.complete(r,'CLOSED','FAIL',clock=lambda:3_000_000_000)
case('failed_observation_never_pass',lambda:h.require(d['status']=='REJECTED' and z['status']=='FAIL','FAIL_STATE'))
(out/'result.json').write_text(json.dumps(dict(status='PASS_FILESYSTEM_DELTA_ONLY',cases=rows,count=len(rows),sourceCalls=0)))
print(json.dumps(dict(status='PASS_FILESYSTEM_DELTA_ONLY',count=len(rows))))
