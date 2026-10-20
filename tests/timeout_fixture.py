"""No network: hangs until the real runAdapter watchdog terminates the group."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time

if os.environ.get('P3_TEST_GUARD') != 'wed-snap-p3-test':
    raise SystemExit('Timeout fixture requires isolated P3 stack')
helper = sys.argv[1] == '--helper'
if helper:
    control = pathlib.Path(sys.argv[2])
    partial = pathlib.Path('/media') / control.name / 'media.mp4.part'
    mode, phase = 'ignore', 'helper'
else:
    phase, url, target = sys.argv[1:4]
    folder = pathlib.Path(target)
    assert folder.parent == pathlib.Path('/media')
    control = pathlib.Path('/control') / folder.name
    mode = 'ignore' if 'toign000001' in url else 'exit'
control.mkdir(parents=True, exist_ok=True)
stat = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
identity = {'pid': os.getpid(), 'startTicks': stat[19], 'namespace': os.readlink('/proc/self/ns/pid'), 'pgid': os.getpgrp()}

def event(name, **extra):
    record = (json.dumps({'event': name, 'at': time.time() * 1000, **identity, 'phase': phase, **extra}) + '\n').encode()
    fd = os.open(control / 'events.jsonl', os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        assert os.write(fd, record) == len(record)
        os.fsync(fd)
    finally:
        os.close(fd)

def terminate(_signal, _frame):
    event('helper_term_received' if helper else 'term_received', ignored=mode == 'ignore', partialExists=partial.exists())
    if mode == 'ignore':
        return
    # Enough time for the observer to inspect a live child holding its partial.
    time.sleep(0.25)
    event('before_exit', partialExists=partial.exists())
    raise SystemExit(0)

signal.signal(signal.SIGTERM, terminate)
if helper:
    event('helper_started')
else:
    event('adapter_invoked')  # Includes any failure that occurs during preparation.
    folder.mkdir(parents=True, exist_ok=True)
    partial = folder / 'media.mp4.part'
    partial.write_bytes(b'timeout fixture partial\n' * 128)
    event('adapter_started', partialBytes=partial.stat().st_size)
    if mode == 'ignore' or 'toclose0001' in url:
        options = {'stdin': subprocess.DEVNULL, 'stdout': subprocess.DEVNULL, 'stderr': subprocess.DEVNULL} if 'toclose0001' in url else {}
        subprocess.Popen([sys.executable, __file__, '--helper', str(control)], **options)

counter = 0
while True:
    counter += 1
    temporary = control / ('heartbeat.' + str(os.getpid()) + '.tmp')
    temporary.write_text(json.dumps({**identity, 'counter': counter, 'at': time.time() * 1000}))
    temporary.replace(control / ('helper-heartbeat.json' if helper else 'heartbeat.json'))
    time.sleep(0.05)
