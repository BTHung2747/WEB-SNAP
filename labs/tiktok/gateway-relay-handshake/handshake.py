"""Lab filesystem handshake. Producer never writes runner decision/completion."""
import argparse,datetime,hashlib,json,math,os,pathlib,re,stat,sys,tempfile,time
CAP=16384
CONTRACT='browser-contract.json';OBSERVATION='browser-observation.json'
DECISION='browser-decision.json';CLEANUP='runner-cleanup.json';COMPLETION='completion.json'
ORIGIN='http://127.0.0.1:5206';TARGET='/reachability'
class Rejected(ValueError):pass
def require(ok,code):
    if not ok:raise Rejected(code)
def pairs(rows):
    result={}
    for key,value in rows:
        require(key not in result,'DUPLICATE_KEY');result[key]=value
    return result
def read_raw(path,limit=CAP):
    require(not path.is_symlink(),'SYMLINK')
    with path.open('rb') as file:
        before=os.fstat(file.fileno());require(stat.S_ISREG(before.st_mode) and before.st_size<=limit,'BYTE_CAP')
        data=file.read(limit+1);after=os.fstat(file.fileno())
        require(len(data)<=limit and before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns,'CHANGED_OR_CAP')
    return data
def parse(data):
    try:return json.loads(data,object_pairs_hook=pairs,parse_constant=lambda _:(_ for _ in ()).throw(Rejected('NONFINITE')))
    except (UnicodeError,json.JSONDecodeError,RecursionError):raise Rejected('MALFORMED') from None
def load(path):return parse(read_raw(path))
def digest(data):return hashlib.sha256(data).hexdigest()
def publish_atomic(root,name,value):
    """Windows-only same-directory rename; MoveFileExW flags=0, never replace."""
    require(os.name=='nt','WINDOWS_ATOMIC_REQUIRED')
    require(name in {CONTRACT,OBSERVATION,DECISION,CLEANUP,COMPLETION},'FILE_ROLE')
    data=json.dumps(value,separators=(',',':'),allow_nan=False).encode('utf-8');require(len(data)<=CAP,'BYTE_CAP')
    fd,temp=tempfile.mkstemp(prefix='.publish-',suffix='.tmp',dir=root)
    try:
        with os.fdopen(fd,'wb') as file:file.write(data);file.flush();os.fsync(file.fileno())
        os.rename(temp,root/name) # Windows fails if destination exists; no os.replace.
    finally:
        try:os.unlink(temp) # Only this call's own mkstemp; rename may have consumed it.
        except FileNotFoundError:pass
    return value
def ns(value):
    require(type(value) is str and re.fullmatch('[1-9][0-9]{0,19}',value) is not None,'DEADLINE_TYPE')
    return int(value)
def contract(root):
    c=load(root/CONTRACT)
    require(type(c) is dict and set(c)=={'schema','runID','origin','path','marker','startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs','scope'},'CONTRACT_SCHEMA')
    require(c['schema']=='wed-browser-contract-v1' and c['scope']=='MARKER_SOURCE_OFF','CONTRACT_SCHEMA')
    require(type(c['runID']) is str and re.fullmatch('[a-f0-9]{32}',c['runID']) is not None,'RUN_ID')
    require(c['origin']==ORIGIN and c['path']==TARGET and c['marker']=='WED_SNAP_REACHABILITY_'+c['runID'],'WRONG_TARGET')
    a,b,d,e=(ns(c[k]) for k in ['startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs'])
    require(a<b<d<e and e-a<=150_000_000_000,'CONTRACT_BUDGET')
    return c
def initialize(root,run_id,total=150,cleanup_reserve=20,seal_reserve=1,*,clock=time.monotonic_ns):
    require(root.is_dir() and not root.is_symlink(),'ROOT')
    require(type(run_id) is str and re.fullmatch('[a-f0-9]{32}',run_id) is not None,'RUN_ID')
    for x in [total,cleanup_reserve,seal_reserve]:require(type(x) in (int,float) and math.isfinite(x) and x>0,'BUDGET_TYPE')
    require(total<=150 and cleanup_reserve+seal_reserve<total,'CONTRACT_BUDGET')
    begin=clock();end=begin+int(total*1e9);cleanup=end-int(seal_reserve*1e9);cutoff=cleanup-int(cleanup_reserve*1e9)
    return publish_atomic(root,CONTRACT,dict(schema='wed-browser-contract-v1',runID=run_id,origin=ORIGIN,path=TARGET,marker='WED_SNAP_REACHABILITY_'+run_id,startMonoNs=str(begin),observationDeadlineMonoNs=str(cutoff),cleanupDeadlineMonoNs=str(cleanup),runDeadlineMonoNs=str(end),scope='MARKER_SOURCE_OFF'))
