"""Only fixed headers/API, fresh options and post-autoclose diagnostics. Network none."""
import io
import json
import os
import types
import unittest
import yt_dlp
from yt_dlp.networking import Request
from yt_dlp.networking.impersonate import ImpersonateTarget
from lab372 import Budget
from probe_374 import FIXED_HEADERS, TARGET, configuration_sha, fixed_configuration, fixed_options, instrument_dispatch


class Tests(unittest.TestCase):
    def test_two_instances_have_same_fixed_headers_and_target(self):
        records = []
        for _ in range(2):
            with yt_dlp.YoutubeDL(fixed_options()) as ydl:
                self.assertEqual(yt_dlp.version.__version__, '2026.08.19')
                self.assertEqual(dict(ydl.params['http_headers']), FIXED_HEADERS)
                self.assertEqual(str(ydl.params['impersonate']), TARGET)
                self.assertEqual(list(ydl.cookiejar), [])
                handler = ydl._request_director.handlers['CurlCFFI']
                req = Request('https://vt.tiktok.com/ZSbxenGuS/', extensions={'impersonate': ImpersonateTarget.from_str(TARGET)})
                records.append({'effective_headers': dict(ydl.params['http_headers']),
                                'prepared_headers': handler._get_impersonate_headers(req),
                                'target': str(handler._get_request_target(req))})
        self.assertEqual(records[0], records[1])
        self.assertEqual(records[0]['prepared_headers']['User-Agent'], FIXED_HEADERS['User-Agent'])
        with open('/out/offline-config-proof.json', 'w') as f:
            json.dump({'network': 'none', 'no_request_made': True,
                       'configuration': fixed_configuration(), 'configuration_sha256': configuration_sha(),
                       'instances': records}, f, indent=2)

    def test_options_are_fresh_when_library_mutates_params(self):
        first = fixed_options()
        first['http_headers']['User-Agent'] = 'mutated fixture'
        self.assertEqual(fixed_options()['http_headers'], FIXED_HEADERS)
        self.assertEqual(configuration_sha(), configuration_sha())

    def test_autoclose_final_bytes_markers_and_aggregate(self):
        class AutoClose(io.BytesIO):
            def read(self, size=-1):
                data = super().read(size)
                self.close()
                return data
        body = b'<html>__UNIVERSAL_DATA_FOR_REHYDRATION__</html>'
        r = AutoClose(body)
        r.extensions = {'impersonate': 'chrome-test'}
        r.url = 'https://www.tiktok.com/@user/video/123'
        r.status = 200
        r.headers = {}
        handler = types.SimpleNamespace(RH_NAME='curl_cffi', send=lambda req: r,
                                        _get_impersonate_headers=lambda req: dict(FIXED_HEADERS))
        rep = {'requests': []}
        budget = Budget(1024, 2048)
        instrument_dispatch(types.SimpleNamespace(handlers={'CurlCFFI': handler}), rep, budget, [], 0)
        req = types.SimpleNamespace(url=r.url, method='GET')
        self.assertEqual(handler.send(req).read(), body)
        self.assertEqual(sum(row['decoded_bytes'] for row in rep['requests']), budget.total)
        self.assertTrue(rep['requests'][0]['has_rehydration_json'])
        self.assertEqual(rep['requests'][0]['effective_target'], 'chrome-test')


if __name__ == '__main__':
    unittest.main(verbosity=2)
