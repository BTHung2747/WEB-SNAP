"""Sequential offline processes; 10s external watchdog independent of child event loop."""
import hashlib,importlib.metadata,inspect,json,os,pathlib,signal,subprocess,sys,time
OUT=pathlib.Path('/out');ROOT=pathlib.Path('/poc')
sys.excepthook=lambda *a:print('POC_SUPERVISOR_FAILURE',flush=True)
def inventory():
    return [{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(ROOT.rglob('*')) if p.is_file() and '__pycache__' not in p.parts]
def group_pids(group):
    result=[]
    for p in pathlib.Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            if os.getpgid(int(p.name))==group:result.append(int(p.name))
        except ProcessLookupError:pass
    return result
def main():
    import aiohappyeyeballs,requests,urllib3
    (OUT/'runtime-api.json').write_text(json.dumps({'python':sys.version.split()[0],
      'versions':{p:importlib.metadata.version(p) for p in ('aiohappyeyeballs','requests','urllib3','yt-dlp')},
      'publicAPI':str(inspect.signature(aiohappyeyeballs.start_connection)),
      'libraryImplSHA':hashlib.sha256(pathlib.Path('/poc/vendor/aiohappyeyeballs/impl.py').read_bytes()).hexdigest()},indent=2))
    core=pathlib.Path('/app/apps/media/src/tiktok')
    core_rows=[{'path':str(p.relative_to(core)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
               for p in sorted(core.rglob('*')) if p.is_file() and 'photo_lab' not in p.parts and '__pycache__' not in p.parts and 'node_modules' not in p.parts]
    (OUT/'core-runtime.json').write_text(json.dumps(core_rows,indent=2))
    before=inventory();(OUT/'runtime-source-before.json').write_text(json.dumps(before,indent=2))
    cases=['one','two-v4','many-v4','mixed','all-fail','near-success','double-success','stock-actual','stock-latency','candidate-latency',
           'cancel-dns','dns-deadline','cancel-connect','cancel-after-winner','small-budget','private-mixed','bad-host',
           'exception-identity','tls-success','tls-cert','tls-stall','eventloop-block']
    results=[];failed=False
    for name in cases:
        start=time.monotonic();deadline=start+10;p=subprocess.Popen([sys.executable,'/poc/test_poc.py',name,str(deadline)],
                  stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        killed=False;members=[]
        try:
            stdout,stderr=p.communicate(timeout=max(0,deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            killed=True;members=group_pids(p.pid);os.killpg(p.pid,signal.SIGKILL);stdout,stderr=p.communicate(timeout=1)
        # A successful child can still leave a daemon fixture grandchild; group owns all.
        left=group_pids(p.pid)
        if left:
            try:os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError:pass
        limit=time.monotonic()+.5
        while group_pids(p.pid) and time.monotonic()<limit:time.sleep(.01)
        left=group_pids(p.pid)
        expected_kill=name in ('eventloop-block','tls-stall','stock-actual')
        ok=(p.returncode==0 or killed and expected_kill) and not left
        result={'case':name,'status':'PASS' if ok else 'FAIL','actualExit':p.returncode,'signal':-p.returncode if p.returncode<0 else None,
                'watchdogSeconds':10,'elapsed':time.monotonic()-start,'watchdogKilled':killed,'groupMembersAtKill':len(members),
                'groupLeft':len(left),'stderrBytes':len(stderr),'stdoutCode':'FIXED_SUCCESS' if stdout.startswith(b'PASS ') else 'FIXED_FAILURE',
                'TLSDetail':'UNKNOWN' if killed else 'SEE_CASE_RECEIPT','sourceCalls':0}
        # Never retain exception text, traceback, commands, URLs or headers from subprocess.
        results.append(result);print(result['status']+' '+name,flush=True)
        if not ok:failed=True
    after=inventory();assert before==after
    (OUT/'runtime-source-after.json').write_text(json.dumps(after,indent=2))
    receipt={'status':'REJECT' if failed else 'PASS_CANDIDATE_OFFLINE','cases':results,'sourceCalls':0,
             'scheduling':{'delaySeconds':.25,'interleave':0,'batchAddresses':2,'setupSeconds':10,'reserveSeconds':1},
             'DNS':'Numeric latency fixture only; OS getaddrinfo cancellation is process containment, not coroutine cancellation',
             'hardDeadline':'Independent supervisor10s kills/reaps owned process group; OS scheduling tolerance measured, not strict zero jitter',
             'productionObserver':'UNKNOWN per-attempt terminal/TLS details/correlation; fixture public-loop events only'}
    (OUT/'result.json').write_text(json.dumps(receipt,indent=2));return 1 if failed else 0
if __name__=='__main__':sys.exit(main())
