"""Production policy/Handler, controlled DNS+connector, real loopback/socketpair I/O.
Run ONLY in the network-none, no-data-volume standalone lab. No external probes.
"""
import ast
import contextlib
import copy
import hashlib
import importlib.util
import io
import ipaddress
import json
import os
import pathlib
import socket
import sys
import threading
import time
import unittest
from datetime import datetime, timezone, timedelta

SOURCE = pathlib.Path('/lab/production/egress.py')
G4 = '8.8.8.8'
G4_SECOND = '1.1.1.1'
G6 = '2001:4860:4860::8888'
DOMAINS = ['youtube.com', 'youtu.be', 'googlevideo.com', 'ytimg.com', 'googleapis.com',
           'tiktok.com', 'tiktokcdn.com', 'tiktokv.com', 'byteoversea.com', 'ibytedtos.com',
           'fb.watch', 'facebook.com', 'fbcdn.net', 'fbsbx.com', 'x.com', 'twitter.com', 'twimg.com']
DENIED_HOSTS = ['youtube.com.evil.example', 'evilyoutube.com', 'notyoutube.com', 'youtube.come',
                'googlevideo.com.evil.example', 'rr1googlevideo.com', 'localhost', 'metadata.google.internal',
                'youtube.com@127.0.0.1', 'user@youtube.com', 'user@www.youtube.com', 'youtube.com@rr1.googlevideo.com',
                '127.0.0.1', '8.8.8.8', '[::1]', '::1', '[2001:4860:4860::8888]']
NON_GLOBAL = ['127.0.0.1', '10.0.0.1', '172.16.0.1', '192.168.1.1', '169.254.169.254',
              '100.64.0.1', '100.127.255.254', '0.0.0.0', '::1', 'fc00::1', 'fd12::1', 'fe80::1']
DNS_DENIED = [(f'non-global-{ip}', [ip]) for ip in NON_GLOBAL] + [('empty', []), ('resolver-error', None)]
for a, b in [(G4, '10.0.0.1'), (G6, 'fc00::1'), (G4, 'fc00::1'), (G6, '10.0.0.1')]:
    DNS_DENIED += [(f'mixed-{a}-then-{b}', [a, b]), (f'mixed-{b}-then-{a}', [b, a])]
PAYLOAD = b'P18 controlled tunnel\x00\xff\n'
ACK = b'ACK:' + PAYLOAD
HTTP_TIMEOUT = 2
results = []

def log(**data):
    now = datetime.now(timezone.utc)
    print(json.dumps(dict(utc=now.isoformat(), vietnam=now.astimezone(timezone(timedelta(hours=7))).isoformat(), **data)), flush=True)

def addresses(ips):
    if ips is None:
        return socket.gaierror(socket.EAI_AGAIN, 'controlled DNS failure')
    return [(socket.AF_INET6, socket.SOCK_STREAM, socket.IPPROTO_TCP, '', (ip, 443, 0, 0))
            if ':' in ip else (socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, '', (ip, 443)) for ip in ips]

class Dial:
    def __init__(self, spy, family, kind, proto):
        self.spy = spy; self.family = family; self.kind = kind; self.proto = proto
        self.stream = None; self.timeout = None; self.closed = False
    def settimeout(self, seconds):
        self.timeout = seconds
        if self.stream: self.stream.settimeout(seconds)
    def connect(self, addr):
        call = dict(family=self.family, kind=self.kind, proto=self.proto, sockaddr=list(addr),
                    resolveCountAtDial=len(self.spy.resolves))
        self.spy.dials.append(call)
        # Never use a network connector. Even a bad runtime verdict remains inside socketpair.
        assert isinstance(addr, tuple) and ipaddress.ip_address(addr[0]) and addr[1] == 443
        assert self.kind == socket.SOCK_STREAM and self.proto == socket.IPPROTO_TCP
        assert len(addr) == (4 if self.family == socket.AF_INET6 else 2)
        if len(self.spy.dials) in self.spy.fail_dials:
            call['result'] = 'controlled-OSError'; raise OSError('controlled first dial failure')
        self.stream, peer = socket.socketpair()
        self.stream.settimeout(self.timeout); peer.settimeout(HTTP_TIMEOUT)
        call['result'] = 'socketpair'
        def echo():
            try:
                body = b''
                while len(body) < len(PAYLOAD):
                    chunk = peer.recv(len(PAYLOAD) - len(body))
                    if not chunk: break
                    body += chunk
                assert body == PAYLOAD
                self.spy.payloads.append(body.hex())
                peer.sendall(ACK)
                assert peer.recv(1) == b'', 'Production Handler must close upstream after client disconnect'
            except Exception as e:
                self.spy.peer_errors.append(type(e).__name__ + ': ' + str(e))
            finally: peer.close()
        thread = threading.Thread(target=echo, name='p18-peer', daemon=True)
        self.spy.peers.append(thread); thread.start()
    def fileno(self): return self.stream.fileno()
    def recv(self, n): return self.stream.recv(n)
    def sendall(self, data): return self.stream.sendall(data)
    def close(self):
        if not self.closed:
            self.closed = True
            if self.stream: self.stream.close()

