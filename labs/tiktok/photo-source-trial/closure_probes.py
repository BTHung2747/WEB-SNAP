"""Native closure validation and real socket cleanup; offline only, no source."""
import copy,json,os,pathlib,socket,subprocess,sys,threading
from batch_validation import validate
from validation_faults import mutate
from common import inventory,versions
from operation_coverage import operation_coverage
OUT=pathlib.Path('/out')
def read(base):
    return ([json.loads(x) for x in (base/'connector-receipts.jsonl').read_text().splitlines()],
            [json.loads(x) for x in (base/'proxy-trace.jsonl').read_text().splitlines()])
def main():
    fd=len(os.listdir('/proc/self/fd'));threads=threading.active_count();cases=[]
    one=read(pathlib.Path('/control-fixture'));two=read(pathlib.Path('/two-close-fixture'))
    def run(name,r,t,positive=False):
        (OUT/'progress.json').write_text(json.dumps({'case':name,'event':'BEGIN'}))
        before=json.dumps([r,t],sort_keys=True);answer=validate(r,t)
        assert answer['accepted'] is positive
        p=subprocess.run([sys.executable,'/integration/batch_validation.py'],input=json.dumps({'receipts':r,'trace':t}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
        assert p.returncode==(0 if positive else 20) and json.loads(p.stdout)['validation']==answer
        assert before==json.dumps([r,t],sort_keys=True)
        cases.append({'case':name,'nativeExit':p.returncode,'validation':answer,'operationCoverage':operation_coverage(t),'inputUnchanged':True,'sourceCalls':0})
    def fault(name,edit,base=one):
        r,t=copy.deepcopy(base);owner=r[0]['registryOwnerID'];ctx=r[0]['ownerID']
        rows=[x for x in t if x['ownerID']==owner and x['phase']=='REGISTRY_CLOSE']
        edit(r,t,rows,owner,ctx);run(name,r,t)
    run('fresh_single_close',*copy.deepcopy(one),True)
    run('fresh_real_idempotent_close',*copy.deepcopy(two),True)
    for mode in ('closure-live','closure-missing','closure-terminal','closure-error','closure-owner','closure-before-winner','closure-before-handoff','closure-late','closure-extra'):
        run(mode,*mutate(*one,mode))
    for label,value in [('bool',False),('float',0.0),('negative',-1),('unknown','UNKNOWN'),('nan',float('nan')),('infinite',float('inf')),('null',None)]:
        fault('end_live_'+label,lambda r,t,c,o,x,v=value:c[-1].update(live=v))
    for label,value in [('bool',False),('float',0.0),('negative',-1),('two',2),('unknown','UNKNOWN')]:
        fault('begin_live_'+label,lambda r,t,c,o,x,v=value:c[0].update(live=v))
    for label,value in [('bool',True),('float',1.0),('zero',0),('gap',2),('negative',-1),('unknown','UNKNOWN')]:
        def edit(r,t,c,o,x,v=value):
            for row in c:row['operationIndex']=v
        fault('close_index_'+label,edit)
    fault('end_error_code',lambda r,t,c,o,x:c[-1].update(code='ERROR'))
    fault('extra_field',lambda r,t,c,o,x:c[-1].update(unobservedMetric=1))
    for label,value in [('negative',-1),('nan',float('nan'))]:fault('elapsed_'+label,lambda r,t,c,o,x,v=value:c[-1].update(elapsed=v))
    def duplicate(r,t,c,o,x):t[t.index(c[-1])+1:t.index(c[-1])+1]=copy.deepcopy(c)
    fault('duplicate_reopen',duplicate)
    fault('terminal_wrong_owner',lambda r,t,c,o,x:c[-1].update(ownerID=x))
    fault('second_begin_live',lambda r,t,c,o,x:c[2].update(live=1),two)
    fault('second_end_live',lambda r,t,c,o,x:c[-1].update(live=1),two)
    fault('second_terminal_missing',lambda r,t,c,o,x:t.remove(c[-1]),two)
    fault('first_error_then_closed',lambda r,t,c,o,x:c[1].update(event='ERROR',code='ERROR'),two)
    def second_gap(r,t,c,o,x):
        for row in c[2:]:row['operationIndex']=3
    fault('second_index_gap',second_gap,two)
    def reversed_pairs(r,t,c,o,x):
        at=t.index(c[0]);t[:]=[a for a in t if a not in c];t[at:at]=c[2:]+c[:2]
    fault('second_pair_before_first',reversed_pairs,two)
    def early_snapshot(r,t,c,o,x):
        row=next(a for a in t if a['ownerID']==x and a['phase']=='TUNNEL_CLOSE')
        t.remove(row);t.insert(t.index(c[0]),row)
    fault('completion_before_close',early_snapshot)
    def after_snapshot(r,t,c,o,x):
        t[:]=[a for a in t if a not in c];at=next(i for i,a in enumerate(t) if a['ownerID']==x and a['phase']=='TUNNEL_CLOSE')+1;t[at:at]=c
    fault('close_after_snapshot_before_return',after_snapshot)
    def orphan(r,t,c,o,x):
        rows=copy.deepcopy(c)
        for row in rows:row['ownerID']='e'*16
        t.extend(rows)
    fault('orphan_close_owner',orphan)
    fault('live_missing',lambda r,t,c,o,x:c[-1].pop('live'))
    def terminal_first(r,t,c,o,x):
        a=t.index(c[0]);b=t.index(c[1]);t[a],t[b]=t[b],t[a]
    fault('terminal_before_begin',terminal_first)
    def reused_index(r,t,c,o,x):
        for row in c[2:]:row['operationIndex']=1
    fault('second_reused_index',reused_index,two)
    physical=physical_probes()
    assert fd==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    result={'status':'PASS_REGISTRY_CLOSURE_OFFLINE','actualExit':0,'validationCases':len(cases),'physicalCases':len(physical),'newCases':len(cases)+len(physical),'cases':cases,'physical':physical,'fdBefore':fd,'fdAfter':len(os.listdir('/proc/self/fd')),'threadsBefore':threads,'threadsAfter':threading.active_count(),'sourceCalls':0,'runtime':{'python':sys.version.split()[0],'versions':versions(),'sources':inventory()}}
    (OUT/'probe-result.json').write_text(json.dumps(result,indent=2));print('PASS closure native and physical gates; source0',flush=True);return 0

def physical_probes():
    from candidate import Sockets
    from ownership import Trace,FileOps,delegate_cleanup
    results=[]
    for mode in ('once','twice','write_begin','write_end','cap','raise_begin','raise_end','primary_cleanup'):
        before=len(os.listdir('/proc/self/fd'));old=Trace.current;original=OSError('FIXTURE_TRACE');primary=ValueError('FIXTURE_PRIMARY');identity=None
        class IO(FileOps):
            def write(self,file,text):
                row=json.loads(text)
                if row['phase']=='REGISTRY_CLOSE' and mode=='write_'+row['event'].lower():raise original
                return super().write(file,text)
        class Observe(Trace):
            def emit(self,cid,phase,event,*a,**k):
                if phase=='REGISTRY_CLOSE' and (mode=='raise_'+event.lower() or mode=='primary_cleanup' and event=='BEGIN'):raise original
                return super().emit(cid,phase,event,*a,**k)
        path=OUT/('physical-'+mode+'.jsonl');trace=Observe(path,io=IO());Trace.current=trace;registry=Sockets()
        registry.factory((socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443)))
        registry.factory((socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.2',443)))
        try:
            if mode=='primary_cleanup':
                def delegate():raise primary
                try:delegate_cleanup(delegate,registry.close,lambda error:None)
                except ValueError as error:identity=error is primary
                assert identity
            else:
                try:
                    for _ in range(16 if mode=='cap' else 2 if mode=='twice' else 1):registry.close()
                except OSError as error:identity=error is original;assert identity
        finally:
            assert registry.live()==0 and not registry.pending
            trace.close();Trace.current=old
        rows=[json.loads(x) for x in path.read_text().splitlines()] if path.exists() else []
        coverage=operation_coverage(rows)
        p=subprocess.run([sys.executable,'/integration/diagnostic_gate.py'],input=json.dumps({'coverage':coverage['status'],'incomplete':trace.incomplete,'socketsLeft':registry.live()}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
        valid=mode in ('once','twice');assert p.returncode==(0 if valid else 20)
        assert before==len(os.listdir('/proc/self/fd'))
        results.append({'case':mode,'diagnosticNativeExit':p.returncode,'physicalSocketsLeft':registry.live(),'pending':len(registry.pending),'FD_before':before,'FD_after':len(os.listdir('/proc/self/fd')),'traceIncomplete':trace.incomplete,'operationCoverage':coverage,'errorIdentity':identity,'sourceCalls':0})
    return results
if __name__=='__main__':sys.exit(main())
