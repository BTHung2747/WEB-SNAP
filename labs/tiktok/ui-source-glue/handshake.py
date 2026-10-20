"""Source schema successor; atomic I/O is delegated to the accepted helper.

No initializer, grant/claim issuer or launcher. Offline vectors require explicit
offline=True and cannot pass the source entry gate.
"""
import datetime,importlib.util,json,pathlib,re,time
_path=pathlib.Path(__file__).resolve().parent.parent/'ui-combined-offline'/'handshake.py'
_spec=importlib.util.spec_from_file_location('accepted_browser_io',_path)
io=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(io)
require=io.require;Rejected=io.Rejected
BIND=('mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs')
FIELDS={'schema','mode','runID','origin','path','approvedURL','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs'}
def binding(c):return {k:c[k] for k in BIND}
def contract(root,*,offline=False,clock=time.monotonic_ns,check_owner_clock=True):
    c=io.load(root/io.CONTRACT)
    require(type(c) is dict and set(c)==FIELDS and c['schema']=='wed-ui-photo-source-contract-v1','CONTRACT_SCHEMA')
    require(c['mode']==('OFFLINE_TEST_ONLY' if offline else 'UI_SINGLE_PHOTO_SOURCE'),'MODE')
    pattern=r'OFFLINE_TEST_ONLY_[A-Z0-9_]{1,40}' if offline else r'[a-f0-9]{32}'
    require(type(c['runID']) is str and re.fullmatch(pattern,c['runID']) is not None,'RUN_ID')
    require(c['origin']==io.ORIGIN and c['path']=='/','WRONG_ORIGIN')
    require(type(c['expectedPostID']) is str and re.fullmatch('[0-9]{15,22}',c['expectedPostID']) is not None,'POST_ID')
    require(type(c['selectedIndex']) is int and 1<=c['selectedIndex']<=50,'INDEX')
    require(type(c['approvedURL']) is str and len(c['approvedURL'])<=512,'URL_TYPE')
    for k in ('decisionSHA256','budgetSHA256'):require(type(c[k]) is str and re.fullmatch('[a-f0-9]{64}',c[k]) is not None,'HASH_TYPE')
    a,b,d,e=(io.ns(c[k]) for k in ('startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs'))
    require((not check_owner_clock or a<=clock()<e) and a<b<d<e and e-a<=480_000_000_000 and d-b>=20_000_000_000 and e-d>=1_000_000_000,'CONTRACT_BUDGET')
    # Binding is checked against exact owner documents, never a fixture scope.
    raw=io.read_raw(root/'source-decision.json');require(io.digest(raw)==c['decisionSHA256'],'DECISION_HASH')
    budget=io.read_raw(root/'source-budget.json');require(io.digest(budget)==c['budgetSHA256'],'BUDGET_HASH')
    expected=io.parse(io.read_raw(pathlib.Path(__file__).resolve().parent/'budget-policy.json'))
    actual=io.parse(budget)
    require(type(actual) is dict and set(actual)==set(expected) and all(type(actual[k]) is int and actual[k]==expected[k] for k in expected),'BUDGET_POLICY')
    d=io.parse(raw)
    require(type(d) is dict and set(d)=={'schema','mode','state','runID','approvedURL','expectedPostID','selectedIndex','budgetSHA256','expiresAt'},'AUTHORITY_SCHEMA')
    require(d['schema']=='wed-ui-photo-source-decision-v1' and d['mode']==c['mode'] and d['state']==('OFFLINE_TEST_ONLY' if offline else 'APPROVED_NEW'),'AUTHORITY_STATE')
    for k in ('runID','approvedURL','expectedPostID','selectedIndex','budgetSHA256'):require(type(d[k]) is type(c[k]) and d[k]==c[k],'AUTHORITY_BINDING')
    try:expiry=datetime.datetime.fromisoformat(d['expiresAt'])
    except (ValueError,TypeError):raise Rejected('AUTHORITY_EXPIRY') from None
    require(expiry.tzinfo is not None and expiry>datetime.datetime.now(datetime.timezone.utc),'AUTHORITY_EXPIRY')
    if not check_owner_clock:
        left=(expiry-datetime.datetime.now(datetime.timezone.utc)).total_seconds()
        require(0<left<=480 and left>(e-b)/1e9,'AUTHORITY_RUNTIME_WINDOW')
    return c
def validate_observation(o,c):
    require(type(o) is dict and set(o)=={'schema',*BIND,'status','tabCleanup','screenshot'},'OBSERVATION_SCHEMA')
    require(o['schema']=='wed-ui-photo-source-observation-v1','OBSERVATION_SCHEMA')
    for k in BIND:require(type(o[k]) is type(c[k]) and o[k]==c[k],'WRONG_BINDING')
    require(o['status'] in ('PASS','FAIL') and type(o['status']) is str,'STATUS_TYPE')
    require(o['tabCleanup'] in ('CLOSED','UNKNOWN') and type(o['tabCleanup']) is str,'CLEANUP_TYPE')
    s=o['screenshot'];require(type(s) is dict and set(s)=={'status','file','sha256'},'SCREENSHOT_SCHEMA')
    require(s['status'] in ('SAVED','UNKNOWN'),'SCREENSHOT_SCHEMA')
    if s['status']=='SAVED':require(s['file']=='browser.jpg' and type(s['sha256']) is str and re.fullmatch('[a-f0-9]{64}',s['sha256']) is not None,'SCREENSHOT_SCHEMA')
    else:require(s['file'] is None and s['sha256'] is None,'SCREENSHOT_SCHEMA')
    return o
