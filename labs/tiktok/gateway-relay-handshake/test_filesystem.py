"""SIMULATED / FILESYSTEM_ONLY; no Docker, browser, socket or source calls."""
import argparse,concurrent.futures,copy,hashlib,importlib.util,json,pathlib,subprocess,sys,threading,time
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('handshake',HERE/'handshake.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
class Clock:
    def __init__(self):self.value=1_000_000_000
    def __call__(self):return self.value
    def pause(self,seconds):self.value+=max(1,int(seconds*1e9))
    def expire(self,c):self.value=int(c['observationDeadlineMonoNs'])
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def valid(root,c):
    # Deliberately not visual evidence: only a file/hash reference fixture.
    (root/'browser.jpg').write_bytes(b'SIMULATED_SCREENSHOT_BYTES_NOT_AN_IMAGE')
    return dict(schema='wed-browser-observation-v1',runID=c['runID'],deadlineMonoNs=c['observationDeadlineMonoNs'],origin=c['origin'],path=c['path'],marker=c['marker'],status='PASS',tabCleanup='CLOSED',screenshot=dict(status='SAVED',file='browser.jpg',sha256=sha(root/'browser.jpg')))
def run(evidence,powershell):
    cases=evidence/'cases';cases.mkdir();rows=[];index=0
    def case(name,real=False,total=10,cleanup=2,seal=1):
        nonlocal index
        index+=1;root=cases/name;root.mkdir();clock=time.monotonic_ns if real else Clock()
        with (evidence/'case-events.jsonl').open('a') as file:file.write(json.dumps(dict(event='BEGIN',case=name,scope='SIMULATED_FILESYSTEM_ONLY'))+'\n')
        c=h.initialize(root,format(index,'032x'),total,cleanup,seal,clock=clock)
        return root,clock,c,valid(root,c)
    def record(name,**facts):
        row=dict(case=name,result='PASS',scope='SIMULATED_FILESYSTEM_ONLY',**facts);rows.append(row)
        with (evidence/'case-events.jsonl').open('a') as file:file.write(json.dumps(dict(event='END',**row))+'\n')
    def finish(root,clock,resources='CLOSED'):
        d=h.wait_decision(root,clock=clock,pause=clock.pause);r=h.complete(root,resources,'PASS',clock=clock);return d,r
    root,clock,c,o=case('timely');h.publish_observation(root,o);d,r=finish(root,clock);assert d['status']=='ACCEPTED' and r['status']=='PASS';record('timely',decision='ACCEPTED',completion='PASS')
    root,clock,c,o=case('late-after-completion');clock.expire(c);d,r=finish(root,clock);before={p:sha(root/p) for p in [h.DECISION,h.COMPLETION]};h.publish_observation(root,o)
    assert d['status']=='NOT_OBSERVED' and r['status']=='FAIL' and all(sha(root/p)==v for p,v in before.items())
    assert (root/h.OBSERVATION).exists() and (root/h.DECISION).exists() and (root/h.COMPLETION).exists();record('late-after-completion',decision='NOT_OBSERVED',completion='FAIL',allThreeRawKept=True,verdictUnchanged=True)
    root,clock,c,o=case('already-late');h.publish_observation(root,o);clock.expire(c);d,r=finish(root,clock);assert d['status']=='LATE' and r['status']=='FAIL';record('already-late',decision='LATE')
    root,clock,c,o=case('duplicate-producer');h.publish_observation(root,o);before=sha(root/h.OBSERVATION)
    try:h.publish_observation(root,{**o,'status':'FAIL'});raise AssertionError('OVERWRITE')
    except FileExistsError:pass
    assert sha(root/h.OBSERVATION)==before and not list(root.glob('.publish-*.tmp'));record('duplicate-producer',originalHashKept=True,temporaryFilesLeft=0)
    root,clock,c,o=case('concurrent-publish');barrier=threading.Barrier(2)
    def producer(value):
        barrier.wait()
        try:h.publish_observation(root,value);return 'PUBLISHED'
        except FileExistsError:return 'ALREADY_EXISTS'
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:outcomes=list(pool.map(producer,[o,{**o,'status':'FAIL'}]))
    assert sorted(outcomes)==['ALREADY_EXISTS','PUBLISHED'];assert h.load(root/h.OBSERVATION) in [o,{**o,'status':'FAIL'}];assert not list(root.glob('.publish-*.tmp'));record('concurrent-publish',winners=1,rejectedWriters=1,completeJSON=True)
    root,clock,c,o=case('partial-temp');(root/'producer.partial.tmp').write_bytes(b'{"schema":');clock.expire(c);d,r=finish(root,clock);assert d['status']=='NOT_OBSERVED' and r['status']=='FAIL' and (root/'producer.partial.tmp').read_bytes()==b'{"schema":';record('partial-temp',ignored=True,partialRawKept=True)
    bad_rows=[('partial-final',b'{"schema":','MALFORMED'),('malformed',b'not-json','MALFORMED'),('duplicate-key',b'{"schema":1,"schema":2}','DUPLICATE_KEY'),('byte-cap',b'x'*(h.CAP+1),'BYTE_CAP')]
    for name,data,code in bad_rows:
        root,clock,c,o=case(name);(root/h.OBSERVATION).write_bytes(data);before=sha(root/h.OBSERVATION);d,r=finish(root,clock);assert d['status']=='REJECTED' and d['code']==code and r['status']=='FAIL' and sha(root/h.OBSERVATION)==before;record(name,code=code,rawUnchanged=True)
    changes=[('wrong-run',lambda o:o.update(runID='f'*32),'WRONG_RUN'),('wrong-deadline',lambda o:o.update(deadlineMonoNs=123),'DEADLINE_TOKEN'),('wrong-origin',lambda o:o.update(origin='http://127.0.0.1:9999'),'WRONG_TARGET'),('wrong-type',lambda o:o.update(status=True),'STATUS_TYPE'),('cleanup-unknown',lambda o:o.update(tabCleanup='UNKNOWN'),'CLEANUP_UNKNOWN'),('screenshot-unknown',lambda o:o.update(screenshot=dict(status='UNKNOWN',file=None,sha256=None)),'SCREENSHOT_UNKNOWN')]
    for name,change,code in changes:
        root,clock,c,o=case(name);change(o);h.publish_atomic(root,h.OBSERVATION,o);before=sha(root/h.OBSERVATION);d,r=finish(root,clock);assert d['status']=='REJECTED' and d['code']==code and r['status']=='FAIL' and sha(root/h.OBSERVATION)==before;record(name,code=code,rawUnchanged=True)
    root,clock,c,o=case('resource-cleanup-unknown');h.publish_observation(root,o);d,r=finish(root,clock,'UNKNOWN');assert d['status']=='ACCEPTED' and r['status']=='FAIL' and r['code']=='CLEANUP_UNKNOWN';record('resource-cleanup-unknown',completion='FAIL')
    root,clock,c,o=case('completion-immutable');h.publish_observation(root,o);finish(root,clock);before={p:sha(root/p) for p in [h.CLEANUP,h.COMPLETION]}
    try:h.complete(root,'UNKNOWN','FAIL',clock=clock);raise AssertionError('COMPLETION_OVERWRITE')
    except FileExistsError:pass
    assert all(sha(root/p)==v for p,v in before.items());record('completion-immutable',originalHashesKept=True)
    root,clock,c,o=case('cleanup-deadline');h.publish_observation(root,o);h.wait_decision(root,clock=clock,pause=clock.pause);clock.value=int(c['cleanupDeadlineMonoNs']);r=h.complete(root,'CLOSED','PASS',clock=clock);assert r['status']=='FAIL' and r['code']=='CLEANUP_DEADLINE';record('cleanup-deadline',completion='FAIL')
    root,clock,c,o=case('observation-changed');h.publish_observation(root,o);h.wait_decision(root,clock=clock,pause=clock.pause);(root/h.OBSERVATION).write_bytes(b'{}');r=h.complete(root,'CLOSED','PASS',clock=clock);assert r['status']=='FAIL' and r['code']=='OBSERVATION_CHANGED';record('observation-changed',completion='FAIL')
    # These subprocesses invoke the actual successor runner's shared wait/finalize
    # functions; -FilesystemOnly exits before every Docker/network branch.
    for name,late,unknown in [('runner-timely',False,False),('runner-late',True,False),('runner-cleanup-unknown',False,True)]:
        root,clock,c,o=case(name,real=True,total=5 if late else 10,cleanup=2,seal=1)
        if not late:h.publish_observation(root,o)
        argv=[powershell,'-NoProfile','-File',str(HERE/'run.ps1'),'-FilesystemOnly','-CaseDirectory',str(root),'-PythonPath',sys.executable,'-SimulatedCleanup','UNKNOWN' if unknown else 'CLOSED']
        begin=time.monotonic();p=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=20)
        (root/'runner-process.json').write_text(json.dumps(dict(scope='SIMULATED_FILESYSTEM_ONLY',command=argv,actualExit=p.returncode,elapsedSeconds=time.monotonic()-begin,stdoutLabel=p.stdout.decode('utf-8',errors='replace').strip() if p.stdout.strip()==b'SIMULATED_FILESYSTEM_ONLY' else 'NOT_EXPECTED_LABEL',stderrPresent=bool(p.stderr))))
        result=h.load(root/h.COMPLETION);assert p.returncode==(22 if late or unknown else 0),(name,p.returncode);assert result['status']==('FAIL' if late or unknown else 'PASS')
        before=sha(root/h.COMPLETION)
        if late:h.publish_observation(root,o);assert sha(root/h.COMPLETION)==before and h.load(root/h.DECISION)['status']=='NOT_OBSERVED'
        record(name,actualRunnerExit=p.returncode,completion=result['status'],lateRawKept=late)
    assert not list(cases.rglob('.publish-*.tmp'))
    result=dict(status='PASS_SIMULATED_FILESYSTEM_ONLY',python=sys.version.split()[0],os=sys.platform,cases=rows,caseCount=len(rows),ownedAtomicTempsLeft=0,partialFixtureIntentionallyKept=True,networkCalls=0,containersCreated=0,browserCalls=0,sourceCalls=0)
    h.publish_atomic(evidence,h.COMPLETION,result)
    print(json.dumps(dict(status=result['status'],caseCount=len(rows),networkCalls=0,containersCreated=0,browserCalls=0)))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--evidence',required=True);parser.add_argument('--powershell',required=True);args=parser.parse_args()
    try:run(pathlib.Path(args.evidence).resolve(),args.powershell)
    except BaseException:
        # Keep all case raw; no messages/tracebacks or historical result repair.
        (pathlib.Path(args.evidence)/'test-failure.json').write_text(json.dumps(dict(status='FAIL_FILESYSTEM_TEST',scope='SIMULATED_FILESYSTEM_ONLY')))
        print('{"status":"FAIL_FILESYSTEM_TEST"}');sys.exit(1)
