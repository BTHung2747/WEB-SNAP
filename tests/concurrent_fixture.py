"""Guarded byte fixture; counts calls before preparation, including failed calls."""
import json
import os
import pathlib
import signal
import sys
import time

if os.environ.get('P3_TEST_GUARD') != 'wed-snap-p3-test':
    raise SystemExit('Concurrent fixture requires isolated P3 stack')
phase, url, target = sys.argv[1:4]
assert phase == 'prepare'
folder = pathlib.Path(target)
assert folder.parent == pathlib.Path('/media')
control = pathlib.Path('/control') / folder.name
control.mkdir(parents=True, exist_ok=True)
stat = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
identity = {'pid': os.getpid(), 'startTicks': stat[19], 'namespace': os.readlink('/proc/self/ns/pid')}

def event(name, **extra):
    # One O_APPEND write per event: two unexpected children cannot erase each other.
    record = (json.dumps({'event': name, 'at': time.time() * 1000, **identity, **extra}) + '\n').encode()
    fd = os.open(control / 'events.jsonl', os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        assert os.write(fd, record) == len(record)
        os.fsync(fd)
    finally:
        os.close(fd)

event('prepare_invoked')
def terminate(signum, _frame):
    raise RuntimeError('fixture interrupted by signal ' + str(signum))
signal.signal(signal.SIGTERM, terminate)
try:
    folder.mkdir(parents=True, exist_ok=True)
    partial = folder / 'media.mp4.part'
    partial.write_bytes(b'concurrent prepare partial')
    event('prepare_started', partialExists=True)
    deadline = time.monotonic() + 45
    counter = 0
    while not (control / 'finish-allowed').exists():
        if time.monotonic() >= deadline:
            raise TimeoutError('fixture gate exceeded 45s')
        counter += 1
        temporary = control / ('heartbeat.' + str(os.getpid()) + '.tmp')
        temporary.write_text(json.dumps({**identity, 'counter': counter, 'at': time.time() * 1000}))
        temporary.replace(control / 'heartbeat.json')
        time.sleep(0.05)
    size = 262144
    partial.write_bytes(bytes((i * 17 + 3) & 255 for i in range(size)))
    partial.replace(folder / 'media.mp4')
    event('prepare_complete', size=size)
    print(json.dumps({'file': 'media.mp4', 'size': size, 'inputBytes': 0}))
except BaseException as error:
    event('prepare_failed', error=type(error).__name__)
    raise
