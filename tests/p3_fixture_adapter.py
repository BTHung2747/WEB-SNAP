"""Prepare barriers/local sockets ONLY in guarded P3; no platform calls."""
import json
import os
import pathlib
import runpy
import signal
import sys
import time

if os.environ.get('P3_TEST_GUARD') != 'wed-snap-p3-test':
    raise SystemExit('P3 fixture guard required')
phase, url, folder = sys.argv[1:4]
folder = pathlib.Path(folder)
if phase == 'prepare' and any(name in url for name in ('sockctrl001', 'sockclose01', 'sockstall01')):
    runpy.run_path('/app/tests/p3_socket_entry.py', run_name='__main__')
    raise SystemExit(0)
if phase == 'prepare' and any(name in url for name in ('limout04095', 'limout04096', 'limout04097')):
    runpy.run_path('/app/tests/byte_limits_fixture.py', run_name='__main__')
    raise SystemExit(0)
if (phase == 'analyze' and 'toana000001' in url) or (phase == 'prepare' and any(name in url for name in ('toprep00001', 'toign000001', 'toclose0001'))):
    runpy.run_path('/app/tests/timeout_fixture.py', run_name='__main__')
    raise SystemExit(0)
if phase == 'prepare' and any(name in url for name in ('cpblock0001', 'cpsame00001', 'cpdiff00001')):
    runpy.run_path('/app/tests/concurrent_fixture.py', run_name='__main__')
    raise SystemExit(0)
if phase != 'prepare' or not any(name in url for name in ('prepwait001', 'prepqueue01', 'prepcrash01')):
    # Analyze is deliberately normal/selectable. Regression keeps the old FFmpeg fixture.
    runpy.run_path('/app/tests/fixture_adapter.py', run_name='__main__')
    raise SystemExit(0)

control = pathlib.Path('/control') / folder.name
control.mkdir(parents=True, exist_ok=True)
folder.mkdir(parents=True, exist_ok=True)
partial = folder / 'media.mp4.part'
partial.write_bytes(b'P3 guarded prepare partial')
stat = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
identity = {'pid': os.getpid(), 'startTicks': stat[19], 'namespace': os.readlink('/proc/self/ns/pid')}

def event(name, **extra):
    with (control / 'events.jsonl').open('a') as stream:
        stream.write(json.dumps({'event': name, 'at': time.time() * 1000, **identity, **extra}) + '\n')
        stream.flush()
        os.fsync(stream.fileno())

def terminate(_signum, _frame):
    # The test can inspect the live child while SIGTERM is pending, before allowing exit.
    event('term_received', partialExists=partial.exists())
    deadline = time.monotonic() + 1.5  # Less than runAdapter's 2s SIGKILL fallback.
    while not (control / 'exit-allowed').exists() and time.monotonic() < deadline:
        time.sleep(0.02)
    event('before_exit', partialExists=partial.exists())
    raise SystemExit(0)

signal.signal(signal.SIGTERM, terminate)
event('prepare_started', partialExists=True)
counter = 0
while True:
    counter += 1
    temporary = control / 'heartbeat.tmp'
    temporary.write_text(json.dumps({**identity, 'counter': counter, 'at': time.time() * 1000}))
    temporary.replace(control / 'heartbeat.json')
    time.sleep(0.05)