def validate_observation(o,c):
    require(type(o) is dict and set(o)=={'schema','runID','deadlineMonoNs','origin','path','marker','status','tabCleanup','screenshot'},'OBSERVATION_SCHEMA')
    require(o['schema']=='wed-browser-observation-v1','OBSERVATION_SCHEMA')
    require(type(o['runID']) is str and o['runID']==c['runID'],'WRONG_RUN')
    require(type(o['deadlineMonoNs']) is str and o['deadlineMonoNs']==c['observationDeadlineMonoNs'],'DEADLINE_TOKEN')
    require(o['origin']==c['origin'] and o['path']==c['path'] and o['marker']==c['marker'],'WRONG_TARGET')
    require(type(o['status']) is str and o['status'] in {'PASS','FAIL'},'STATUS_TYPE')
    require(type(o['tabCleanup']) is str and o['tabCleanup'] in {'CLOSED','UNKNOWN'},'CLEANUP_TYPE')
    s=o['screenshot'];require(type(s) is dict and set(s)=={'status','file','sha256'},'SCREENSHOT_SCHEMA')
    require(type(s['status']) is str and s['status'] in {'SAVED','UNKNOWN'},'SCREENSHOT_SCHEMA')
    if s['status']=='SAVED':require(s['file']=='browser.jpg' and type(s['sha256']) is str and re.fullmatch('[a-f0-9]{64}',s['sha256']) is not None,'SCREENSHOT_SCHEMA')
    else:require(s['file'] is None and s['sha256'] is None,'SCREENSHOT_SCHEMA')
    return o
def publish_observation(root,o):
    validate_observation(o,contract(root))
    # Syntactically valid late observations are retained, never a verdict writer.
    return publish_atomic(root,OBSERVATION,o)
def wait_decision(root,*,clock=time.monotonic_ns,pause=time.sleep):
    c=contract(root);cutoff=ns(c['observationDeadlineMonoNs']);sha=None;status='NOT_OBSERVED';code='DEADLINE';o=None
    while True:
        now=clock()
        require(now>=ns(c['startMonoNs']),'CLOCK_RESET')
        if (root/OBSERVATION).exists():
            try:
                raw=read_raw(root/OBSERVATION);sha=digest(raw);o=validate_observation(parse(raw),c)
                if clock()>=cutoff:status,code='LATE','DEADLINE'
                elif o['status']!='PASS':status,code='REJECTED','OBSERVED_FAIL'
                elif o['tabCleanup']!='CLOSED':status,code='REJECTED','CLEANUP_UNKNOWN'
                elif o['screenshot']['status']!='SAVED':status,code='REJECTED','SCREENSHOT_UNKNOWN'
                else:
                    require(digest(read_raw(root/'browser.jpg',2*1024*1024))==o['screenshot']['sha256'],'SCREENSHOT_HASH')
                    status,code=('ACCEPTED','OK') if clock()<cutoff else ('LATE','DEADLINE')
            except Rejected as exc:status,code='REJECTED',exc.args[0]
            except FileNotFoundError:status,code='REJECTED','SCREENSHOT_MISSING'
            break
        if now>=cutoff:break
        pause(min(.02,(cutoff-now)/1e9))
    decision=dict(schema='wed-browser-decision-v1',runID=c['runID'],deadlineMonoNs=c['observationDeadlineMonoNs'],decisionMonoNs=str(clock()),status=status,code=code,observationSHA256=sha)
    return publish_atomic(root,DECISION,decision)
