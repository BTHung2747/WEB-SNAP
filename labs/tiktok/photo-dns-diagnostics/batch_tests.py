"""Public-library offline probes. Route only delegate sock_connect to numeric loopback."""
import asyncio,copy,json,os,pathlib,socket,subprocess,sys,threading,time,types,uuid
from candidate import Sockets,connect
from ownership import Trace,FileOps
from proxy_entry import SourceLoop
from batch_policy import BudgetStop,allocation
from operation_coverage import operation_coverage
from tcp_observer import coverage
OUT=pathlib.Path('/out')
def native_operation(rows,incomplete,left):
    p=subprocess.run([sys.executable,'/integration/operation_coverage.py'],input=json.dumps({'rows':rows,'incomplete':incomplete,'socketsLeft':left}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
    assert p.returncode in (0,20);return p.returncode
def native_connector(status,op_exit,left,pending):
    # A distinct native policy/file-independent gate; numeric coverage alone is not success.
    data={'status':status,'operationExit':op_exit,'socketsLeft':left,'pending':pending}
    code='import json,sys;d=json.load(sys.stdin);ok=d["status"]=="WINNER" and d["operationExit"]==0 and d["socketsLeft"]==0 and d["pending"]==0;print(json.dumps({"scope":"CONNECTOR_POLICY_GATE","accepted":ok}));sys.exit(0 if ok else 20)'
    p=subprocess.run([sys.executable,'-c',code],input=json.dumps(data).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
    assert json.loads(p.stdout)['scope']=='CONNECTOR_POLICY_GATE';return p.returncode
def run_batch(name,plan,size=3,budget=4.2,fault=None):
    (OUT/'batch-progress.json').write_text(json.dumps({'case':name,'event':'BEGIN'}))
    fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count();listen=socket.socket();listen.bind(('127.0.0.1',0));listen.listen(64);target=listen.getsockname()
    closed=socket.socket();closed.bind(('127.0.0.1',0));bad=closed.getsockname();closed.close()
    path=OUT/(name+'-trace.jsonl');trace=Trace(path,io=fault);old=Trace.current;Trace.current=trace;registry=Sockets()
    calls=[];errors=[];received=None;seen=[];late=[];reused_deadline=None
    ctx=types.SimpleNamespace(cid=uuid.uuid4().hex[:16],end=time.monotonic()+budget+1,trace=trace,registry=registry)
    class Delegate(asyncio.SelectorEventLoop):
        async def sock_connect(self,sock,address):
            i=int(address[0].rsplit('.',1)[1]);calls.append(i)
            try:
                if plan in ('stall_third','slow_cancel') and i<=2:
                    try:await asyncio.sleep(30)
                    except asyncio.CancelledError:
                        if plan=='slow_cancel':await asyncio.sleep(.15)
                        raise
                if plan=='caller_cancel':await asyncio.sleep(30)
                if plan=='dual':
                    result=await super().sock_connect(sock,target);seen.append(i)
                    if len(seen)==2:barrier.set()
                    await barrier.wait();return result
                winner=1 if plan in ('first_winner','late_factory') else 3 if plan=='stall_third' else 7 if plan=='fast7' else 45 if plan=='fast45' else 64 if plan=='fast64' else 0
                return await super().sock_connect(sock,target if i==winner else bad)
            except BaseException as e:errors.append(e);raise
    class Observed(SourceLoop,Delegate):pass
    loop=Observed(ctx);barrier=asyncio.Event();deadline=time.monotonic()+budget;ctx.end=deadline+1
    infos=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.'+str(i),443)) for i in range(1,size+1)]
    if plan=='bad_tail':infos[-1]=(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))
    if plan=='constructor':
        original=OSError('FIXTURE_CONSTRUCTOR')
        def constructor(*a):raise original
        registry.constructor=constructor
    status='UNKNOWN';elapsed=0
    async def call():
        nonlocal status,received,elapsed
        start=time.monotonic()
        try:
            if plan=='caller_cancel':
                task=asyncio.create_task(connect(infos,deadline,registry,loop=loop));await asyncio.sleep(.05);task.cancel()
                await task
            else:await connect(infos,deadline,registry,loop=loop)
            status='WINNER'
            if plan=='late_factory':
                count=len(registry.order)
                try:registry.last_factory(infos[0])
                except BudgetStop as exc:assert exc.code=='EPOCH_CLOSED'
                else:raise AssertionError('LATE_FACTORY_ALLOWED')
                assert len(registry.order)==count
        except BaseException as e:
            received=e;status=e.code if isinstance(e,BudgetStop) else 'CANCELLED' if isinstance(e,asyncio.CancelledError) else 'POLICY_DENIED' if isinstance(e,ValueError) else 'LIBRARY_ERROR'
        finally:elapsed=time.monotonic()-start;registry.epoch_active=False;registry.close()
    try:loop.run_until_complete(call())
    finally:
        assert not registry.pending and not any(not t.done() for t in registry.worker_tasks) and not asyncio.all_tasks(loop)
        registry.close();listen.settimeout(.01)
        while True:
            try:client,_=listen.accept();client.close()
            except TimeoutError:break
        listen.close();loop.close();trace.close();Trace.current=old
    rows=[json.loads(x) for x in path.read_text().splitlines()] if path.exists() else []
    op=operation_coverage(rows);tcp=coverage(rows);op_exit=native_operation(rows,trace.incomplete,registry.live());policy_exit=native_connector(status,op_exit,registry.live(),len(registry.pending))
    assert registry.live()==0 and registry.maxLive<=2 and fd==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    result={'case':name,'status':status,'budget':budget,'remainingAtAdmission':registry.remaining_at_admission,'elapsed':elapsed,'attemptedNumericIndices':calls,'groups':registry.groups,'groupRecords':registry.records,'suffixUnknown':registry.suffix_unknown,'socketPeak':registry.maxLive,'socketsLeft':registry.live(),'pending':len(registry.pending),'lateDenied':registry.late_denied,'reapFailed':registry.reap_failed,'coverage':tcp,'operationCoverage':op,'traceIncomplete':trace.incomplete,'traceRows':len(rows),'counts':list(trace.counts.values()),'diagnosticGateActualExit':op_exit,'connectorGateActualExit':policy_exit,'FD_before':fd,'FD_after':len(os.listdir('/proc/self/fd')),'threadsBefore':threads,'threadsAfter':threading.active_count(),'publicErrorIdentity':received is None or not isinstance(received,OSError) or any(e is received for e in errors) or plan=='constructor' and received is original,'sourceOtherAddressesReachable':'UNKNOWN','sourceCalls':0}
    (OUT/(name+'-result.json')).write_text(json.dumps(result,indent=2));return result

def derived():
    cases=[]
    r=run_batch('first_pair_stall_third_control','stall_third');assert r['status']=='WINNER' and r['attemptedNumericIndices']==[1,2,3] and r['groupRecords'][0]['pending']==0 and r['groupRecords'][0]['live']==0 and r['connectorGateActualExit']==0;cases.append(r)
    r=run_batch('many_immediate_fail','fast7',7);assert r['attemptedNumericIndices']==list(range(1,8)) and r['status']=='WINNER' and r['connectorGateActualExit']==0;cases.append(r)
    r=run_batch('first_winner','first_winner');assert r['attemptedNumericIndices']==[1] and r['status']=='WINNER' and r['connectorGateActualExit']==0;cases.append(r)
    r=run_batch('many45_trace_cap','fast45',45,8.5);assert r['status']=='TRACE_ADMISSION_LIMIT' and r['attemptedNumericIndices']==list(range(1,9)) and r['suffixUnknown']==37 and r['diagnosticGateActualExit']==0 and r['connectorGateActualExit']==20;cases.append(r)
    return cases

def policies():
    cases=[]
    specs=[('pair_half_second','first_winner',2,.5,'TCP_BUDGET_EXHAUSTED'),('pair_point_nine','first_winner',2,.9,'TCP_BUDGET_EXHAUSTED'),
           ('singleton_point_five_nine','first_winner',1,.59,'TCP_BUDGET_EXHAUSTED'),('singleton_nominal_point_six','first_winner',1,.60,None),
           ('singleton_floor_plus_clock_slack','first_winner',1,.61,'WINNER'),('singleton_point_nine','first_winner',1,.9,'WINNER'),
           ('fast64_prefix','fast64',64,8.5,'TRACE_ADMISSION_LIMIT'),('winner_dual','dual',2,2.2,'WINNER'),
           ('caller_cancel','caller_cancel',3,2.2,'CANCELLED'),('slow_cancel_reap_failure','slow_cancel',3,2.2,'GROUP_REAP_DEADLINE'),('late_factory_after_epoch','late_factory',2,2.2,'WINNER'),
           ('bad_answer_after_prefix','bad_tail',64,4.2,'POLICY_DENIED'),('constructor_error','constructor',1,1.2,'LIBRARY_ERROR')]
    for name,plan,n,b,expected in specs:
        r=run_batch(name,plan,n,b)
        if expected is None:expected='TCP_BUDGET_EXHAUSTED' if r['remainingAtAdmission']<.6 else 'WINNER'
        assert r['status']==expected and r['connectorGateActualExit']==(0 if expected=='WINNER' else 20)
        if expected=='TCP_BUDGET_EXHAUSTED':assert r['attemptedNumericIndices']==[] and r['groups']==0
        if plan=='slow_cancel':assert r['groups']==1 and r['reapFailed'] and r['pending']==0
        if plan=='constructor':assert r['publicErrorIdentity'] and r['operationCoverage']['status']=='COMPLETE'
        cases.append(r)
    return cases
