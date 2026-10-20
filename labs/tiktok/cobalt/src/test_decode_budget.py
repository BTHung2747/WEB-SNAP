# Offline F-DECODE-BUDGET: no payload/cmd/output leaves native diagnostics.
import json,pathlib,subprocess,time
from unittest.mock import Mock,patch
from prepare_operations import Operations
from candidate_file import DECODE_RESERVE_SECONDS
assert DECODE_RESERVE_SECONDS==10
results=[]
for left in (-1,0,5,10):
    trace=Operations(time.monotonic()+left,sink='decode-exhausted-'+str(left)+'.jsonl')
    with patch('prepare_operations.subprocess.Popen',Mock()) as spawn:
        try:trace.native('DECODE',['python3','-c','pass'],180,reserve=10);raise AssertionError('Expected exhausted reserve')
        except RuntimeError as error:assert error.args==('PREPARE_DEADLINE',)
        assert spawn.call_count==0
    assert trace.terminals[-1]['code']=='PREPARE_DEADLINE' and trace.terminals[-1]['returncode'] is None
    results.append({'case':'exhausted-'+str(left),'spawnCalls':0,'operation':trace.terminals[-1]})

for name,script,left,expected in [
 ('success','pass',15,0),('exit20','import sys;sys.exit(20)',15,20),
 ('selfkill','import os,signal;os.kill(os.getpid(),signal.SIGKILL)',15,-9),
 ('timeout','import time;time.sleep(2)',10.08,-9)]:
    trace=Operations(time.monotonic()+left,sink='decode-child-'+name+'.jsonl')
    error=None
    try:trace.native('DECODE',['python3','-c',script],180,reserve=10)
    except (RuntimeError,subprocess.TimeoutExpired) as caught:error=type(caught).__name__
    last=trace.terminals[-1]
    assert last['returncode']==expected and 0<last['timeout']<=left-10
    assert last['code']==('OK' if name=='success' else 'SUBPROCESS_TIMEOUT' if name=='timeout' else 'DECODE_FAIL')
    assert (error is None)==(name=='success')
    results.append({'case':name,'errorClass':error,'operation':last,'reapedActualReturncode':expected})
assert 'cmd' not in json.dumps(results) and 'stdout' not in json.dumps(results)
pathlib.Path('/out/decode-budget-fixtures.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,
    'reserveSeconds':10,'exhaustedBeforeSpawn':True,'nativeErrorsAndReap':True,
    'results':results,'ownershipCleanupCases':'Existing actual parent metadata/prepare exit20/kill fixtures execute in same suite'},indent=2),encoding='utf8')
print('PASS F-DECODE-BUDGET remaining180-reserve10, exhausted no spawn, native rc0/20/-9 and timeout kill/reap; no payload')
