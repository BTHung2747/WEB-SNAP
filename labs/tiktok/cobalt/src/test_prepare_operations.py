# Offline fixed-schema operations, real subprocess exit/timeout and poisoned payloads.
import json,pathlib,subprocess,time
from prepare_operations import Operations
from send_diagnostics import worker_class
trace=Operations(sink='operation-tests.jsonl')
secret='https://fixture.invalid/FAKEPATH?token=FAKEQUERY Cookie: FAKECOOKIE'
for operation in ('DOWNLOADER','OUTPUT_CHECK','CONTRACT','HASH'):
    with trace.step(operation,trace.timeout(180)):pass
p=trace.native('FFPROBE',['python3','-c','import sys;sys.exit(0)'],1)
assert p.returncode==0
try:trace.native('DECODE',['python3','-c','import time;time.sleep(2)',secret],.02);raise AssertionError('Expected timeout')
except subprocess.TimeoutExpired as error:assert worker_class(error)=='subprocess.TimeoutExpired'
assert trace.terminals[-1]['code']=='SUBPROCESS_TIMEOUT' and trace.terminals[-1]['returncode']==-9
try:trace.native('DECODE',['python3','-c','import sys;sys.exit(20)',secret],1);raise AssertionError('Expected nonzero')
except RuntimeError:pass
assert trace.terminals[-1]['code']=='DECODE_FAIL' and trace.terminals[-1]['returncode']==20
try:
    with trace.step('CONTRACT',1):raise RuntimeError({'secret':secret})
except RuntimeError:pass
assert trace.terminals[-1]['code']=='UNKNOWN_ERROR'
assert 'FAKE' not in json.dumps(trace.terminals)
events=[json.loads(line) for line in pathlib.Path('/out/operation-tests.jsonl').read_text().splitlines()]
assert all(set(e)=={'operation','event','code','elapsed','timeout','returncode'} for e in events)
assert len(events)==2*len(trace.terminals)
expired=Operations(time.monotonic()-1,sink='expired-operation-tests.jsonl')
try:expired.timeout(120);raise AssertionError('Expired prepare accepted')
except RuntimeError:pass
remaining=Operations(time.monotonic()+.2,sink='remaining-operation-tests.jsonl').timeout(30)
assert 0<remaining<=.2
pathlib.Path('/out/operation-fixtures.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,
    'timeoutWhitelisted':True,'timeoutActualReturncode':-9,'nonzeroActualReturncode':20,
    'fixedSchema':True,'poisonRejected':True,'remainingDeadlineClamped':True,'operations':trace.terminals},indent=2),encoding='utf8')
print('PASS prepare operations begin/end/error fixed schema, actual exit0/20/-9, TimeoutExpired whitelist, no cmd/output/payload, remaining180s clamp')