class Spy:
    """Replace only resolver/socket connector namespace, never policy or ipaddress."""
    def __init__(self, replies, fail_dials=()):
        self.replies = replies; self.fail_dials = set(fail_dials)
        self.resolves = []; self.dials = []; self.sockets = []; self.peers = []
        self.peer_errors = []; self.payloads = []; self.forbidden = []
    def getaddrinfo(self, host, port, **kwargs):
        self.resolves.append(dict(host=host, port=port, options=kwargs))
        assert port == 443 and kwargs == {'type': socket.SOCK_STREAM}
        assert len(self.resolves) <= len(self.replies), 'Unexpected second resolve while dialing'
        reply = self.replies[len(self.resolves) - 1]
        if isinstance(reply, Exception): raise reply
        return reply
    def socket(self, family, kind, proto=0):
        value = Dial(self, family, kind, proto); self.sockets.append(value); return value
    def __getattr__(self, key):
        if key == 'create_connection':
            def forbidden(*_args, **_kwargs):
                self.forbidden.append('create_connection'); raise AssertionError('Forbidden hostname connector path')
            return forbidden
        return getattr(socket, key)
    def report(self):
        return copy.deepcopy(dict(resolver=self.resolves, dial=self.dials, resolveCount=len(self.resolves),
                    dialCount=len(self.dials), socketCreated=len(self.sockets),
                    socketClosed=sum(s.closed for s in self.sockets), peerErrors=self.peer_errors,
                    payloadHex=self.payloads, forbiddenConnectors=self.forbidden))
    def settle(self):
        for peer in self.peers: peer.join(3)
        assert not any(p.is_alive() for p in self.peers), 'Orphan socketpair peer thread'
        assert all(s.closed for s in self.sockets), 'Handler leaked upstream socket'
        assert not self.peer_errors and not self.forbidden

def load_source():
    spec = importlib.util.spec_from_file_location('egress', SOURCE)
    module = importlib.util.module_from_spec(spec); sys.modules['egress'] = module; spec.loader.exec_module(module)
    assert module.Handler.handle.__code__.co_filename == str(SOURCE)
    assert module.allowed.__code__.co_filename == str(SOURCE)
    return module

def case(name, expected, run):
    try:
        run(); result = 'PASS'; error = None
    except Exception as e:
        result = 'FAIL'; error = type(e).__name__ + ': ' + str(e)
    results.append(dict(name=name, result=result))
    log(stage='case-result', name=name, expected=expected, result=result, error=error)

@contextlib.contextmanager
def patch_transport(module, spy):
    original = module.socket; module.socket = spy
    try: yield
    finally: module.socket = original

def policy_matrix(module):
    for host in [d for domain in DOMAINS for d in (domain, 'sub.' + domain)] + DENIED_HOSTS:
        expected = host not in DENIED_HOSTS
        def run(host=host, expected=expected):
            spy = Spy([addresses([G4])])
            with patch_transport(module, spy): verdict = module.allowed(host)
            log(stage='allowed-observed', host=host, verdict=verdict, **spy.report())
            assert verdict is expected; assert not spy.resolves and not spy.dials
        case('allowed:' + host, expected, run)
    dns_cases = [('global-A', [G4]), ('two-global-A', [G4, G4_SECOND]), ('global-AAAA', [G6]),
                 ('global-A-AAAA', [G4, G6])] + DNS_DENIED
    for name, ips in dns_cases:
        allowed = name.startswith('global') or name == 'two-global-A'
        def run(name=name, ips=ips, allowed=allowed):
            spy = Spy([addresses(ips)]); returned = None; error = None
            with patch_transport(module, spy):
                try: returned = module.public_addresses('www.youtube.com'); verdict = 'ALLOW'
                except Exception as e: verdict = 'DENY'; error = type(e).__name__
            log(stage='public-addresses-observed', name=name, ips=ips, verdict=verdict, errorType=error,
                returned=returned, **spy.report())
            assert verdict == ('ALLOW' if allowed else 'DENY')
            assert len(spy.resolves) == 1 and not spy.dials
            if allowed: assert returned == addresses(ips)
        case('dns:' + name, 'ALLOW' if allowed else 'DENY', run)
    for host in DENIED_HOSTS:
        def run(host=host):
            spy = Spy([addresses([G4])]); verdict = 'ALLOW'
            with patch_transport(module, spy):
                try: module.public_addresses(host)
                except Exception: verdict = 'DENY'
            log(stage='denied-host-policy-observed', host=host, verdict=verdict, **spy.report())
            assert verdict == 'DENY'; assert not spy.resolves and not spy.dials
        case('dns-host-denied:' + host, 'DENY/0 resolve/0 dial', run)

