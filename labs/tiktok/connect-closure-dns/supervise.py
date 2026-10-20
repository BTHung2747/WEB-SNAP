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

def helpers(parent):
    result=[]
    for file in ([OUT/(ACTIVE_CASE+'-ownership-helper-owners.jsonl')] if (OUT/(ACTIVE_CASE+'-ownership-helper-owners.jsonl')).exists() else []):
        data=file.read_bytes()
        if len(data)>65536:raise RuntimeError('OWNER_FILE_CAP')
        for line in data.splitlines():
            row=json.loads(line)
            if row['parentPID']!=parent:continue
            pid=row['helperPID']
            try:
                stat=pathlib.Path('/proc',str(pid),'stat').read_text().split(')',1)[1].split()
                if stat[19]==row['startTicks'] and int(stat[1])==parent and os.getpgid(pid)==pid:result.append(pid)
            except (ProcessLookupError,FileNotFoundError):pass
    return result

def kill_helpers(parent):
    groups=helpers(parent)
    for group in groups:
        try:os.killpg(group,signal.SIGKILL)
        except ProcessLookupError:pass
    return groups
def main():
    import aiohappyeyeballs,requests,urllib3
    (OUT/'runtime-api.json').write_text(json.dumps({'python':sys.version.split()[0],
      'versions':{p:importlib.metadata.version(p) for p in ('aiohappyeyeballs','requests','urllib3','yt-dlp')},
      'publicAPI':str(inspect.signature(aiohappyeyeballs.start_connection)),
      'libraryImplSHA':hashlib.sha256(pathlib.Path('/vendor/aiohappyeyeballs/impl.py').read_bytes()).hexdigest()},indent=2))
    core=pathlib.Path('/app/apps/media/src/tiktok')
    core_rows=[{'path':str(p.relative_to(core)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
               for p in sorted(core.rglob('*')) if p.is_file() and 'photo_lab' not in p.parts and '__pycache__' not in p.parts and 'node_modules' not in p.parts]
    (OUT/'core-runtime.json').write_text(json.dumps(core_rows,indent=2))
    before=inventory();(OUT/'runtime-source-before.json').write_text(json.dumps(before,indent=2))
    vendor=pathlib.Path('/vendor')
    (OUT/'vendor-runtime.json').write_text(json.dumps([{'path':str(p.relative_to(vendor)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(vendor.rglob('*')) if p.is_file() and '__pycache__' not in p.parts],indent=2))
    cases=['one','two-v4','many-v4','mixed','all-fail','near-success','double-success','stock-actual','stock-latency','candidate-latency',
           'cancel-dns','dns-deadline','cancel-connect','cancel-after-winner','small-budget','private-mixed','bad-host',
           'exception-identity','tls-success','tls-close-early','tls-close-slow','tls-cert','tls-stall','eventloop-block',
           'dns-thread-success','dns-thread-error','dns-thread-cancel','dns-thread-deadline','dns-thread-crash',
           'dns-thread-oversize','dns-thread-answer-oversize','dns-thread-late-reply','dns-thread-localhost',
           'dns-thread-inheritance','dns-thread-inputcap','dns-thread-parent-block','closure-expired','socket-expired']
    if os.environ.get('POC_CASES')=='Smoke':cases=['tls-close-early','tls-close-slow','dns-thread-success','dns-thread-error','dns-thread-inheritance','dns-thread-oversize']
    results=[];failed=False
    for name in cases:
        global ACTIVE_CASE
        ACTIVE_CASE=name
        start=time.monotonic();deadline=start+10;p=subprocess.Popen([sys.executable,'/poc/test_poc.py',name,str(deadline)],
                  stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
        killed=False;members=[];helperGroups=[]
        try:
            stdout,stderr=p.communicate(timeout=max(0,deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            killed=True;members=group_pids(p.pid);helperGroups=kill_helpers(p.pid);os.killpg(p.pid,signal.SIGKILL);stdout,stderr=p.communicate(timeout=1)
        # A successful child can still leave a daemon fixture grandchild; group owns all.
        unexpectedHelpers=helpers(p.pid);helperGroups+=kill_helpers(p.pid)
        left=group_pids(p.pid)
        if left:
            try:os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError:pass
        limit=time.monotonic()+.5
        while (group_pids(p.pid) or any(group_pids(g) for g in helperGroups)) and time.monotonic()<limit:time.sleep(.01)
        left=group_pids(p.pid)
        expected_kill=name in ('eventloop-block','tls-stall','stock-actual','dns-thread-parent-block')
        helperLeft=sum(len(group_pids(g)) for g in set(helperGroups))
        ok=(p.returncode==0 or killed and expected_kill) and not left and not helperLeft and not unexpectedHelpers
        result={'case':name,'status':'PASS' if ok else 'FAIL','actualExit':p.returncode,'signal':-p.returncode if p.returncode<0 else None,
                'watchdogSeconds':10,'elapsed':time.monotonic()-start,'watchdogKilled':killed,'groupMembersAtKill':len(members),
                'groupLeft':len(left),'helperGroupsKilled':len(set(helperGroups)),'helperGroupsLeft':helperLeft,'unexpectedHelpers':len(unexpectedHelpers),
                'closure':'PROCESS_CONTAINMENT' if killed else 'SEE_OWNED_RECEIPT','stderrBytes':len(stderr),'stdoutCode':'FIXED_SUCCESS' if stdout.startswith(b'PASS ') else 'FIXED_FAILURE',
                'TLSDetail':'UNKNOWN' if killed else 'SEE_CASE_RECEIPT','sourceCalls':0}
        # Never retain exception text, traceback, commands, URLs or headers from subprocess.
        results.append(result);print(result['status']+' '+name,flush=True)
        if not ok:failed=True
    after=inventory();assert before==after
    (OUT/'runtime-source-after.json').write_text(json.dumps(after,indent=2))
    receipt={'status':'REJECT' if failed else 'PASS_CANDIDATE_OFFLINE','cases':results,'sourceCalls':0,
             'scheduling':{'delaySeconds':.25,'interleave':0,'batchAddresses':2,'setupSeconds':10,'reserveSeconds':1},
             'DNS':'Public subprocess IPC from threaded handler; numeric/localhost fixture; external OS DNS/D-state UNKNOWN',
             'hardDeadline':'Independent supervisor10s kills/reaps owned process group; OS scheduling tolerance measured, not strict zero jitter',
             'productionObserver':'UNKNOWN per-attempt terminal/TLS details/correlation; fixture public-loop events only'}
    (OUT/'result.json').write_text(json.dumps(receipt,indent=2));return 1 if failed else 0
if __name__=='__main__':sys.exit(main())
