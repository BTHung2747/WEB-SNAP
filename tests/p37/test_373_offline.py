"""Small fixtures for changed instrumentation/outcome. No source request."""
import io
import types
import unittest
from lab372 import Budget
from probe_373 import combined_outcome, instrument_dispatch, response_fields


class Tests(unittest.TestCase):
    def test_underlying_read_closes_response_before_return(self):
        class AutoClose(io.BytesIO):
            def read(self, size=-1):
                data = super().read(size)
                self.close()  # curl adapter can call public close while original_read is in progress.
                return data
        r = AutoClose(b'<html>__UNIVERSAL_DATA_FOR_REHYDRATION__</html>')
        r.extensions = {'impersonate': 'chrome-test'}
        r.url = 'https://www.tiktok.com/@user/video/123'
        r.status = 200
        r.headers = {}
        h = types.SimpleNamespace(RH_NAME='curl_cffi', send=lambda req: r)
        rep = {'requests': []}
        budget = Budget(1024, 2048)
        instrument_dispatch(types.SimpleNamespace(handlers={'CurlCFFI': h}), rep, budget, [], 0)
        req = types.SimpleNamespace(url=r.url, method='GET')
        h.send(req).read()
        self.assertEqual(rep['requests'][0]['decoded_bytes'], budget.total)
        self.assertTrue(rep['requests'][0]['has_rehydration_json'])

    def test_extension_target_and_safe_headers(self):
        r = types.SimpleNamespace(extensions={'impersonate': 'chrome-136:windows-10'},
                                  url='https://www.tiktok.com/@user/video/123?token=SECRET',
                                  status=200, headers={'Content-Type': 'text/html', 'Set-Cookie': 'SECRET'})
        row = response_fields(r, 'curl_cffi')
        self.assertEqual(row['effective_target'], 'chrome-136:windows-10')
        self.assertEqual(row['content_id'], '123')
        self.assertNotIn('SECRET', str(row))
        self.assertNotIn('Set-Cookie', row['headers'])

    def test_real_dispatch_boundary_and_one_shot(self):
        r = io.BytesIO(b'<html>__UNIVERSAL_DATA_FOR_REHYDRATION__</html>')
        r.extensions = {'impersonate': 'chrome-test'}
        r.url = 'https://www.tiktok.com/@user/video/123'
        r.status = 200
        r.headers = {'Content-Encoding': 'gzip'}
        called = []
        h = types.SimpleNamespace(RH_NAME='curl_cffi', send=lambda req: (called.append(req), r)[1])
        director = types.SimpleNamespace(handlers={'CurlCFFI': h})
        rep = {'requests': []}
        budget = Budget(1024, 2048)
        instrument_dispatch(director, rep, budget, [], 0)
        req = types.SimpleNamespace(url='https://vt.tiktok.com/short/', method='GET')
        self.assertEqual(h.send(req).read(), b'<html>__UNIVERSAL_DATA_FOR_REHYDRATION__</html>')
        self.assertEqual(called, [req])
        row = rep['requests'][0]
        self.assertEqual(row['actual_handler'], 'curl_cffi')
        self.assertTrue(row['has_rehydration_json'])
        self.assertTrue(row['redirect_observed'])
        self.assertEqual(row['decoded_bytes'], budget.total)

    def test_metadata_failure_is_not_process_success(self):
        fail = {'harness_status': 'COMPLETED', 'error': 'extractor failed'}
        passed = {'result': {'id': '123', 'formats': [{'format_id': 'play'}]}}
        self.assertEqual(combined_outcome(fail, fail), {'A': 'FAIL', 'B': 'FAIL', 'both_failed': True})
        self.assertEqual(combined_outcome(fail, passed)['B'], 'PASS')
        self.assertEqual(combined_outcome({}, {'result': {'id': '123', 'formats': []}})['B'], 'FAIL')


if __name__ == '__main__':
    unittest.main(verbosity=2)
