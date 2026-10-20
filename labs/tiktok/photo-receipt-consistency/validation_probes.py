"""Bounded native validation controls/faults. Fresh fixture is input from own current run."""
import copy,hashlib,json,os,pathlib,subprocess,sys
from batch_validation import validate
from common import inventory,versions
from operation_coverage import operation_coverage
OUT=pathlib.Path('/out')
def main():
    fd=len(os.listdir('/proc/self/fd'));source=pathlib.Path('/control-fixture')
    receipts=[json.loads(x) for x in (source/'connector-receipts.jsonl').read_text().splitlines()]
    trace=[json.loads(x) for x in (source/'proxy-trace.jsonl').read_text().splitlines()]
    cases=[]
    def run(name,r,t,positive=False):
        (OUT/'progress.json').write_text(json.dumps({'case':name,'event':'BEGIN'}))
        r_before=json.dumps(r,sort_keys=True);t_before=json.dumps(t,sort_keys=True)
        answer=validate(r,t);assert answer['accepted'] is positive
        child=subprocess.run([sys.executable,'/integration/batch_validation.py'],input=json.dumps({'receipts':r,'trace':t}).encode(),stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
        assert child.returncode==(0 if positive else 20) and json.loads(child.stdout)['validation']==answer
        assert r_before==json.dumps(r,sort_keys=True) and t_before==json.dumps(t,sort_keys=True)
        cases.append({'case':name,'validation':answer,'nativeExit':child.returncode,'operationCoverage':operation_coverage(t),'receiptUnchanged':True,'traceUnchanged':True,'sourceCalls':0})
    run('fresh_control',copy.deepcopy(receipts),copy.deepcopy(trace),True)
    from validation_faults import mutate
    for mode in ('batchval-groups0','batchval-records-empty','batchval-owner-disjoint','batchval-registry-disjoint','batchval-duplicate-owner','batchval-missing-operation','batchval-record-mismatch'):
        r,t=mutate(receipts,trace,mode);run(mode,r,t)
    for value,label in [(True,'bool'),(1.0,'float'),(-1,'negative'),(5,'cap'),(None,'null')]:
        r=copy.deepcopy(receipts);r[0]['batch']['groups']=value;run('groups_'+label,r,copy.deepcopy(trace))
    for label,value in [('bool',False),('float',0.0),('negative',-1),('extra',1),('unknown','UNKNOWN')]:
        r=copy.deepcopy(receipts);r[0]['batch']['pending']=value;run('pending_'+label,r,copy.deepcopy(trace))
    for label,edit in [
        ('missing_receipt',lambda r:r.pop()),('extra_receipt',lambda r:r.append(copy.deepcopy(r[0]))),
        ('duplicate_record',lambda r:r[0]['batch']['groupRecords'].append(copy.deepcopy(r[0]['batch']['groupRecords'][0]))),
        ('record_index',lambda r:r[0]['batch']['groupRecords'][0].update(group=2)),
        ('record_bool_index',lambda r:r[0]['batch']['groupRecords'][0].update(group=True)),
        ('record_success',lambda r:r[0]['batch']['groupRecords'][0].update(success=False)),
        ('winner_live_zero',lambda r:r[0]['batch']['groupRecords'][0].update(live=0)),
        ('winner_closed',lambda r:r[0]['batch']['groupRecords'][0].update(closed=2)),
        ('wrong_q',lambda r:r[0]['batch']['groupRecords'][0].update(q=.5)),
        ('wrong_elapsed',lambda r:r[0]['batch']['groupRecords'][0].update(elapsed=1.999)),
        ('nan_active',lambda r:r[0]['batch']['groupRecords'][0].update(active=float('nan'))),
        ('suffix_conflict',lambda r:r[0]['batch'].update(suffixUnknown=64)),
        ('peak_conflict',lambda r:r[0].update(socketPeak=0)),
        ('missing_registry',lambda r:r[0].pop('registryOwnerID')),
        ('invalid_owner',lambda r:r[0].update(ownerID='z'*16)),
        ('swapped_registry',lambda r:r[0].update(registryOwnerID=r[1]['registryOwnerID'])),
        ('failure',lambda r:r[0]['batch'].update(code='LIBRARY_ERROR')),
        ('not_started',lambda r:r[0]['batch'].update(code='NOT_STARTED')),
        ('admission',lambda r:r[0]['batch'].update(code='TRACE_ADMISSION_LIMIT')),
        ('epoch',lambda r:r[0]['batch'].update(epochActive=True)),
        ('cancel',lambda r:r[0]['batch'].update(code='CANCELLED')),
        ('trace_fault',lambda r:r[0]['batch'].update(code='TRACE_INCOMPLETE')),
        ('deadline',lambda r:r[0]['batch'].update(code='TCP_BUDGET_EXHAUSTED')),
        ('closed_epoch_code',lambda r:r[0]['batch'].update(code='EPOCH_CLOSED')),
        ('reap_deadline_code',lambda r:r[0]['batch'].update(code='GROUP_REAP_DEADLINE')),
        ('reap',lambda r:r[0]['batch'].update(reapFailed=True)),
        ('missing_version',lambda r:r[0].pop('version')),
        ('extra_field',lambda r:r[0].update(unknownNumeric=1))]:
        r=copy.deepcopy(receipts);edit(r);run(label,r,copy.deepcopy(trace))
    for label,phase in [('missing_socket_pair','SOCKET_CREATE'),('missing_tcp_pair','FIXTURE_TCP'),('missing_handoff_pair','CONNECT_200')]:
        owner=receipts[0]['registryOwnerID'] if phase=='SOCKET_CREATE' else receipts[0]['ownerID']
        t=[r for r in copy.deepcopy(trace) if not(r['ownerID']==owner and r['phase']==phase)]
        run(label,copy.deepcopy(receipts),t)
    t=copy.deepcopy(trace);owner=receipts[0]['registryOwnerID']
    for r in t:
        if r['ownerID']==owner and r['phase']=='LIBRARY_SELECT':r['contextOwnerID']='e'*16
    run('trace_relationship_conflict',copy.deepcopy(receipts),t)
    t=copy.deepcopy(trace)
    for r in t:
        if r['ownerID']==owner and r['phase']=='SOCKET_CREATE':r['groupIndex']=2
    run('trace_group_conflict',copy.deepcopy(receipts),t)
    t=[r for r in copy.deepcopy(trace) if not(r['ownerID']==owner and r['phase']=='LIBRARY_SELECT' and r['event']=='BEGIN')]
    run('terminal_only',copy.deepcopy(receipts),t)
    # Entire extra pair remains operation COMPLETE but cannot be ignored by profile validator.
    t=copy.deepcopy(trace);extra=[copy.deepcopy(r) for r in t if r['ownerID']==owner and r['phase']=='LIBRARY_SELECT']
    for r in extra:r.update(groupIndex=2,operationIndex=2)
    t.extend(extra);run('extra_library_pair',copy.deepcopy(receipts),t)
    r=copy.deepcopy(receipts);t=copy.deepcopy(trace);r[0]['batch']['groupRecords'][0].update(q=.8,active=.7)
    for x in t:
        if x['ownerID']==owner and x['phase']=='LIBRARY_SELECT' and x['event']=='BEGIN':x.update(totalSeconds=.8,activeSeconds=.7)
    run('consistent_trace_but_pair_floor_invalid',r,t)
    t=copy.deepcopy(trace)
    for x in t:
        if x['ownerID']==receipts[0]['ownerID'] and x['phase'] in ('TCP_CONNECT','FIXTURE_TCP') and x['event']=='END':x.update(event='ERROR',code='ERROR')
    run('winner_without_tcp_success',copy.deepcopy(receipts),t)
    assert fd==len(os.listdir('/proc/self/fd'))
    (OUT/'probe-result.json').write_text(json.dumps({'status':'PASS_BATCH_RECEIPT_TRACE_PROBES','actualExit':0,'newCases':len(cases),'cases':cases,'fdBefore':fd,'fdAfter':len(os.listdir('/proc/self/fd')),'sourceCalls':0,'inputSHA':{'receipts':hashlib.sha256((source/'connector-receipts.jsonl').read_bytes()).hexdigest(),'trace':hashlib.sha256((source/'proxy-trace.jsonl').read_bytes()).hexdigest()},'runtime':{'python':sys.version.split()[0],'versions':versions(),'sources':inventory()}},indent=2));print('PASS batch receipt trace native gates; source0',flush=True);return 0
if __name__=='__main__':sys.exit(main())
