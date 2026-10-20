"""Pure fixture mutations of frozen actual completion. No DNS/socket/process/workflow."""
import copy,hashlib,importlib.util,json,pathlib,sys,types
sys.dont_write_bytecode=True
ROOT=pathlib.Path(__file__).resolve().parents[3]
LAB=pathlib.Path(__file__).resolve().parent
BASE=ROOT/'labs/tiktok/photo-dns-child-offline/common'
INPUT=ROOT/'docs/evidence/tiktok-dns-child-offline-20261015/offline-1/proxy-result.json'
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def main(out):
    out=pathlib.Path(out);out.mkdir(exist_ok=False)
    sys.path[:0]=[str(ROOT/'apps/egress/src'),str(ROOT/'apps/egress/vendor'),str(LAB)]
    before=load('frozen_collector',BASE/'proxy_collect.py')
    import overlay_entry
    fixed,entry=overlay_entry.bind(BASE)
    source=json.loads(INPUT.read_text(encoding='utf-8-sig'))['connections'][0]
    original=copy.deepcopy(source);ctx=types.SimpleNamespace(cid=source['ownerID'])
    rows=[]
    def record(name,value,phase='analyze',check=None,context=ctx):
        result=fixed.project(context,value,phase)
        if check:assert check(result),name
        rows.append(dict(case=name,fixture=True,diagnosticComplete=result['diagnosticComplete']))
        return result
    baseline=[]
    for key,value in [('workerThreadClosed','MISSING'),('clientClosed','MISSING'),('workerThreadClosed',1),('ownerID','BOUNDARY_MISSING')]:
        item=copy.deepcopy(source)
        if value=='BOUNDARY_MISSING':del item['trace'][0][key]
        elif value=='MISSING':del item[key]
        else:item[key]=value
        old=before.project(ctx,item,'analyze');new=fixed.project(ctx,item,'analyze')
        field=new['boundaries'][0]['ownerID'] if value=='BOUNDARY_MISSING' else new['threadClosed' if key=='workerThreadClosed' else 'clientClosed']
        assert old['diagnosticComplete'] and not new['diagnosticComplete'] and field=='UNKNOWN'
        baseline.append(dict(case=('missing_boundary_owner' if value=='BOUNDARY_MISSING' else f'{key}_{value}'),oldComplete=True,newComplete=False,newValue=field))
    record('happy_actual_frozen',source,check=lambda r:r['diagnosticComplete'])
    assert len({r['ownerID'] for r in source['trace']})>1
    record('legitimate_child_owners',source,check=lambda r:r['diagnosticComplete'] and any(b['ownerID']!=ctx.cid for b in r['boundaries']))
    for key,projected in [('workerThreadClosed','threadClosed'),('clientClosed','clientClosed'),('loopClosed','loopClosed'),('accepted','accepted'),('traceIncomplete','traceIncomplete')]:
        for val in ('MISSING',1,0,None,'false',[],{}):
            item=copy.deepcopy(source)
            if val=='MISSING':del item[key]
            else:item[key]=val
            record(f'{key}_bad_{len(rows)}',item,check=lambda r,k=projected:not r['diagnosticComplete'] and r[k]=='UNKNOWN')
        item=copy.deepcopy(source);item[key]=False
        record(f'{key}_known_false',item,check=lambda r,k=projected:r[k] is False and r['diagnosticComplete'])
    for val in (None,1,[],{},'not-a-phase'):
        record(f'phase_invalid_{len(rows)}',source,phase=val,check=lambda r:r['phase']=='UNKNOWN' and not r['diagnosticComplete'])
    value=copy.deepcopy(source);value['ownerID']='not-an-owner'
    record('invalid_context_owner',value,context=types.SimpleNamespace(cid='not-an-owner'),check=lambda r:r['ownerID']=='UNKNOWN' and not r['diagnosticComplete'])
    value=copy.deepcopy(source);value['traceIncomplete']=True
    record('known_trace_incomplete',value,check=lambda r:r['traceIncomplete'] is True and not r['diagnosticComplete'])
    for key in ('ownerID','phase','event','code','elapsed'):
        for val in ('MISSING',None,[],True):
            item=copy.deepcopy(source)
            if val=='MISSING':del item['trace'][0][key]
            else:item['trace'][0][key]=val
            record(f'boundary_{key}_{len(rows)}',item,check=lambda r,k=key:not r['diagnosticComplete'] and r['boundaries'][0][k]=='UNKNOWN')
    for key in ('dnsExit','dnsGroupLeft','responseBytes','inputBytes','dnsChildReaped','dnsPipesClosed'):
        for value in ('MISSING','invalid'):
            item=copy.deepcopy(source)
            if value=='MISSING':del item['receipt']['dns'][key]
            else:item['receipt']['dns'][key]=value
            record(f'dns_{key}_{value}',item,check=lambda r:not r['diagnosticComplete'])
    for key in ('validation','dnsDiagnostic'):
        item=copy.deepcopy(source)
        if key=='validation':item[key]=[]
        else:item['receipt']['dns'][key]=[]
        record(f'container_{key}_invalid',item,check=lambda r:not r['diagnosticComplete'])
    paired=next(i for i,r in enumerate(source['trace']) if r['phase'] in fixed.PAIRED)
    for val in ('MISSING',True,65,'invalid'):
        item=copy.deepcopy(source)
        if val=='MISSING':del item['trace'][paired]['operationIndex']
        else:item['trace'][paired]['operationIndex']=val
        record(f'operation_index_{len(rows)}',item,check=lambda r:not r['diagnosticComplete'] and r['boundaries'][paired]['operationIndex']=='UNKNOWN')
    item=copy.deepcopy(source);item['trace']=[source['trace'][0]]*129
    record('trace_cap_129',item,check=lambda r:not r['diagnosticComplete'])
    dirty=copy.deepcopy(source);dirty.update(url='https://fake.invalid/PATH_TOKEN?QUERY_TOKEN',cookie='COOKIE_TOKEN')
    dirty['trace'][0].update(host='HOST_TOKEN',ip='IP_TOKEN',message='MESSAGE_TOKEN',stack='STACK_TOKEN')
    data=json.dumps(record('privacy_injection',dirty,check=lambda r:r['diagnosticComplete']))
    assert all(v not in data for v in ('PATH_TOKEN','QUERY_TOKEN','COOKIE_TOKEN','HOST_TOKEN','IP_TOKEN','MESSAGE_TOKEN','STACK_TOKEN','https://'))
    delegateProof=[]
    class Trace:
        incomplete=False
        def mark_incomplete(self):self.incomplete=True
    def install_case(name,folder,value,count=1):
        c=types.SimpleNamespace(cid=ctx.cid,trace=Trace(),_phase_key='not-secret-fixture-key')
        sentinel=object();calls=[]
        class Broker:
            entries={'not-secret-fixture-key':dict(phase='analyze')}
            def finish(self,a,b):calls.append((a,b));return sentinel
        server=types.SimpleNamespace(phase_broker=Broker());fixed.install(server,folder)
        for _ in range(count):assert server.phase_broker.finish(c,value) is sentinel
        assert len(calls)==count and all(a is c and b is value for a,b in calls)
        delegateProof.append(dict(case=name,calls=len(calls),identityPreserved=True,incomplete=c.trace.incomplete))
        return c
    normal=out/'normal';normal.mkdir()
    assert not install_case('normal_delegate',normal,source).trace.incomplete
    bad=copy.deepcopy(source);del bad['workerThreadClosed'];partial=out/'partial';partial.mkdir()
    assert install_case('missing_closure_delegate',partial,bad).trace.incomplete
    fault=out/'sink-blocker';fault.write_text('fixture')
    assert install_case('sink_failure_delegate',fault,source).trace.incomplete
    invalid=copy.deepcopy(source);invalid['ownerID']='invalid';folder=out/'invalid';folder.mkdir()
    assert install_case('invalid_projection_delegate',folder,invalid).trace.incomplete
    countFolder=out/'countcap';countFolder.mkdir();assert install_case('connection_cap_65',countFolder,source,65).trace.incomplete
    emitted=(countFolder/'completions.jsonl').read_text().splitlines();assert len(emitted)<=64 and (countFolder/'completions.jsonl').stat().st_size<=fixed.CAP
    assert entry.main()==78 # Same frozen entry, no STEP5_EXECUTE_SOURCE; no startup or socket.
    assert source==original
    result=dict(status='PASS_PURE_DIAGNOSTIC_COMPLETENESS_FIX',runtime='bundled CPython',version=list(sys.version_info[:3]),projectionCases=len(rows),reviewerReproductions=baseline,cases=rows,delegateCases=delegateProof,overlayCollector=str(pathlib.Path(fixed.__file__).resolve()),frozenEntry=str(pathlib.Path(entry.__file__).resolve()),overlayDenyExit=78,inputSHA256=hashlib.sha256(INPUT.read_bytes()).hexdigest(),inputMutated=False,sourceRequestsNew=0,sourceGrantNew=False,dockerUsed=False,wholeWorkflowRerun=False)
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(dict(status=result['status'],projectionCases=len(rows),reviewerCases=4,delegateCases=len(delegateProof),sourceRequestsNew=0)))
if __name__=='__main__':
    try:main(sys.argv[1])
    except BaseException:
        print('{"error":"PURE_PROJECTION_ASSERTION_FAILED"}');sys.exit(1)