class LabServer:
    def __init__(self, module):
        self.active = 0; self.lock = threading.Lock()
        lab = self
        class ObservedServer(module.Server):
            def finish_request(self, request, client_address):
                with lab.lock: lab.active += 1
                try: super().finish_request(request, client_address)
                finally:
                    with lab.lock: lab.active -= 1
        self.server = ObservedServer(('127.0.0.1', 0), module.Handler)
        assert self.server.RequestHandlerClass is module.Handler
        self.address = self.server.server_address
        self.thread = threading.Thread(target=lambda: self.server.serve_forever(poll_interval=0.02), name='p18-server', daemon=True)
        self.thread.start()
        log(stage='production-handler-server', bind=list(self.address), handlerSource=module.Handler.handle.__code__.co_filename)
    def transaction(self, line, status, spy):
        # Actual loopback HTTP request, no DNS lookup, Handler body untouched.
        conn = socket.socket(socket.AF_INET, socket.SOCK_STREAM); conn.settimeout(HTTP_TIMEOUT)
        try:
            conn.connect(self.address); conn.sendall((line + '\r\nHost: lab\r\n\r\n').encode('ascii'))
            head = b''
            while b'\r\n\r\n' not in head:
                chunk = conn.recv(1)
                assert chunk and len(head) < 4096; head += chunk
            actual_status = int(head.split(b' ')[1])
            log(stage='CONNECT-status', request=line, status=actual_status, **spy.report())
            assert actual_status == status
            if actual_status == 200:
                conn.sendall(PAYLOAD); received = b''
                while len(received) < len(ACK):
                    chunk = conn.recv(len(ACK) - len(received)); assert chunk; received += chunk
                assert received == ACK
                log(stage='tunnel-payload', sentBytes=len(PAYLOAD), receivedBytes=len(received),
                    sha256=hashlib.sha256(received).hexdigest(), transport='loopback + socketpair; no Internet/TLS')
        finally:
            conn.close()
            end = time.monotonic() + 3
            while self.active and time.monotonic() < end: time.sleep(0.005)
            spy.settle()
            assert self.active == 0, 'Orphan production Handler'
    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join(3)
        assert not self.thread.is_alive() and self.active == 0
        log(stage='server-teardown', serverThreadAlive=False, activeHandlers=0)

def handler_case(module, server, name, line, replies, status, resolve_count, expected_dials, fail_dials=()):
    def run():
        spy = Spy([addresses(r) for r in replies], fail_dials)
        try:
            with patch_transport(module, spy): server.transaction(line, status, spy)
        finally: log(stage='CONNECT-final', name=name, **spy.report())
        assert len(spy.resolves) == resolve_count
        assert [d['sockaddr'] for d in spy.dials] == [list(a) for a in expected_dials]
        assert all(d['resolveCountAtDial'] == 1 for d in spy.dials)
        assert len(spy.payloads) == (1 if status == 200 else 0)
        assert all(s.closed for s in spy.sockets)
    case(name, dict(status=status, resolveCount=resolve_count, dialSockaddrs=[list(a) for a in expected_dials]), run)

