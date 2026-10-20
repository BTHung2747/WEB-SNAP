"""After roles stop, recheck provisional files and inherited trace/DNS/order gates."""
import hashlib,json,os,pathlib,sys
from common import stage_policy,summary_valid
from album_contract import validate_summary,selection,filename,require,canonical,MIB,file_rows
from operation_coverage import operation_coverage
from batch_validation import validate
from dns_diagnostic import validate_receipt
from evidence_contract import load as strict_load,projected_observer,revalidate_accounting,operation_proof
from http_success import success as http_success
from cleanup_contract import validated as cleanup_policy,disposition
W=pathlib.Path('/worker');P=pathlib.Path('/proxy');O=pathlib.Path('/out')
def load(p,cap=128*1024):
    return strict_load(p,cap)
def lines(p,cap=128*1024):
    data=p.read_bytes();require(len(data)<=cap,'EVIDENCE_CAP');return [json.loads(x) for x in data.splitlines()]
def main():
    settings=None;r={};gates={};files=[];reason='UNKNOWN';operations=[];rebuilt=None;httpProof=None
    selected=[]
    try:
        settings=load(pathlib.Path('/control/control.json'))
        cleanup_policy(settings) # Independently supplied readonly authority, not admission/packet.
        stage=stage_policy();require(stage not in ('cold','bootstrap'),'COLD_ONLY_NO_CAPABILITY');gates['admission']=True
        r=load(W/'result.json')
        require(type(r['parentActualExit']) is int and r['parentActualExit']==0 and type(r['workerActualExit']) is int and r['workerActualExit']==0 and r['readerJoined'] is True,'NATIVE_EXIT')
        meta=validate_summary(r['metadataPacket']['summary'],'7678209751167110421');chosen=r['selection'];selected=selection(chosen,meta)
        require(chosen['mode']==settings['selectionMode'] and selected==(settings['indices'] if settings['indices'] is not None else list(range(1,meta['imageCount']+1))),'SELECTION_RECEIPT')
        own=load(W/'ownership-selected.json');require(own['selected']==[n for i in selected for n in (filename(i),filename(i)+'.part')],'OWNERSHIP_RECEIPT')
        packet=r['preparePacket'];require(packet['status']=='PASS','FILE_LEDGER');file_rows(packet['files'],selected,meta)
        for i,row in zip(selected,packet['files']):
            require(type(row) is dict and row['index']==i and row['file']==filename(i) and row['itemKey']==meta['images'][i-1]['itemKey'],'FILE_LEDGER')
            path=W/filename(i);c=row['contract'];require(path.is_file() and not path.is_symlink() and not os.path.lexists(W/(filename(i)+'.part')),'FILE_OWNERSHIP')
            require(type(row['bytes']) is int and 0<row['bytes']<=16*MIB and path.stat().st_size==row['bytes'],'FILE_BYTES')
            h=hashlib.sha256()
            with path.open('rb') as f:
                for chunk in iter(lambda:f.read(65536),b''):h.update(chunk)
            require(type(row['sha256']) is str and h.hexdigest()==row['sha256'],'FILE_SHA')
            require(c['magic']=='jpeg' and c['mime']=='image/jpeg' and c['frames']==1 and c['fullDecode']=='PASS' and c['width']==meta['images'][i-1]['width'] and c['height']==meta['images'][i-1]['height'] and c['pixels']==c['width']*c['height'],'FILE_CONTRACT')
            ops=load(W/f'operations-public-{i:04d}.json',16384)
            operations.append(operation_proof(ops,i,settings['phaseDeadline']))
            files.append(row)
        require(sum(f['bytes'] for f in files)==packet['outputBytes']<=16*len(selected)*MIB,'AGGREGATE_OUTPUT')
        gates['files']=True
        account=load(W/'request-accounting.json');events=projected_observer(W)
        rebuilt=revalidate_accounting(r,events,account,len(selected))
        gates['accounting']=True
        httpProof=http_success(r,rebuilt,len(selected));gates['httpSuccess']=httpProof['accepted']
        require(httpProof['accepted'] is True,'HTTP_SUCCESS_POLICY')
        summary=load(P/'proxy-summary.json');trace=lines(P/'proxy-trace.jsonl');require(summary_valid(summary) and len(trace)==summary['trace']['rows']<=256,'TRACE')
        require(operation_coverage(trace)==summary['operationCoverage'] and summary['operationCoverage']['status']=='COMPLETE','OPERATION_COVERAGE')
        connectors=lines(P/'connector-receipts.jsonl');require(validate(connectors,trace)['accepted'] is True,'BATCH_REGISTRY')
        require(all(validate_receipt(c['dns'],trace)['accepted'] is True for c in connectors),'DNS_RECEIPT')
        gates.update(trace=True,registry=True,dns=True)
        require(r['sentinelsPreserved'] is True,'SENTINEL');accepted=True
    except Exception as error:
        allowed={'NATIVE_EXIT','SELECTION_RECEIPT','OWNERSHIP_RECEIPT','FILE_LEDGER','FILE_OWNERSHIP','FILE_BYTES','FILE_SHA','FILE_CONTRACT','OPERATIONS','DECODE_PROOF','AGGREGATE_OUTPUT','ACCOUNTING','TRACE','OPERATION_COVERAGE','BATCH_REGISTRY','DNS_RECEIPT','SENTINEL','EVIDENCE_CAP'}
        from evidence_contract import REASON_CODES
        allowed|=REASON_CODES|{'HTTP_SUCCESS_POLICY','STAGE_POLICY','ALBUM_ADMISSION_REQUIRED','ALBUM_ADMISSION_SCHEMA','ALBUM_ADMISSION_STRING','OLD_ONE_PHOTO_CONSUMED','ALBUM_ADMISSION_HASH','ALBUM_ADMISSION_TARGET','ALBUM_ADMISSION_SELECTION','ALBUM_ADMISSION_QUOTA','ALBUM_ADMISSION_EXPIRED','ALBUM_ADMISSION_RUNTIME','ALBUM_ADMISSION_GATE','ALBUM_ADMISSION_CLAIM','ALBUM_AUTHORITY_LINK','ALBUM_AUTHORITY_CAP','CLEANUP_POLICY_INVALID','CLEANUP_POLICY_CONFLICT'}
        reason=error.args[0] if type(error) is RuntimeError and error.args and type(error.args[0]) is str and error.args[0] in allowed else 'EVIDENCE_PERMISSION' if isinstance(error,PermissionError) else 'MISSING_RECEIPT' if isinstance(error,FileNotFoundError) else 'INVALID_RECEIPT';accepted=False
    cleanup=disposition(settings,W,not accepted);removed=cleanup['removed'];preserved=cleanup['preserved']
    if cleanup['status']!='COMPLETE':
        if accepted:
            cleanup=disposition(settings,W,True);removed=cleanup['removed'];preserved=cleanup['preserved']
        accepted=False;reason=reason if reason!='UNKNOWN' else 'CLEANUP_POLICY_INVALID'
    out=dict(status='PASS_ALBUM_OFFLINE' if accepted else 'FAIL_OFFLINE',actualExit=0 if accepted else 20,reasonCode=None if accepted else reason,gates=gates,files=files if accepted else [],ownedOutputRemoved=removed,sentinelsPreserved=preserved,sourceGate=False,sourceCalls=0,visual='FIXTURE_ONLY',contentIdentity='UNKNOWN',workerActualExit=r.get('workerActualExit','UNKNOWN'),parentActualExit=r.get('parentActualExit','UNKNOWN'),recomputedAccounting=rebuilt,operationProof=operations,httpSuccess=httpProof)
    out['cleanupDisposition']=cleanup
    if settings and settings.get('stage')=='source':
        out.update(status='PASS_SOURCE_ALBUM_TECHNICAL_NEEDS_VISUAL_REVIEW' if accepted else 'FAIL_SOURCE_ALBUM',sourceGate=True,sourceCalls='UNKNOWN_USE_REQUEST_ACCOUNTING',visual='NEEDS_VISUAL_REVIEW',stage='source')
    (O/'album-result.json').write_text(json.dumps(out,indent=2));print(out['status'],flush=True);return out['actualExit']
if __name__=='__main__':
    try:sys.exit(main())
    except Exception:
        print('ALBUM_FINALIZER_FAILURE',flush=True);sys.exit(20)
