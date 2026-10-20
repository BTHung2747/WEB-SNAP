# Exactly one known-valid inspection and one full fake pipeline; no repeat until PASS.
import hashlib,json,pathlib,subprocess,sys,time
from candidate_file import inspect_file
from prepare_operations import Operations
from runtime_inventory import collect
from yt_candidate_driver import pipeline
OUT=pathlib.Path('/out');file=OUT/'fixture-input.mp4'
EXPECTED='f587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()
def safe_uncaught(kind,value,tb):print(json.dumps({'code':'SUBPROCESS_TIMEOUT' if kind is subprocess.TimeoutExpired else 'OFFLINE_LONG_GATE_FAILURE'}))
sys.excepthook=safe_uncaught
assert sha(file)==EXPECTED
OUT.joinpath('runtime-inventory.json').write_text(json.dumps(collect(),indent=2),encoding='utf8')
trace=Operations(sink='known-valid-operations.jsonl')
inspection=inspect_file(file,486,trace)
assert sha(file)==EXPECTED and inspection['decode']=='PASS'
OUT.joinpath('known-valid-result.json').write_text(json.dumps({'status':'PASS','sha256':EXPECTED,
    'bytes':file.stat().st_size,'inspection':inspection,'operations':trace.terminals,'sourceRequests':0},indent=2),encoding='utf8')
result,code=pipeline('fixture','7692288554839313682',prepare=True,
         worker_argv=['python3','/lab/src/fixture_pipeline_worker.py','--long-fixture'])
result.update(parentActualExit=code,sourceAttempts=0,environment='network-none exact known-valid486s full extractor/downloader/parent/filecontract')
OUT.joinpath('long-integration-result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
assert code==0 and result['workerActualExit']==0 and result['preparePacket']['result']['sha256']==EXPECTED==sha(OUT/'video.mp4')
assert result['prepareSeconds']<180 and result['preparePacket']['result']['decode']=='PASS'
print('PASS exact known-valid486s and full pipeline; complete decode; reserve10; actual worker/parent0; unchanged input/output SHA; no source')