WIRE_DENIED = [
    ('non-CONNECT', 'GET https://www.youtube.com/ HTTP/1.1'),
    ('port80', 'CONNECT www.youtube.com:80 HTTP/1.1'),
    ('port8443', 'CONNECT www.youtube.com:8443 HTTP/1.1'),
    ('lookalike', 'CONNECT youtube.com.evil.example:443 HTTP/1.1'),
    ('suffix-lookalike', 'CONNECT evilyoutube.com:443 HTTP/1.1'),
    ('userinfo', 'CONNECT user@www.youtube.com:443 HTTP/1.1'),
    ('userinfo-switch-host', 'CONNECT youtube.com@rr1.googlevideo.com:443 HTTP/1.1'),
    ('private-literal', 'CONNECT 127.0.0.1:443 HTTP/1.1'),
    ('global-literal', 'CONNECT 8.8.8.8:443 HTTP/1.1'),
    ('ipv6-literal', 'CONNECT [::1]:443 HTTP/1.1'),
    ('global-ipv6-literal', 'CONNECT [2001:4860:4860::8888]:443 HTTP/1.1'),
]

def handler_matrix(module):
    server = LabServer(module)
    try:
        for name, line in WIRE_DENIED:
            handler_case(module, server, 'handler:' + name, line, [[G4]], 403, 0, [])
        for name, ips in DNS_DENIED:
            handler_case(module, server, 'handler-dns:' + name, 'CONNECT www.youtube.com:443 HTTP/1.1', [ips], 403, 1, [])
        for name, host, ips, failures in [
            ('global-A-control', 'www.youtube.com', [G4], ()),
            ('global-AAAA-control', 'rr1.googlevideo.com', [G6], ()),
            ('normalized-control', 'WWW.YOUTUBE.COM.', [G4], ()),
            ('fallback-A-A', 'www.youtube.com', [G4, G4_SECOND], (1,)),
            ('fallback-A-AAAA', 'www.youtube.com', [G4, G6], (1,)),
        ]:
            expected = [a[4] for a in addresses(ips)]
            handler_case(module, server, 'handler:' + name, f'CONNECT {host}:443 HTTP/1.1', [ips], 200, 1, expected, failures)
        for name, second in [('private', ['10.0.0.1']), ('mixed-A', [G4, '192.168.1.1']), ('mixed-AAAA-first', ['fc00::1', G4])]:
            def run(name=name, second=second):
                spy = Spy([addresses([G4]), addresses(second)])
                try:
                    with patch_transport(module, spy):
                        server.transaction('CONNECT www.youtube.com:443 HTTP/1.1', 200, spy)
                        first = spy.report(); before = len(spy.dials)
                        server.transaction('CONNECT www.youtube.com:443 HTTP/1.1', 403, spy)
                    log(stage='same-host-recheck', name=name, first=first, secondDns=second,
                        secondResolveDelta=len(spy.resolves)-first['resolveCount'], secondDialDelta=len(spy.dials)-before, final=spy.report())
                    assert len(spy.resolves) == 2 and len(spy.dials) == 1
                    assert spy.dials[0]['sockaddr'] == [G4, 443]
                    assert spy.dials[0]['resolveCountAtDial'] == 1
                    assert [r['host'] for r in spy.resolves] == ['www.youtube.com', 'www.youtube.com']
                finally: log(stage='recheck-teardown', name=name, **spy.report())
            case('recheck:' + name, 'first200/1 numeric dial; second403/new DNS/0 additional dial', run)
    finally: server.close()

def regression(module):
    # Old policy suite imports the already-loaded CURRENT production module, not baked image code.
    assert sys.modules['egress'] is module
    def old_policy():
        spec = importlib.util.spec_from_file_location('legacy_egress_tests', '/lab/tests/egress_test.py')
        legacy = importlib.util.module_from_spec(spec); spec.loader.exec_module(legacy)
        stream = io.StringIO()
        outcome = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(legacy))
        log(stage='legacy-policy', source=module.__file__, testsRun=outcome.testsRun,
            failures=len(outcome.failures), errors=len(outcome.errors), output=stream.getvalue())
        assert outcome.testsRun == 2 and outcome.wasSuccessful()
    case('regression:egress_test.py', '2 original helper tests PASS/current source', old_policy)
    tree = ast.parse(pathlib.Path('/lab/tests/network_policy.py').read_text())
    targets = ast.literal_eval(next(n for n in tree.body if isinstance(n, ast.For)).iter)
    assert targets == ['127.0.0.1:443', '169.254.169.254:443', 'youtube.com.evil.invalid:443', '[::1]:443']
    server = LabServer(module)
    try:
        for target in targets:
            handler_case(module, server, 'regression:negative-CONNECT:' + target,
                         'CONNECT ' + target + ' HTTP/1.1', [[G4]], 403, 0, [])
    finally: server.close()
    log(stage='regression-scope', original='/lab/tests/network_policy.py', negativeTargets=targets,
        externalRoutingProbe='NOT RUN: 8.8.8.8 real routing probe excluded; lab network none')

