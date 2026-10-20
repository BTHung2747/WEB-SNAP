"""Signal only verified adapter-group members through pinned Linux pidfds."""
import json
import os
import pathlib
import signal
import sys

group, name = json.loads(sys.argv[1]), sys.argv[2]
assert name in ('SIGTERM', 'SIGKILL')
assert os.readlink('/proc/self/ns/pid') == group['namespace']
handles = []
try:
    # Pin all candidates before any signal can make the leader exit/reparent others.
    for member in group['members']:
        try:
            fd = os.pidfd_open(member['pid'])
        except ProcessLookupError:
            continue
        handles.append((member, fd))
    for member, fd in handles:
        try:
            stat = (pathlib.Path('/proc') / str(member['pid']) / 'stat').read_text().rsplit(') ', 1)[1].split()
        except FileNotFoundError:
            continue
        if stat[19] != member['ticks'] or int(stat[2]) != group['pgid'] or int(stat[3]) != group['pgid']:
            continue
        try:
            signal.pidfd_send_signal(fd, getattr(signal, name))
        except ProcessLookupError:
            pass
finally:
    for _member, fd in handles:
        os.close(fd)