def publish_observation(root,o,*,role='producer',offline=False,clock=time.monotonic_ns):
    require(role=='producer','WRITER_ROLE');c=contract(root,offline=offline,clock=clock)
    validate_observation(o,c);return io.publish_atomic(root,io.OBSERVATION,o)
def wait_decision(root,*,role='owner',offline=False,clock=time.monotonic_ns,pause=time.sleep):
    require(role=='owner','WRITER_ROLE');c=contract(root,offline=offline,clock=clock)
    cutoff=io.ns(c['observationDeadlineMonoNs']);sha=None;status='NOT_OBSERVED';code='DEADLINE'
    while True:
        now=clock();require(now>=io.ns(c['startMonoNs']),'CLOCK_RESET')
        if (root/io.OBSERVATION).exists():
            try:
                raw=io.read_raw(root/io.OBSERVATION);sha=io.digest(raw);o=validate_observation(io.parse(raw),c)
                require(o['status']=='PASS','OBSERVED_FAIL');require(o['tabCleanup']=='CLOSED','CLEANUP_UNKNOWN')
                require(o['screenshot']['status']=='SAVED','SCREENSHOT_UNKNOWN')
                require(io.digest(io.read_raw(root/'browser.jpg',2*1024*1024))==o['screenshot']['sha256'],'SCREENSHOT_HASH')
                status,code=('ACCEPTED','OK') if clock()<cutoff else ('LATE','DEADLINE')
            except Rejected as exc:status,code='REJECTED',exc.args[0]
            except FileNotFoundError:status,code='REJECTED','ARTIFACT_MISSING'
            break
        if now>=cutoff:break
        pause(min(.02,(cutoff-now)/1e9))
    return io.publish_atomic(root,io.DECISION,dict(schema='wed-ui-photo-source-browser-decision-v1',**binding(c),decisionMonoNs=str(clock()),status=status,code=code,observationSHA256=sha))
def complete(root,cleanup_state,execution_state,*,role='owner',offline=False,clock=time.monotonic_ns):
    require(role=='owner','WRITER_ROLE');c=contract(root,offline=offline,clock=clock)
    require(cleanup_state in ('CLOSED','UNKNOWN') and execution_state in ('PASS','FAIL'),'FINAL_STATE')
    raw=io.read_raw(root/io.DECISION);d=io.parse(raw)
    require(type(d) is dict and set(d)=={'schema',*BIND,'decisionMonoNs','status','code','observationSHA256'} and d['schema']=='wed-ui-photo-source-browser-decision-v1','DECISION_SCHEMA')
    for k in BIND:require(d[k]==c[k] and type(d[k]) is type(c[k]),'WRONG_BINDING')
    require(d['status'] in ('ACCEPTED','REJECTED','LATE','NOT_OBSERVED'),'DECISION_STATUS')
    codes={'OK','DEADLINE','OBSERVED_FAIL','CLEANUP_UNKNOWN','SCREENSHOT_UNKNOWN','SCREENSHOT_HASH','WRONG_BINDING','OBSERVATION_SCHEMA','ARTIFACT_MISSING','SCREENSHOT_SCHEMA','STATUS_TYPE','CLEANUP_TYPE','BYTE_CAP','SYMLINK','CHANGED_OR_CAP','MALFORMED','NONFINITE','DUPLICATE_KEY'}
    require(type(d['code']) is str and d['code'] in codes and (d['status']!='ACCEPTED' or d['code']=='OK'),'DECISION_CODE')
    at=clock();require(at>=io.ns(c['startMonoNs']),'CLOCK_RESET')
    cleanup=dict(schema='wed-ui-photo-source-cleanup-v1',**binding(c),closedAtMonoNs=str(at),resources=cleanup_state,execution=execution_state)
    io.publish_atomic(root,io.CLEANUP,cleanup)
    status,code='FAIL',d['code']
    if d['status']=='ACCEPTED':
        try:
            require(io.ns(c['startMonoNs'])<=io.ns(d['decisionMonoNs'])<io.ns(c['observationDeadlineMonoNs']),'DECISION_LATE')
            obs=io.read_raw(root/io.OBSERVATION);require(io.digest(obs)==d['observationSHA256'],'OBSERVATION_CHANGED');o=validate_observation(io.parse(obs),c)
            require(o['status']=='PASS' and o['tabCleanup']=='CLOSED','CLEANUP_UNKNOWN')
            require(o['screenshot']['status']=='SAVED' and io.digest(io.read_raw(root/'browser.jpg',2*1024*1024))==o['screenshot']['sha256'],'SCREENSHOT_HASH')
            require(cleanup_state=='CLOSED','CLEANUP_UNKNOWN');require(execution_state=='PASS','EXECUTION_FAILED')
            require(at<io.ns(c['cleanupDeadlineMonoNs']),'CLEANUP_DEADLINE')
            status,code=('PASS_OFFLINE_HANDSHAKE' if offline else 'PASS_UI_SOURCE'),'OK'
        except Rejected as exc:code=exc.args[0]
        except FileNotFoundError:code='ARTIFACT_MISSING'
    if clock()>=io.ns(c['runDeadlineMonoNs']):status,code='FAIL','RUN_DEADLINE'
    return io.publish_atomic(root,io.COMPLETION,dict(schema='wed-ui-photo-source-completion-v1',**binding(c),status=status,code=code,decisionSHA256Observed=io.digest(raw),cleanupSHA256=io.digest(io.read_raw(root/io.CLEANUP)),completedMonoNs=str(clock()),sourceRequests='UNKNOWN'))
