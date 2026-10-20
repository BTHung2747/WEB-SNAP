"""Offline-only coordination. Public library API; no HTTP/TLS/DNS implementation."""
import asyncio, ipaddress, socket, time, uuid
from ownership import Trace
import aiohappyeyeballs

SETUP_SECONDS = 10.0
RESERVE_SECONDS = 1.0  # CONNECT/TLS/handoff and cleanup; not a guaranteed TLS duration.

def guard(addresses):
    from dns_admission import guard_row
    if not addresses:raise ValueError('POLICY_DENIED')
    for row in addresses:guard_row(row)
    return addresses

async def resolve_fixture(delay, addresses, deadline, receipts):
    from dns_ipc import resolve
    return await resolve(delay, addresses, deadline, receipts)

class Sockets:
    def __init__(self):
        self.sockets=[]; self.order=[]; self.maxLive=0;self.trace=Trace.current;self.cid=uuid.uuid4().hex[:16];self.deadline=None
        self.context_id=uuid.uuid4().hex[:16];self.pending=set();self.worker_tasks=set();self.reap_failed=False;self.epoch=0;self.epoch_active=False;self.active_deadline=None
        self.groups=0;self.group_index=0;self.records=[];self.stop_code='UNKNOWN';self.suffix_unknown=0;self.late_denied=0;self.secondary=[]
        self.constructor=socket.socket;self.remaining_at_admission=None
    def factory(self, info):
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
        for s in self.sockets: s.close()
        try:
            if self.trace:self.trace.emit(self.cid,'REGISTRY_CLOSE','END',live=self.live())
        except BaseException as exc:error=error or exc
        if error is not None:raise error

async def connect(addresses, deadline, registry, *, staggered=True, loop=None):
    guard(addresses)  # Entire set before first socket, including later groups.
    if len(addresses)>64:raise ValueError('DNS_ANSWER_CAP')
    if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
    from batch_policy import connect_groups
    return await connect_groups(addresses,deadline,registry,loop=loop or asyncio.get_running_loop(),staggered=staggered,library=aiohappyeyeballs.start_connection)

async def setup(addresses, dns_delay, registry, receipt, *, staggered=True, loop=None, budget=10, host='fixture.tiktok.com', absolute_deadline=None):
    started=time.monotonic(); end=started+min(budget, SETUP_SECONDS)
    if absolute_deadline is not None:end=min(end,absolute_deadline)
    receipt.update(setupSeconds=min(budget,10), reserveSeconds=RESERVE_SECONDS)
    receipt['effectiveRemainingAtSetup']=max(0,end-started)
    try:
        # PoC input is fixed; actual proxy caller must retain its original host allowlist.
        import egress
        if not egress.allowed(host):raise ValueError('POLICY_DENIED')
        guarded=await resolve_fixture(dns_delay,addresses,end-RESERVE_SECONDS,receipt)
        winner=await connect(guarded,end-RESERVE_SECONDS,registry,staggered=staggered,loop=loop)
        receipt.update(winnerNonblocking=not winner.getblocking(), reserveRemaining=end-time.monotonic())
        return winner
    except BaseException:
        registry.close(); raise
    finally:
        receipt['setupElapsed']=time.monotonic()-started
