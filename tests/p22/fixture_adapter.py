"""Metadata TTL fixture, no sockets/platform calls. Production supervisor is unchanged."""
import json
import os
import pathlib
import sys
import time

if os.environ.get('P22_GUARD') != 'wed-snap-metadata-lab' or os.environ.get('MEDIA_ROOT') != '/media':
    raise SystemExit('Refuse non-P22 fixture')
phase, url, folder = sys.argv[1:4]
folder = pathlib.Path(folder)
if folder.parent != pathlib.Path('/media'):
    raise SystemExit('Refuse foreign media')
folder.mkdir(parents=True, exist_ok=True)
control = pathlib.Path('/tmp/p22-control')
control.mkdir(exist_ok=True)
with (control / 'invocations.jsonl').open('a') as stream:
    stream.write(json.dumps({'id': folder.name, 'phase': phase, 'pid': os.getpid(), 'namespace': os.readlink('/proc/self/ns/pid'), 'realEpochMs': int(time.time()*1000)}) + '\n')
if phase == 'analyze':
    (folder / 'preview').write_bytes(b'\x89PNG\r\n\x1a\nP22_METADATA_PREVIEW_FIXTURE')
    result = {'title': 'P22 local metadata fixture', 'duration': 10, 'formats': [{'id': 'fixture-mp4', 'label': 'Byte fixture; not platform video', 'size': 8192}]}
    expiry = control / (folder.name + '.source-expiry.json')
    if expiry.exists():
        # Declared trusted-adapter absolute Unix-ms contract; not parsed from URL.
        result['sourceExpiresAt'] = json.loads(expiry.read_text())['sourceExpiresAt']
    print(json.dumps(result))
elif phase == 'prepare':
    gate = control / (folder.name + '.prepare-gate')
    if gate.exists():
        (folder / 'media.mp4.part').write_bytes(b'P22 local prepare partial')
        deadline = time.monotonic() + 4
        while gate.exists() and time.monotonic() < deadline:
            time.sleep(.02)
        (folder / 'media.mp4.part').unlink(missing_ok=True)
    (folder / 'media.mp4').write_bytes(bytes([7])*8192)
    print(json.dumps({'file': 'media.mp4', 'size': 8192, 'inputBytes': 8192}))
else:
    raise SystemExit('Unknown phase')
