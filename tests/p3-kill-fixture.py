"""Emergency cleanup AFTER FAIL only, with namespace/identity and pidfd guards."""
import json
import os
import pathlib
import signal
import sys
if os.environ.get('P3_TEST_GUARD') != 'wed-snap-p3-test':
    raise SystemExit('P3 guard missing')
m, job = json.loads(sys.argv[1]), sys.argv[2]
assert os.readlink('/proc/self/ns/pid') == m['namespace']
records = [json.loads(line) for line in (pathlib.Path('/control') / job / 'events.jsonl').read_text().splitlines()]
assert any(r['pid'] == m['pid'] and r['startTicks'] == m['startTicks'] and r['namespace'] == m['namespace'] for r in records)
try:
    fd = os.pidfd_open(m['pid'])
except ProcessLookupError:
    raise SystemExit(0)
try:
    p = pathlib.Path('/proc') / str(m['pid'])
    stat = (p / 'stat').read_text().rsplit(') ', 1)[1].split()
    assert stat[19] == m['startTicks'] and int(stat[2]) == m['pgid']
    cmd = (p / 'cmdline').read_bytes()
    assert b'timeout_fixture.py' in cmd or b'/app/infra/media_adapter.py' in cmd
    signal.pidfd_send_signal(fd, signal.SIGKILL)
finally:
    os.close(fd)