def syntax():
    for name in [str(SOURCE), '/lab/tests/p18_egress_lab.py', '/lab/tests/egress_test.py', '/lab/tests/network_policy.py']:
        def run(name=name):
            compile(pathlib.Path(name).read_text(), name, 'exec'); log(stage='syntax', path=name, result='PASS')
        case('syntax:' + name, 'Python compile/no pycache/write', run)

def main():
    assert os.environ.get('EGRESS_LAB_GUARD') == 'wed-snap-egress-lab'
    assert os.getuid() == 65534
    assert all(key not in os.environ for key in ['DATABASE_URL', 'REDIS_URL', 'POSTGRES_PASSWORD', 'ADMIN_SECRET', 'EGRESS_DOMAINS'])
    assert sorted(os.listdir('/sys/class/net')) == ['lo'], 'Lab must have ONLY loopback/network none'
    assert len(pathlib.Path('/proc/net/route').read_text().splitlines()) == 1, 'No external IPv4 routing'
    sha = hashlib.sha256(SOURCE.read_bytes()).hexdigest(); assert sha == os.environ['EGRESS_LAB_SHA']
    phase = os.environ['EGRESS_LAB_PHASE']; assert phase in ('All', 'Matrix', 'Regression', 'Syntax')
    fd_before = len(os.listdir('/proc/self/fd'))
    identity = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
    log(stage='guard-before-tests', source=str(SOURCE), sourceSha=sha, python=sys.version.split()[0], uid=os.getuid(),
        pid=os.getpid(), startTicks=identity[19],
        namespace=os.readlink('/proc/self/ns/pid'), interfaces=['lo'], externalRoutes=0, dataServices=False, phase=phase,
        stubs=['socket.getaddrinfo controlled tuple responses', 'socket connector spy backed by socketpair'],
        real=['allowed', 'public_addresses', 'ipaddress.is_global', 'production Handler', 'loopback HTTP CONNECT', 'select/relay'])
    log(stage='matrix-before-tests', allowedHosts=[d for domain in DOMAINS for d in (domain, 'sub.'+domain)],
        deniedHosts=DENIED_HOSTS, dnsAllowed=[[G4], [G4, G4_SECOND], [G6], [G4, G6]], dnsDenied=DNS_DENIED,
        wireDenied=WIRE_DENIED, deniedStatus=403, deniedDialCount=0, pinning='exact numeric sockaddr:443; one DNS per CONNECT',
        fallback=['A-A', 'A-AAAA'], recheck=['private', 'mixed-A', 'mixed-AAAA-first'],
        secondConnect='403/one new resolve/zero additional dial', payloadBytes=len(PAYLOAD), receivedBytes=len(ACK),
        httpTimeout=HTTP_TIMEOUT, cleanupBound=3, outerContainerBound=90)
    try:
        if phase in ('All', 'Syntax'): syntax()
        if phase in ('All', 'Matrix'):
            module = load_source(); policy_matrix(module); handler_matrix(module)
        if phase in ('All', 'Regression'): regression(load_source())
    finally:
        assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == sha
        leaked = [t.name for t in threading.enumerate() if t is not threading.main_thread()]
        # Request threads finish shutdown_request immediately after our activity observation.
        end = time.monotonic() + 3
        while leaked and time.monotonic() < end:
            time.sleep(0.01); leaked = [t.name for t in threading.enumerate() if t is not threading.main_thread()]
        assert not leaked, 'Orphan lab threads: ' + repr(leaked)
        assert len(os.listdir('/proc/self/fd')) == fd_before, 'Socket/file descriptor leak'
        log(stage='lab-teardown', threadsAlive=[], fdBefore=fd_before, fdAfter=len(os.listdir('/proc/self/fd')),
            sourceUnchanged=True, persistentWrites=False)
    passed = sum(r['result'] == 'PASS' for r in results); failed = len(results) - passed
    log(stage='summary', phase=phase, sourceSha=sha, passed=passed, failed=failed, result='PASS' if not failed else 'FAIL',
        failedCases=[r['name'] for r in results if r['result'] == 'FAIL'], InternetTLSRedirectRebindingCertified=False)
    return int(bool(failed))

if __name__ == '__main__':
    sys.exit(main())
