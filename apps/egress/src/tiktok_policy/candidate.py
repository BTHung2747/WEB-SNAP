"""Offline-only coordination. Public library API; no HTTP/TLS/DNS implementation."""
import asyncio, ipaddress, socket, time, uuid
from .ownership import Trace
import aiohappyeyeballs

SETUP_SECONDS = 10.0
RESERVE_SECONDS = 1.0  # CONNECT/TLS/handoff and cleanup; not a guaranteed TLS duration.

def guard(addresses):
    from .dns_admission import guard_row
    if not addresses:raise ValueError('POLICY_DENIED')
    for row in addresses:guard_row(row)
    return addresses

class Sockets:
    def __init__(self,trace,context_id):
        self.sockets=[]; self.order=[]; self.maxLive=0;self.trace=trace;self.cid=uuid.uuid4().hex[:16];self.deadline=None
        self.context_id=context_id;self.pending=set();self.worker_tasks=set();self.reap_failed=False;self.epoch=0;self.epoch_active=False;self.active_deadline=None
        self.groups=0;self.group_index=0;self.records=[];self.stop_code='UNKNOWN';self.suffix_unknown=0;self.late_denied=0;self.secondary=[]
        self.constructor=socket.socket;self.remaining_at_admission=None
    def factory(self, info):
        if self.trace is None or self.trace.incomplete:raise RuntimeError('TRACE_INCOMPLETE')
        guard([info])
        if self.deadline is not None and time.monotonic()>=self.deadline:raise TimeoutError('SOCKET_DEADLINE')
        if self.live() >= 2: raise RuntimeError('SOCKET_CAP')
        if self.trace:self.trace.observe(self.cid,'SOCKET_CREATE','BEGIN',code='BEGIN',live=self.live(),groupIndex=self.group_index)
        try:
            if self.deadline is not None and time.monotonic()>=self.deadline:raise TimeoutError('SOCKET_DEADLINE')
            sock=self.constructor(info[0], info[1], info[2]); self.sockets.append(sock)
        except BaseException:
            if self.trace:self.trace.observe(self.cid,'SOCKET_CREATE','ERROR',code='ERROR',live=self.live(),groupIndex=self.group_index)
            raise
        if self.trace:self.trace.observe(self.cid,'SOCKET_CREATE','END',live=self.live(),groupIndex=self.group_index)
        self.order.append(info); self.maxLive=max(self.maxLive,self.live()); return sock
    def live(self): return sum(s.fileno() != -1 for s in self.sockets)
    def close(self):
        error=None
        try:
            if self.trace:self.trace.emit(self.cid,'REGISTRY_CLOSE','BEGIN',code='BEGIN',live=self.live())
        except BaseException as exc:error=exc
        for s in self.sockets:
            try:s.close()
            except BaseException as exc:error=error or exc
        try:
            if self.trace:self.trace.emit(self.cid,'REGISTRY_CLOSE','END',live=self.live())
        except BaseException as exc:error=error or exc
        if error is not None:raise error

async def connect(addresses, deadline, registry, *, staggered=True, loop=None):
    guard(addresses)  # Entire set before first socket, including later groups.
    if len(addresses)>64:raise ValueError('DNS_ANSWER_CAP')
    if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
    from .batch_policy import connect_groups
    return await connect_groups(addresses,deadline,registry,loop=loop or asyncio.get_running_loop(),staggered=staggered,library=aiohappyeyeballs.start_connection)

