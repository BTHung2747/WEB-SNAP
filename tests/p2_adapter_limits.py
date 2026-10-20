"""Components of production media_adapter.py; only transport/extractor/probe stubbed.

No network, limit-function mocks, or prebuilt LIMIT_EXCEEDED fixture responses.
Small real files live only in this guarded test container's /tmp.
"""
import contextlib
import copy
import hashlib
import io
import json
import math
import os
import pathlib
import runpy
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from unittest.mock import patch

import yt_dlp

assert os.environ.get('P3_TEST_GUARD') == 'wed-snap-p3-test'
assert os.environ.get('APP_ORIGIN') == 'http://localhost:5174'
assert os.environ.get('REDIS_URL') == 'redis://redis:6379/14'
assert os.environ.get('DATABASE_URL', '').endswith('/wed_snap_p3_test')
SOURCE = pathlib.Path('/app/production/media_adapter.py')
assert SOURCE.is_file()
INPUT, OUTPUT, DURATION = 8192, 4096, 600
MISSING = object()
failures = []
case_count = 0

def log(**values):
    print(json.dumps({'date': datetime.now(timezone.utc).isoformat(), 'componentOnly': True,
                      'productionSource': str(SOURCE), **values}, allow_nan=False), flush=True)

def label(value):
    if value is MISSING:
        return 'missing'
    if isinstance(value, float) and not math.isfinite(value):
        return 'NaN' if math.isnan(value) else 'infinite'
    return value

def test(name, fn):
    global case_count
    case_count += 1
    try:
        fn()
        log(test=name, result='PASS')
    except AssertionError as error:
        failures.append(name)
        log(test=name, result='FAIL', assertion=str(error))

def info(duration=30, filesize=None):
    value = {'title': 'Production component fixture', 'duration': duration,
             'formats': [{'format_id': '18', 'ext': 'mp4', 'protocol': 'https',
                          'vcodec': 'avc1', 'acodec': 'mp4a', 'height': 360,
                          'filesize': filesize}]}
    if duration is MISSING:
        del value['duration']
    return value

root = tempfile.TemporaryDirectory(prefix='p2-adapter-components-')
invocations = 0

def run_adapter(phase='prepare', metadata=None, output_bytes=128, probe_duration='30'):
    global invocations
    invocations += 1
    target = pathlib.Path(root.name) / f'case-{invocations}'
    calls = {'extract': 0, 'download': 0, 'probe': 0}
    metadata = info() if metadata is None else metadata
    def extract(_self, _url, download=False):
        assert download is False
        calls['extract'] += 1
        return copy.deepcopy(metadata)
    def download(_self, _info, download=True):
        assert download is True
        calls['download'] += 1
        (target / 'media.mp4').write_bytes(bytes((i * 19 + 5) & 255 for i in range(output_bytes)))
    def probe(command, **kwargs):
        assert command[0] == 'ffprobe', 'Only the local probe transport is stubbed'
        assert pathlib.Path(command[-1]) == target / 'media.mp4'
        calls['probe'] += 1
        value = {'streams': [{'codec_type': 'video', 'height': 360}, {'codec_type': 'audio'}], 'format': {}}
        if probe_duration is not MISSING:
            value['format']['duration'] = probe_duration
        return subprocess.CompletedProcess(command, 0, json.dumps(value), '')
    captured = io.StringIO()
    namespace, exit_code = None, 0
    with patch.dict(os.environ, {'ADAPTER_MAX_INPUT': str(INPUT), 'ADAPTER_MAX_OUTPUT': str(OUTPUT), 'ADAPTER_MAX_DURATION': str(DURATION)}), \
         patch.object(sys, 'argv', [str(SOURCE), phase, 'https://youtu.be/localtest01', str(target), '18']), \
         patch.object(yt_dlp.YoutubeDL, 'extract_info', extract), \
         patch.object(yt_dlp.YoutubeDL, 'process_ie_result', download), \
         patch.object(subprocess, 'run', probe), contextlib.redirect_stdout(captured):
        try:
            namespace = runpy.run_path(str(SOURCE), run_name='__main__')
        except SystemExit as error:
            exit_code = error.code
    result = json.loads(captured.getvalue().strip())
    actual = (target / 'media.mp4').stat().st_size if (target / 'media.mp4').exists() else 0
    return {'data': result, 'exit': exit_code, 'calls': calls, 'actualBytes': actual, 'namespace': namespace}

