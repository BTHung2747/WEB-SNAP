"""Verify F37.2-H2 diagnostic fix:
When caller reads one-shot via read(None) or read() and closes,
markers and decoded_bytes are properly finalized without needing a second empty read.
"""
import io, sys
sys.path.insert(0, 'tests/p37')
from lab372 import Budget, bound_response, sanitize

def test_fixed_logic():
    content = b'<html><head><title>Fixed Title</title></head><body>__UNIVERSAL_DATA_FOR_REHYDRATION__</body></html>'
    class FakeResp:
        def __init__(self, data):
            self.buf = io.BytesIO(data)
            self.closed = False
        def read(self, amt=None):
            return self.buf.read() if amt is None else self.buf.read(amt)
        def close(self):
            self.closed = True

    resp = FakeResp(content)
    row = {'url': 'https://example.com'}
    budget = Budget(10_000, 50_000)
    head = bytearray()

    def sniff(b):
        if len(head) < 512 * 1024:
            head.extend(b[:512 * 1024 - len(head)])

    def compute_markers(state):
        text = bytes(head).decode('utf-8', 'ignore'); low = text.lower()
        title = text[low.find('<title>') + 7:low.find('</title>')][:100] if '<title>' in low else None
        row.update({
            'decoded_bytes': state['n'],
            'title': sanitize(title, 100) if title else None,
            'has_rehydration_json': '__UNIVERSAL_DATA_FOR_REHYDRATION__' in text,
            'has_sigi_state': 'SIGI_STATE' in text
        })

    bound_response(resp, budget, sniff=sniff, on_finalize=compute_markers)

    # Caller reads once with None, then closes
    body = resp.read(None)
    assert len(body) == len(content)

    print("Result row after single read(None):", row)
    assert 'decoded_bytes' in row, "decoded_bytes missing!"
    assert row['decoded_bytes'] == len(content)
    assert row['has_rehydration_json'] is True
    assert row['title'] == 'Fixed Title'
    print("F37.2-H2 FIX VERIFIED: All markers recorded on single-shot read.")

if __name__ == '__main__':
    test_fixed_logic()
