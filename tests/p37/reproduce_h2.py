"""Reproduce F37.2-H2 diagnostic bug in probe_ab.py.
Under the old probe_ab.py logic (lines 61-73):
`finish_read` only finalized when `not data`.
When a caller reads the whole body in one shot via `read(None)` or `read()`,
data is non-empty, so `if not data:` is False. If the caller does not call read()
a second time, markers/decoded_bytes/title are NEVER recorded.
"""
import io, sys

def test_old_logic_oneshot_fails():
    buf = io.BytesIO(b'<html><head><title>Test Title</title></head><body>__UNIVERSAL_DATA_FOR_REHYDRATION__</body></html>')
    row = {'url': 'https://example.com'}
    state = {'n': 0}
    head = bytearray()
    
    orig = buf.read
    def sniff(b):
        if len(head) < 512 * 1024:
            head.extend(b[:512 * 1024 - len(head)])
            
    def finish_read(amt=None):
        data = orig(amt)
        state['n'] += len(data)
        sniff(data)
        if not data:  # OLD LOGIC in probe_ab.py: only updates row when EOF read returns empty bytes
            text = bytes(head).decode('utf-8', 'ignore'); low = text.lower()
            title = text[low.find('<title>') + 7:low.find('</title>')][:100] if '<title>' in low else None
            row.update({'decoded_bytes': state['n'], 'title': title,
                        'has_rehydration_json': '__UNIVERSAL_DATA_FOR_REHYDRATION__' in text})
        return data

    # Caller reads the entire response in a single call read(None), then closes without calling read() again.
    body = finish_read(None)
    assert len(body) > 0
    # In old logic, row is NOT updated!
    is_bug_present = ('decoded_bytes' not in row or 'has_rehydration_json' not in row)
    print("Old logic one-shot read result row:", row)
    print("F37.2-H2 bug reproduced:", is_bug_present)
    if is_bug_present:
        sys.exit(42) # exit 42 proves bug reproduction
    sys.exit(0)

if __name__ == '__main__':
    test_old_logic_oneshot_fails()