try:
    log(stage='guard-matrix', project='wed-snap-p3-test', database='wed_snap_p3_test', redisDb=14,
        sourceSha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(), python=sys.version.split()[0],
        ytDlp=yt_dlp.version.__version__, inputCap=INPUT, outputCap=OUTPUT, durationCap=DURATION,
        productionHardCaps={'input': 262144000, 'output': 209715200, 'duration': 600}, detectionAllowanceBytes=1)
    loaded = run_adapter('analyze')
    assert loaded['exit'] == 0
    # runpy returns a copy; function globals are the live production namespace.
    ns = loaded['namespace']['valid'].__globals__
    ns['phase'] = 'prepare'
    Rejected = ns['Rejected']

    class Response:
        def __init__(self, body, headers=None, chunk=None):
            self.body = body
            self.headers = headers or {}
            self.chunk = chunk
            self.offset = 0
            self.read_requests = []
            self.closed = False
        def read(self, amount=None):
            self.read_requests.append(amount)
            amount = len(self.body) if amount is None or amount < 0 else amount
            if self.chunk:
                amount = min(amount, self.chunk)
            data = self.body[self.offset:self.offset + amount]
            self.offset += len(data)
            return data
        def close(self):
            self.closed = True

    def read_case(size, chunked):
        ns['network_bytes'] = 0
        response = Response(b'x' * size, {'Transfer-Encoding': 'chunked'} if chunked else {}, 700 if chunked else None)
        code, delivered = None, 0
        with patch.object(yt_dlp.YoutubeDL, 'urlopen', lambda _self, _request: response):
            with ns['BoundedYoutubeDL']({'quiet': True, 'no_warnings': True}) as ydl:
                bounded = ydl.urlopen('https://local.invalid/component')
                try:
                    while True:
                        data = bounded.read(4096)
                        if not data:
                            break
                        delivered += len(data)
                except Rejected as error:
                    code = str(error)
        auto_closed = response.closed
        response.close()
        log(stage='input-body', bodyBytes=size, transport='chunked' if chunked else 'no-content-length', cap=INPUT,
            observedBytes=response.offset, globalBytes=ns['network_bytes'], deliveredBytes=delivered,
            readRequests=response.read_requests, autoClosed=auto_closed, responseClosed=response.closed, code=code,
            detectionAllowanceBytes=1)
        assert response.offset == min(size, INPUT + 1)
        assert ns['network_bytes'] == response.offset
        assert code == ('LIMIT_EXCEEDED' if size > INPUT else None)
        assert auto_closed == (size > INPUT)

    for chunked in (False, True):
        for size in (INPUT - 1, INPUT, INPUT + 1):
            test(f'input-{"chunked" if chunked else "no-length"}-{size}', lambda n=size, c=chunked: read_case(n, c))

    def oversized_header():
        ns['network_bytes'] = 0
        response = Response(b'x' * 16, {'Content-Length': str(INPUT + 1)})
        code = None
        with patch.object(yt_dlp.YoutubeDL, 'urlopen', lambda _self, _request: response):
            with ns['BoundedYoutubeDL']({'quiet': True, 'no_warnings': True}) as ydl:
                try:
                    ydl.urlopen('https://local.invalid/component')
                except Rejected as error:
                    code = str(error)
        log(stage='input-content-length', declaredBytes=INPUT + 1, cap=INPUT, readRequests=response.read_requests,
            observedBytes=response.offset, responseClosed=response.closed, code=code)
        assert code == 'LIMIT_EXCEEDED'
        assert response.closed and response.offset == 0 and response.read_requests == []
    test('input-content-length-reject-before-read', oversized_header)

    def cumulative_response():
        ns['network_bytes'] = 0
        first = Response(b'a' * (INPUT - 1))
        second = Response(b'b' * 128)
        code = None
        with ns['BoundedYoutubeDL']({'quiet': True, 'no_warnings': True}) as ydl:
            with patch.object(yt_dlp.YoutubeDL, 'urlopen', lambda _self, _request: first):
                bounded = ydl.urlopen('https://local.invalid/fragment-one')
                assert len(bounded.read()) == INPUT - 1
                bounded.close()
            with patch.object(yt_dlp.YoutubeDL, 'urlopen', lambda _self, _request: second):
                bounded = ydl.urlopen('https://local.invalid/fragment-two')
                try:
                    bounded.read(4096)
                except Rejected as error:
                    code = str(error)
        log(stage='input-cumulative-response', cap=INPUT, firstObservedBytes=first.offset,
            secondBodyBytes=128, secondObservedBytes=second.offset, observedBytes=ns['network_bytes'],
            secondReadRequests=second.read_requests, responsesClosed=[first.closed, second.closed],
            code=code, detectionAllowanceBytes=1)
        assert code == 'LIMIT_EXCEEDED' and second.closed
        assert second.offset == 2 and ns['network_bytes'] == INPUT + 1, 'Aggregate budget may consume only cap+1 detection byte'
    test('input-cumulative-response-detection-allowance', cumulative_response)

    def progress_case(size):
        ns['counts'] = {}
        code = None
        ns['hook']({'filename': 'video-fragment', 'downloaded_bytes': 4096})
        # Repeated progress for one file must not charge its previous bytes twice.
        ns['hook']({'filename': 'video-fragment', 'downloaded_bytes': 4096})
        try:
            ns['hook']({'filename': 'audio-fragment', 'downloaded_bytes': size - 4096})
        except Rejected as error:
            code = str(error)
        log(stage='input-progress-hook', cap=INPUT, downloadedBytes=sum(ns['counts'].values()), fragments=2, code=code)
        assert sum(ns['counts'].values()) == size
        assert code == ('LIMIT_EXCEEDED' if size > INPUT else None)
    for size in (INPUT - 1, INPUT, INPUT + 1):
        test(f'input-progress-hook-{size}', lambda n=size: progress_case(n))

    def metadata_duration(value):
        code = None
        try:
            ns['valid'](info(value))
        except Rejected as error:
            code = str(error)
        allowed = value is not MISSING and isinstance(value, (int, float)) and math.isfinite(value) and value <= DURATION
        log(stage='duration-metadata-valid', duration=label(value), cap=DURATION, code=code)
        assert code == (None if allowed else 'LIMIT_EXCEEDED')
    for value in (599, 600, 601, MISSING, None, float('nan')):
        test(f'metadata-duration-{label(value)}', lambda v=value: metadata_duration(v))

    def prepare_recheck(value):
        outcome = run_adapter(metadata=info(value))
        log(stage='prepare-metadata-recheck', duration=label(value), cap=DURATION, exit=outcome['exit'],
            code=outcome['data'].get('error'), calls=outcome['calls'])
        assert outcome['exit'] == 1 and outcome['data']['error'] == 'LIMIT_EXCEEDED'
        assert outcome['calls']['download'] == 0
    for value in (601, MISSING):
        test(f'prepare-metadata-recheck-{label(value)}', lambda v=value: prepare_recheck(v))

    def probed_duration(value):
        outcome = run_adapter(probe_duration=value)
        allowed = value in ('599', '600')
        log(stage='duration-post-probe', metadataDuration=30, probedDuration=label(value), cap=DURATION,
            outputBytes=outcome['actualBytes'], exit=outcome['exit'], code=outcome['data'].get('error'), calls=outcome['calls'])
        assert outcome['calls'] == {'extract': 1, 'download': 1, 'probe': 1}
        assert outcome['exit'] == (0 if allowed else 1)
        assert outcome['data'].get('error') == (None if allowed else 'LIMIT_EXCEEDED')
    for value in ('599', '600', '601', MISSING, None, 'N/A', 'NaN'):
        test(f'post-probe-duration-{label(value)}', lambda v=value: probed_duration(v))

    def output_size(size):
        outcome = run_adapter(output_bytes=size)
        log(stage='output-stat-after-download', cap=OUTPUT, actualBytes=outcome['actualBytes'],
            metadataFilesize=None, exit=outcome['exit'], code=outcome['data'].get('error'), calls=outcome['calls'])
        assert outcome['actualBytes'] == size and outcome['calls']['download'] == 1
        assert outcome['exit'] == (1 if size > OUTPUT else 0)
        assert outcome['data'].get('error') == ('LIMIT_EXCEEDED' if size > OUTPUT else None)
        assert outcome['calls']['probe'] == (0 if size > OUTPUT else 1)
        if size <= OUTPUT:
            assert outcome['data']['size'] == size
    for size in (OUTPUT - 1, OUTPUT, OUTPUT + 1):
        test(f'output-stat-{size}', lambda n=size: output_size(n))

    def filesize_prefilter():
        outcome = run_adapter(metadata=info(filesize=OUTPUT + 1), output_bytes=OUTPUT + 1)
        log(stage='metadata-filesize-prefilter', cap=OUTPUT, metadataFilesize=OUTPUT + 1,
            code=outcome['data'].get('error'), calls=outcome['calls'], actualBytes=outcome['actualBytes'])
        assert outcome['data']['error'] == 'FORMAT_UNAVAILABLE'
        assert outcome['calls']['download'] == 0 and outcome['actualBytes'] == 0
    test('metadata-filesize-prefilter-distinct-branch', filesize_prefilter)
    log(stage='summary', caseCount=case_count, failedCases=failures, result='FAIL' if failures else 'PASS',
        noNetwork=True, detectionAllowanceBytes=1)
finally:
    root.cleanup()
if failures:
    raise SystemExit(1)
