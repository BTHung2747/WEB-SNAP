import ast,copy,json,pathlib,re,subprocess,sys
from supervise import run_child,METADATA_SECONDS
from runtime_inventory import collect,require_match
assert METADATA_SECONDS==30
current=collect()
pathlib.Path('/out/runtime-inventory.json').write_text(json.dumps(current,indent=2),encoding='utf8')
require_match(current,current)
for section in ('source','dependencies'):
    stale=copy.deepcopy(current);stale[section][0]['sha256']='fake-stale-hash'
    try:require_match(stale,current)
    except RuntimeError:pass
    else:raise AssertionError('Stale runtime hash accepted')
print('PASS actual runtime inventory match; stale mounted source/installed dependencies rejected offline')
# Compile the exact safe() from download.py without executing its stdin/network entry point.
tree=ast.parse(pathlib.Path('/lab/src/download.py').read_text())
fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='safe')
env={'re':re};exec(compile(ast.Module(body=[fn],type_ignores=[]),'download-safe','exec'),env)
assert 'FAKE' not in env['safe']('https://FAKEUSER:FAKEPASS@host.invalid/FAKEPATH/token?token=FAKEQUERY#FAKEHASH\nCookie: FAKECOOKIE')
print('PASS downloader exact safe function hides pathname/query/userinfo/header tokens (fake only)')
code=subprocess.call(['node','/lab/src/test.mjs'])
if code:sys.exit(code)
code=subprocess.call(['node','/lab/src/test_stages.mjs'])
if code:sys.exit(code)
code=subprocess.call(['node','/lab/src/test_origins.mjs'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_yt_candidate.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_send_diagnostics.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_connection_boundaries.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_read20.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_prepare_operations.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_decode_budget.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_candidate_exit_file.py'])
if code:sys.exit(code)
code=subprocess.call(['python3','/lab/src/test_pipeline.py'])
if code:sys.exit(code)
blocked=run_child(['node','-e','for(;;){}'],METADATA_SECONDS)
assert blocked['timed_out'] and blocked['code']==-9 and 30<=blocked['seconds']<32,blocked
print(json.dumps({'case':'external-watchdog-busy-loop','deadline':METADATA_SECONDS,'actualExit':blocked['code'],
                  'signal':9,'timedOut':blocked['timed_out'],'seconds':blocked['seconds']}))
print('PASS external 30s watchdog kills Node CPU starvation independently of JS timers; no network')
