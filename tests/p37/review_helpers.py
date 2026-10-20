"""Actual lab helpers, response-only doubles; no network or yt-dlp requests."""
import io
import unittest
from lab372 import Budget, LimitExceeded, bound_response, sanitize


class Response:
    def __init__(self, body):
        self.body = io.BytesIO(body)
        self.closed = False
        self.requests = []

    def read(self, n=None):
        self.requests.append(n)
        return self.body.read(n)

    def close(self):
        self.closed = True


class Review(unittest.TestCase):
    def test_exact_cap_chunked_eof(self):
        r = Response(b'abcdefgh'); budget = Budget(8, 32)
        state = bound_response(r, budget)
        self.assertEqual(r.read(4) + r.read(4), b'abcdefgh')
        self.assertEqual(r.read(4), b'')
        self.assertEqual(state['error'], None)
        self.assertTrue(state['finalized'])
        self.assertEqual(budget.total, 8)

    def test_exact_aggregate_eof(self):
        budget = Budget(8, 8)
        for body in (b'abcd', b'efgh'):
            r = Response(body); bound_response(r, budget)
            self.assertEqual(r.read(4), body)
            self.assertEqual(r.read(4), b'')
        self.assertEqual(budget.total, 8)

    def test_excess_detected_by_one_byte(self):
        r = Response(b'abcdefghi'); budget = Budget(8, 32)
        bound_response(r, budget)
        self.assertEqual(r.read(8), b'abcdefgh')
        with self.assertRaises(LimitExceeded): r.read(8)
        self.assertEqual(r.requests, [8, 1])
        self.assertEqual(budget.total, 9)
        self.assertTrue(r.closed)

    def test_zero_read_does_not_finalize(self):
        r = Response(b'ab'); state = bound_response(r, Budget(8, 32))
        self.assertEqual(r.read(0), b'')
        self.assertFalse(state['finalized'])
        self.assertEqual(r.read(), b'ab')
        self.assertTrue(state['finalized'])

    def test_error_state_is_sanitized(self):
        r = Response(b'')
        def broken(n):
            raise OSError('https://FAKEUSER:FAKEPASS@example.invalid/p?token=FAKEQUERY')
        r.read = broken
        state = bound_response(r, Budget(8, 32))
        with self.assertRaises(OSError): r.read()
        self.assertNotIn('FAKEPASS', state['error'])
        self.assertNotIn('FAKEQUERY', state['error'])

    def test_invalid_port_redaction_never_throws(self):
        self.assertNotIn('FAKEPASS', sanitize('https://u:FAKEPASS@example.invalid:bad/p?token=q'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
