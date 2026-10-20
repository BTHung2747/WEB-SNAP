"""Small byte files, never video/platform evidence. No limit errors are manufactured."""
import json
import os
import pathlib
import sys
import time

if os.environ.get('P3_TEST_GUARD') != 'wed-snap-p3-test':
    raise SystemExit('P3 fixture guard required')
phase, url, target = sys.argv[1:4]
assert phase == 'prepare'
size = next(n for n in (4095, 4096, 4097) if f'limout0{n}' in url)
folder = pathlib.Path(target)
assert folder.parent == pathlib.Path('/media')
control = pathlib.Path('/control') / folder.name
control.mkdir(parents=True, exist_ok=True)
folder.mkdir(parents=True, exist_ok=True)
partial = folder / 'media.mp4.part'
output = folder / 'media.mp4'
payload = bytes((offset * 19 + 5) & 255 for offset in range(size))
for path in (partial, output):
    with path.open('xb') as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())
stat = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
identity = {'pid': os.getpid(), 'startTicks': stat[19], 'namespace': os.readlink('/proc/self/ns/pid'), 'pgid': os.getpgrp()}

def event(name, **extra):
    with (control / 'events.jsonl').open('a') as stream:
        stream.write(json.dumps({'event': name, 'at': time.time() * 1000, **identity, **extra}) + '\n')
        stream.flush()
        os.fsync(stream.fileno())

event('prepare_started', actualBytes=output.stat().st_size, reportedBytes=size, partialBytes=partial.stat().st_size)
deadline = time.monotonic() + 15
counter = 0
while not (control / 'output-allowed').exists():
    if time.monotonic() > deadline:
        event('fixture_gate_timeout')
        raise SystemExit(2)
    counter += 1
    temp = control / 'heartbeat.tmp'
    temp.write_text(json.dumps({**identity, 'counter': counter}))
    temp.replace(control / 'heartbeat.json')
    time.sleep(0.02)
event('before_exit', actualBytes=output.stat().st_size, reportedBytes=size, partialExists=partial.exists())
print(json.dumps({'file': 'media.mp4', 'size': size, 'inputBytes': 0}), flush=True)
