# Cached lab entrypoint: actual runtime hash gate before any source operation.
import datetime,json,pathlib,sys
from runtime_inventory import collect,require_match
from yt_candidate_driver import pipeline
OUT=pathlib.Path('/out')
def main():
    url,expected_id=sys.argv[1:3]
    reserved={'stage':'reserved','expectedId':expected_id,'input':'[url-redacted]',
              'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'maxMetadataGET':2,'maxPrepareGET':1}
    with (OUT/'attempt-reserved.json').open('x',encoding='utf8') as f:json.dump(reserved,f)
    current=collect();(OUT/'runtime-inventory.json').write_text(json.dumps(current,indent=2),encoding='utf8')
    try:require_match(json.loads((OUT/'offline-runtime.json').read_text()),current)
    except Exception:
        result={'stage':'hash-gate','status':'FAIL','error':'OFFLINE_RUNTIME_HASH_MISMATCH','sourceAttempts':0,'file':'NOT_RUN'}
        (OUT/'candidate-result.json').write_text(json.dumps(result,indent=2),encoding='utf8');print(json.dumps(result));return 30
    result,code=pipeline(url,expected_id,prepare=True,allow_network=True)
    result['runtimeHashGate']='PASS';result['parentActualExit']=code
    result['visualAudioWatermark']='NEEDS_VISUAL_REVIEW' if result.get('status')=='FILE_NEEDS_VISUAL_REVIEW' else 'NOT_RUN'
    (OUT/'candidate-result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:result.get(k) for k in ('stage','status','file','metadataAccepted','workerActualExit','parentActualExit','error')}))
    return code
if __name__=='__main__':sys.exit(main())
