"""Offline-only coordination. Public library API; no HTTP/TLS/DNS implementation."""
import asyncio, ipaddress, multiprocessing, socket, time, threading
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

def dns_child(pipe, delay, addresses):
    # Explicit latency/address fixture, not a replacement resolver for production.
    # Real stock resolver remains unmodified and is not called on external names.
    try:
        time.sleep(delay)
        result = []
        for family, _, _, _, address in addresses:
            result.extend(socket.getaddrinfo(address[0], 443, family=family,
                          type=socket.SOCK_STREAM, flags=socket.AI_NUMERICHOST))
        pipe.send(result)
    finally:
        pipe.close()

async def resolve_fixture(delay, addresses, deadline, receipts):
    if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
    # Linux-only PoC starts with no background threads. Public fork context avoids
    # spawn's persistent resource-tracker process; do not transplant into a threaded proxy.
    if threading.active_count() != 1: raise RuntimeError('DNS_FORK_THREADS')
    ctx = multiprocessing.get_context('fork')
    read, write = ctx.Pipe(duplex=False)
    proc = ctx.Process(target=dns_child, args=(write, delay, addresses))
    proc.start(); write.close(); started = time.monotonic()
    receipts['dnsPID'] = proc.pid
    try:
        while not read.poll():
            if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
            if not proc.is_alive(): raise OSError('DNS_ERROR')
            await asyncio.sleep(min(.01, max(0, deadline-time.monotonic())))
        rows = read.recv()
        if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
        return guard(rows)
    finally:
        read.close()
        if proc.is_alive(): proc.terminate()
        proc.join(.2)
        if proc.is_alive(): proc.kill(); proc.join(.2)
        receipts.update(dnsElapsed=time.monotonic()-started, dnsChildReaped=not proc.is_alive(), dnsExit=proc.exitcode)
        if proc.is_alive(): raise RuntimeError('DNS_CLEANUP_FAILED')
        proc.close()

class Sockets:
    def __init__(self): self.sockets=[]; self.order=[]; self.maxLive=0
    def factory(self, info):
        guard([info])
        if self.live() >= 2: raise RuntimeError('SOCKET_CAP')
        sock=socket.socket(info[0], info[1], info[2]); self.sockets.append(sock)
        self.order.append(info); self.maxLive=max(self.maxLive,self.live()); return sock
    def live(self): return sum(s.fileno() != -1 for s in self.sockets)
    def close(self):
        for s in self.sockets: s.close()

async def connect(addresses, deadline, registry, *, staggered=True, loop=None):
    guard(addresses)  # Entire set before first socket, including later groups.
    if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
    last = None
    # Public API has no max_concurrent. Groups of <=2 bound actual open sockets.
    for offset in range(0,len(addresses),2):
        if time.monotonic() >= deadline: raise TimeoutError('SETUP_DEADLINE')
        try:
            async with asyncio.timeout_at(deadline):
                return await aiohappyeyeballs.start_connection(
                    addresses[offset:offset+2], happy_eyeballs_delay=.25 if staggered else None,
                    interleave=0, socket_factory=registry.factory, loop=loop)
        except OSError as exc:
            last=exc
            if registry.live(): registry.close(); raise RuntimeError('LOSER_NOT_CLOSED')
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
