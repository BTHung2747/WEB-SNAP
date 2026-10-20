"""Offline-only coordination. Public library API; no HTTP/TLS/DNS implementation."""
import asyncio, ipaddress, socket, time, uuid
from ownership import Trace
import aiohappyeyeballs

SETUP_SECONDS = 10.0
RESERVE_SECONDS = 1.0  # CONNECT/TLS/handoff and cleanup; not a guaranteed TLS duration.

def guard(addresses):
    # Same all-answer policy as stock; never filter or reorder by family.
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
        raise ValueError('POLICY_DENIED')
    if any(a[0] not in (socket.AF_INET, socket.AF_INET6) or a[1] != socket.SOCK_STREAM or a[4][1] != 443 for a in addresses):
        raise ValueError('POLICY_DENIED')
    return addresses

async def resolve_fixture(delay, addresses, deadline, receipts):
    from dns_ipc import resolve
    return await resolve(delay, addresses, deadline, receipts)

class Sockets:
    def __init__(self):
        self.sockets=[]; self.order=[]; self.maxLive=0;self.trace=Trace.current;self.cid=uuid.uuid4().hex[:16];self.deadline=None
    def factory(self, info):
        guard([info])
        if self.deadline is not None and time.monotonic()>=self.deadline:raise TimeoutError('SOCKET_DEADLINE')
        if self.live() >= 2: raise RuntimeError('SOCKET_CAP')
        if self.trace:self.trace.emit(self.cid,'SOCKET_CREATE','BEGIN',code='BEGIN',live=self.live())
        if self.deadline is not None and time.monotonic()>=self.deadline:
            if self.trace:self.trace.emit(self.cid,'SOCKET_CREATE','ERROR',code='DEADLINE',live=self.live())
            raise TimeoutError('SOCKET_DEADLINE')
        sock=socket.socket(info[0], info[1], info[2]); self.sockets.append(sock)
        if self.trace:self.trace.emit(self.cid,'SOCKET_CREATE','END',live=self.live())
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
    if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
    registry.deadline=deadline if registry.deadline is None else min(registry.deadline,deadline)
    last = None
    # Public API has no max_concurrent. Groups of <=2 bound actual open sockets.
    for offset in range(0,len(addresses),2):
        if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
        try:
            async with asyncio.timeout_at(deadline):
                if registry.trace:registry.trace.emit(registry.cid,'LIBRARY_SELECT','BEGIN',code='BEGIN',live=registry.live())
                winner=await aiohappyeyeballs.start_connection(
                    addresses[offset:offset+2], happy_eyeballs_delay=.25 if staggered else None,
                    interleave=0, socket_factory=registry.factory, loop=loop)
                if registry.trace:registry.trace.emit(registry.cid,'LIBRARY_SELECT','END',live=registry.live(),losersClosed=sum(s is not winner and s.fileno()==-1 for s in registry.sockets))
                return winner
        except OSError as exc:
            if registry.trace:registry.trace.emit(registry.cid,'LIBRARY_SELECT','ERROR',code='ERROR',live=registry.live())
            last=exc
            if registry.live(): registry.close(); raise RuntimeError('LOSER_NOT_CLOSED')
        except BaseException:
            if registry.trace:registry.trace.emit(registry.cid,'LIBRARY_SELECT','ERROR',code='ERROR',live=registry.live())
            raise
    if last is not None: raise last  # Preserve library identity; never log its message.
    raise ValueError('NO_ADDRESSES')

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