def complete(root,cleanup_state,execution_state,*,clock=time.monotonic_ns):
    c=contract(root);require(cleanup_state in {'CLOSED','UNKNOWN'} and execution_state in {'PASS','FAIL'},'FINAL_STATE')
    if not (root/DECISION).exists():
        publish_atomic(root,DECISION,dict(schema='wed-browser-decision-v1',runID=c['runID'],deadlineMonoNs=c['observationDeadlineMonoNs'],decisionMonoNs=str(clock()),status='NOT_OBSERVED',code='ABORTED_BEFORE_WAIT',observationSHA256=None))
    decision_raw=read_raw(root/DECISION);d=parse(decision_raw)
    require(type(d) is dict and set(d)=={'schema','runID','deadlineMonoNs','decisionMonoNs','status','code','observationSHA256'} and d['schema']=='wed-browser-decision-v1' and d['runID']==c['runID'] and d['deadlineMonoNs']==c['observationDeadlineMonoNs'],'DECISION_SCHEMA')
    require(type(d['status']) is str and d['status'] in {'ACCEPTED','REJECTED','LATE','NOT_OBSERVED'} and type(d['code']) is str and re.fullmatch('[A-Z_]{1,40}',d['code']) is not None,'DECISION_SCHEMA')
    cleanup_at=clock();require(cleanup_at>=ns(c['startMonoNs']),'CLOCK_RESET')
    cleanup=dict(schema='wed-runner-cleanup-v1',runID=c['runID'],closedAtMonoNs=str(cleanup_at),resources=cleanup_state,execution=execution_state)
    publish_atomic(root,CLEANUP,cleanup)
    status,code='FAIL',d['code']
    if d['status']=='ACCEPTED':
        try:
            require(ns(d['decisionMonoNs'])<ns(c['observationDeadlineMonoNs']),'DECISION_LATE')
            raw=read_raw(root/OBSERVATION);require(digest(raw)==d['observationSHA256'],'OBSERVATION_CHANGED');o=validate_observation(parse(raw),c)
            require(o['status']=='PASS' and o['tabCleanup']=='CLOSED','CLEANUP_UNKNOWN')
            require(o['screenshot']['status']=='SAVED' and digest(read_raw(root/'browser.jpg',2*1024*1024))==o['screenshot']['sha256'],'SCREENSHOT_HASH')
            if cleanup_state!='CLOSED':code='CLEANUP_UNKNOWN'
            elif execution_state!='PASS':code='EXECUTION_FAILED'
            elif cleanup_at>=ns(c['cleanupDeadlineMonoNs']):code='CLEANUP_DEADLINE'
            else:status,code='PASS','OK'
        except Rejected as exc:code=exc.args[0]
        except FileNotFoundError:code='ARTIFACT_MISSING'
    if clock()>=ns(c['runDeadlineMonoNs']):status,code='FAIL','RUN_DEADLINE'
    result=dict(schema='wed-handshake-completion-v1',runID=c['runID'],status=status,code=code,decisionSHA256=digest(decision_raw),cleanupSHA256=digest(read_raw(root/CLEANUP)),completedMonoNs=str(clock()),sourceCalls=0)
    return publish_atomic(root,COMPLETION,result)
def main():
    require(sys.version_info[:3]==(3,12,14),'PYTHON_VERSION')
    p=argparse.ArgumentParser();p.add_argument('command',choices=['init','publish','budget','wait','complete']);p.add_argument('--root',required=True);p.add_argument('--run-id');p.add_argument('--deadline-utc');p.add_argument('--input');p.add_argument('--cleanup-state',choices=['CLOSED','UNKNOWN']);p.add_argument('--execution-state',choices=['PASS','FAIL'])
    a=p.parse_args();root=pathlib.Path(a.root).resolve();require(root.is_dir(),'ROOT')
    if a.command=='init':
        limit=datetime.datetime.fromisoformat(a.deadline_utc);require(limit.tzinfo is not None,'DEADLINE_TYPE');left=(limit-datetime.datetime.now(datetime.timezone.utc)).total_seconds();r=initialize(root,a.run_id,total=left)
    elif a.command=='publish':r=publish_observation(root,load(pathlib.Path(a.input)))
    elif a.command=='budget':
        c=contract(root);left=ns(c['observationDeadlineMonoNs'])-time.monotonic_ns();print(json.dumps(dict(command='budget',status='OK',waitMs=max(1000,min(150000,math.ceil(left/1e6)+1000)))));return 0
    elif a.command=='wait':r=wait_decision(root)
    else:r=complete(root,a.cleanup_state,a.execution_state)
    print(json.dumps(dict(command=a.command,status=r.get('status','PUBLISHED'),code=r.get('code','OK'))))
    return 21 if a.command=='wait' and r['status']!='ACCEPTED' else 22 if a.command=='complete' and r['status']!='PASS' else 0
if __name__=='__main__':
    try:exit_code=main()
    except FileExistsError:print('{"status":"FAIL","code":"ALREADY_PUBLISHED"}');exit_code=23
    except Rejected as exc:print(json.dumps(dict(status='FAIL',code=exc.args[0])));exit_code=20
    except (OSError,ValueError,TypeError):print('{"status":"FAIL","code":"FILESYSTEM_OR_SCHEMA"}');exit_code=20
    sys.exit(exit_code)
