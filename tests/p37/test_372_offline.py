"""Offline fixtures for P37.2 helpers. No network. Exit code != 0 on failure."""
import io, sys
sys.path.insert(0, '/p37')
from lab372 import sanitize, Budget, bound_response, LimitExceeded

results = []


def case(name, fn):
    try:
        fn()
        results.append((name, 'PASS'))
    except Exception as e:  # noqa
        results.append((name, 'FAIL ' + type(e).__name__ + ': ' + str(e)[:120]))


class Fake:
    """Records the size actually requested from the underlying stream."""
    def __init__(self, data=b'', exc=None):
        if isinstance(data, int):
            data = b'x' * data
        self.buf = io.BytesIO(data)
        self.requested = []
        self.closed = False
        self.exc = exc

    def read(self, amt=None):
        self.requested.append(amt)
        if self.exc:
            raise self.exc
        return self.buf.read() if amt is None else self.buf.read(amt)

    def close(self):
        self.closed = True


def t_clamp_none():
    r = Fake(10_000); b = Budget(100, 1000); bound_response(r, b)
    try:
        r.read(None)
    except LimitExceeded:
        pass
    else:
        raise AssertionError('no raise')
    assert r.requested == [101], r.requested  # never asked for more than cap+1
    assert r.closed


def t_clamp_big_amt():
    r = Fake(10_000); b = Budget(100, 1000); bound_response(r, b)
    try:
        r.read(1_000_000)
    except LimitExceeded:
        pass
    assert r.requested == [101], r.requested


def t_under_cap():
    r = Fake(50); b = Budget(100, 1000); bound_response(r, b)
    assert len(r.read(None)) == 50 and not r.closed


def t_aggregate():
    b = Budget(100, 120); a = Fake(100); c = Fake(100); bound_response(a, b); bound_response(c, b)
    assert len(a.read(None)) == 100
    try:
        c.read(None)
    except LimitExceeded:
        assert c.requested == [21], c.requested
    else:
        raise AssertionError('aggregate not enforced')


def t_sanitize():
    s = sanitize('GET https://user:secretpass@www.tiktok.com:8443/@a/video/1?msToken=ABC&x=1#f failed; cookie: sid=1; token=zzz Authorization: Bearer q')
    for bad in ('secretpass', 'msToken=ABC', 'x=1', 'sid=1', 'zzz', 'Bearer'):
        assert bad not in s, (bad, s)
    assert 'tiktok.com:8443/@a/video/1' in s
    assert '[q-redacted]' in s


def t_oneshot_finalize():
    # Caller reads full body in a single read(None) call and never calls read() again
    content = b'<html><head><title>My Video Title</title></head><body>__UNIVERSAL_DATA_FOR_REHYDRATION__</body></html>'
    r = Fake(content)
    b = Budget(10_000, 50_000)
    finalized_state = {}

    def on_fin(st):
        finalized_state.update(st)

    bound_response(r, b, on_finalize=on_fin)
    body = r.read(None)
    assert len(body) == len(content)
    # Must be finalized immediately without requiring another empty read!
    assert finalized_state.get('finalized') is True
    assert finalized_state.get('n') == len(content)


def t_chunked_finalize():
    # Caller reads in 20-byte chunks until EOF
    content = b'1234567890' * 10 # 100 bytes
    r = Fake(content)
    b = Budget(10_000, 50_000)
    finalized_state = {}

    def on_fin(st):
        finalized_state.update(st)

    bound_response(r, b, on_finalize=on_fin)
    chunks = []
    while True:
        chunk = r.read(20)
        if not chunk:
            break
        chunks.append(chunk)
    assert b''.join(chunks) == content
    assert finalized_state.get('finalized') is True
    assert finalized_state.get('n') == 100


def t_error_finalize():
    # An exception is raised during stream read
    r = Fake(data=b'hello', exc=RuntimeError('Stream broke'))
    b = Budget(10_000, 50_000)
    finalized_state = {}

    def on_fin(st):
        finalized_state.update(st)

    bound_response(r, b, on_finalize=on_fin)
    try:
        r.read(10)
    except RuntimeError:
        pass
    else:
        raise AssertionError('did not raise RuntimeError')
    assert finalized_state.get('finalized') is True
    assert 'Stream broke' in str(finalized_state.get('error'))


def t_close_finalize():
    # Caller reads partially, then closes
    content = b'abcdefghijklmnopqrstuvwxyz'
    r = Fake(content)
    b = Budget(10_000, 50_000)
    finalized_state = {}

    def on_fin(st):
        finalized_state.update(st)

    bound_response(r, b, on_finalize=on_fin)
    data = r.read(5)
    assert len(data) == 5
    assert not finalized_state.get('finalized')
    r.close()
    assert finalized_state.get('finalized') is True
    assert finalized_state.get('n') == 5


def t_cap_exceeded_finalize():
    # Response exceeds budget cap
    r = Fake(1000)
    b = Budget(50, 100)
    finalized_state = {}

    def on_fin(st):
        finalized_state.update(st)

    bound_response(r, b, on_finalize=on_fin)
    try:
        r.read(None)
    except LimitExceeded:
        pass
    assert finalized_state.get('finalized') is True
    assert finalized_state.get('error') == 'LIMIT_EXCEEDED'


case('read(None) clamped before read', t_clamp_none)
case('huge amt clamped before read', t_clamp_big_amt)
case('under cap passes', t_under_cap)
case('aggregate budget enforced + clamped', t_aggregate)
case('sanitize removes query/secrets/headers/userinfo', t_sanitize)
case('one-shot read finalizes markers and bytes', t_oneshot_finalize)
case('chunked read finalizes on EOF', t_chunked_finalize)
case('error during read triggers finalize with error', t_error_finalize)
case('explicit close triggers finalize', t_close_finalize)
case('cap exceeded triggers finalize and close', t_cap_exceeded_finalize)

for n, r in results:
    print(r.split()[0], n, r if r != 'PASS' else '')
sys.exit(0 if all(r == 'PASS' for _, r in results) else 1)
