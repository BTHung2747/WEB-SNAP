"""After roles stop: physical/trace gates and provisional JPEG; owned-output cleanup only."""
import hashlib,json,pathlib,sys
from common import summary_valid,stage_policy
P=pathlib.Path('/proxy');W=pathlib.Path('/worker');O=pathlib.Path('/out')
sys.excepthook=lambda *a:print('WHOLEPHOTO_FINALIZE_FAIL',flush=True)
def main():
    stage=stage_policy()
    result=json.loads((W/'result.json').read_text());prior=json.loads((W/'ownership-before.json').read_text())
    try:summary=json.loads((P/'proxy-summary.json').read_text())
    except (OSError,ValueError):summary=None
    traceOK=summary_valid(summary);packet=result.get('preparePacket') or {};meta=result.get('metadataPacket') or {}
    if traceOK:
        try:
            trace=[json.loads(line) for line in (P/'proxy-trace.jsonl').read_text().splitlines()]
            traceOK=len(trace)==summary['trace']['rows'] and len(trace)<=256
            counts={}
            for row in trace:
                counts[row['ownerID']]=counts.get(row['ownerID'],0)+1
                assert row['event'] in ('BEGIN','END','ERROR') and counts[row['ownerID']]<=32
            assert all(secret not in json.dumps(trace) for secret in ('https://','FAKESIGNED','fixture_cookie','__UNIVERSAL'))
        except (OSError,ValueError,KeyError,AssertionError):traceOK=False
    file=W/'image.jpg';provisional=result['parentActualExit']==0 and result['workerActualExit']==0 and packet.get('status')=='PASS'
    fileOK=False
    if provisional:
        contract=packet['contract'];fileOK=(file.exists() and contract['magic']=='jpeg' and contract['mime']=='image/jpeg'
          and contract['frames']==1 and contract['fullDecode']=='PASS' and contract['width']<=8192 and contract['height']<=8192
          and contract['pixels']<=16000000 and file.stat().st_size<=16*1024*1024 and hashlib.sha256(file.read_bytes()).hexdigest()==packet['sha256']
          and meta['summary']['id']=='7678209751167110421' and meta['summary']['type']=='photo' and packet['selectedIndex']==1)
    rows=packet.get('rows') or meta.get('rows') or []
    accounting=json.loads((W/'request-accounting.json').read_text())
    assert accounting==result['requestAccounting'] and accounting['version']==3
    attempts=accounting['preparedGETAttempts']
    accountingOK=accounting['exact'] and accounting['withinBudget']
    assert len([r for r in rows if r['phase']=='metadata'])<=2 and len([r for r in rows if r['phase']=='prepare'])<=1
    assert all(r['method']=='GET' and r['url']=='[url-redacted]' for r in rows)
    from operation_coverage import operation_coverage
    operationOK=False;batchOK=False
    batchValidation={'status':'PARTIAL','accepted':False,'reasonCodes':['MISSING_RECEIPT_OR_TRACE'],'originReceipt':'UNKNOWN'}
    try:
        operations=operation_coverage([json.loads(x) for x in (P/'proxy-trace.jsonl').read_text().splitlines()])
        operationOK=operations['status']=='COMPLETE' and summary['operationCoverage']==operations
        connectors=[json.loads(x) for x in (P/'connector-receipts.jsonl').read_text().splitlines()]
        from batch_validation import validate
        batchValidation=validate(connectors,[json.loads(x) for x in (P/'proxy-trace.jsonl').read_text().splitlines()])
        batchOK=batchValidation['accepted']
    except (OSError,ValueError,KeyError,TypeError):pass
    accepted=traceOK and provisional and fileOK and accountingOK and operationOK and batchOK;removed=[]
    if not accepted:
        for name in ('image.jpg','image.jpg.part'):
            path=W/name
            if name not in prior['preexisting'] and path.is_file() and not path.is_symlink():path.unlink();removed.append(name)
    preserved=all((W/name).exists() for name in prior['preexisting'])
    if prior['preexisting']:assert hashlib.sha256((W/'image.jpg').read_bytes()).hexdigest()==prior['sha']
    receipt={'status':('PASS_WHOLEPHOTO_OFFLINE' if stage=='offline' else 'PASS_SOURCE_TECHNICAL_NEEDS_REVIEW') if accepted else 'FAIL_EXPECTED_OR_UNKNOWN','actualExit':0 if accepted else 20,
       'parentActualExit':result['parentActualExit'],'workerActualExit':result['workerActualExit'],'packetFileProvisional':provisional,
       'fixtureFileContract':fileOK if stage=='offline' else False,'technicalFileContract':fileOK,'traceGate':traceOK,'operationGate':operationOK,'batchGate':batchOK,'batchValidation':batchValidation,'ownedOutputRemoved':removed,'preexistingPreserved':preserved,
       'sourceCalls':0 if stage=='offline' else 'UNKNOWN_USE_REQUEST_ACCOUNTING','accountingVersion':3,'requestAccounting':accounting,'accountingGate':accountingOK,
       'observedStatuses':[{'phase':r['phase'],'status':r.get('status','UNKNOWN'),'decodedBytes':r.get('decodedBytes','UNKNOWN')} for r in rows],
       'sourceFile':('TECHNICAL_PASS_NEEDS_REVIEW' if accepted else 'NOT_ACCEPTED') if stage=='source' else 'NOT_RUN','sourceVisual':'NOT_REVIEWED','stage':stage,'correlation':'UNKNOWN'}
    (O/'whole-result.json').write_text(json.dumps(receipt,indent=2));print('WHOLEPHOTO_PASS' if accepted else 'WHOLEPHOTO_REJECT',flush=True)
    return receipt['actualExit']
if __name__=='__main__':
    try:sys.exit(main())
    except Exception as error:
        removed=[]
        try:
            prior=json.loads((W/'ownership-before.json').read_text())
            for name in ('image.jpg','image.jpg.part'):
                path=W/name
                if name not in prior['preexisting'] and path.is_file() and not path.is_symlink():path.unlink();removed.append(name)
        except (OSError,ValueError):pass
        code='PERMISSION' if isinstance(error,PermissionError) else 'MISSING_RECEIPT' if isinstance(error,FileNotFoundError) else 'INVALID_RECEIPT'
        (O/'validator-failure.json').write_text(json.dumps({'code':code,'actualExit':20,'ownedOutputRemoved':removed}))
        print('WHOLEPHOTO_FINALIZE_REJECT',flush=True);sys.exit(20)
