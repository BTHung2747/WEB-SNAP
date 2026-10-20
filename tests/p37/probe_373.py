"""One bounded metadata analyze per container. A=base; B=base+curl_cffi.
Instrumentation delegates to the pinned yt-dlp dispatcher; it never sends extra requests.
No response bodies/cookies are persisted. Existing upstream challenge solver is disabled.
"""
import datetime
import json
import os
import re
import resource
import signal
import sys
import time
from lab372 import Budget, SafeLogger, bound_response, sanitize

URL = 'https://vt.tiktok.com/ZSbxenGuS/'
DEADLINE = 30
RESPONSE_CAP, AGG_CAP = 8 * 1024 * 1024, 16 * 1024 * 1024


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def response_fields(resp, handler):
    target = getattr(resp, 'extensions', {}).get('impersonate')
    final = sanitize(getattr(resp, 'url', ''), 240)
    match = re.search(r'/(video|photo)/(\d+)', final or '')
    return {
        'actual_handler': handler,
        'effective_target': str(target) if target is not None else None,
        'target_evidence': 'response.extensions.impersonate',
        'status': getattr(resp, 'status', None), 'final_url': final,
        'content_id': match.group(2) if match else None,
        'content_type_in_url': match.group(1) if match else None,
        'headers': {k: sanitize(resp.headers.get(k), 240) for k in
                    ('Content-Type', 'Content-Encoding', 'Content-Length', 'Location', 'Server', 'Date')
                    if resp.headers.get(k) is not None},
    }


def instrument_dispatch(director, rep, budget, responses, started):
    # Exact-version networking/common.py dispatch calls handler.send(request).
    # Wrap that boundary, delegate unchanged, record failures and actual responses.
    for handler in director.handlers.values():
        original = handler.send

        def send(request, original=original, handler=handler):
            row = {'url': sanitize(request.url, 240), 'method': request.method,
                   't': round(time.monotonic() - started, 3),
                   'actual_handler': handler.RH_NAME}
            rep['requests'].append(row)
            try:
                resp = original(request)
            except BaseException as e:
                row['dispatch_error'] = sanitize(type(e).__name__ + ': ' + str(e))
                resp = getattr(e, 'response', None)
                if resp is not None:
                    row.update(response_fields(resp, handler.RH_NAME))
                    resp.close()
                raise
            row.update(response_fields(resp, handler.RH_NAME))
            row['redirect_observed'] = row['url'] != row['final_url']
            responses.append(resp)
            head = bytearray()

            def sniff(b):
                head.extend(b[:max(0, 512 * 1024 - len(head))])

            def finalize(state):
                text = bytes(head).decode('utf-8', 'ignore')
                low = text.lower()
                row.update({
                    'decoded_bytes': state['n'],
                    'has_rehydration_json': '__UNIVERSAL_DATA_FOR_REHYDRATION__' in text,
                    'has_sigi_state': 'SIGI_STATE' in text,
                    'maintenance_marker': 'maintenance' in low,
                    'captcha_marker': any(k in low for k in ('captcha', 'verify-center', 'tiktok-verify')),
                    'challenge_marker': 'wci' in low or 'secsdk' in low,
                    'read_error': state.get('error') if state.get('error') != 'CLOSED' else None,
                })

            length = resp.headers.get('Content-Length')
            if length and length.isdigit() and int(length) > RESPONSE_CAP:
                resp.close()
                raise ValueError('LIMIT_EXCEEDED Content-Length')
            state = bound_response(resp, budget, sniff=sniff, on_finalize=finalize)
            bounded_read = resp.read

            def observed_read(amt=None):
                try:
                    return bounded_read(amt)
                finally:
                    # curl's underlying read may call public close before returning bytes.
                    # Refresh after bounded_read has counted/sniffed them; never reread the body.
                    if amt != 0:
                        finalize(state)

            resp.read = observed_read
            return resp

        handler.send = send


def metadata_outcome(rep):
    result = rep.get('result') or {}
    return 'PASS' if result.get('id') and result.get('formats') and not rep.get('error') else 'FAIL'


def combined_outcome(a, b):
    return {'A': metadata_outcome(a), 'B': metadata_outcome(b),
            'both_failed': metadata_outcome(a) == metadata_outcome(b) == 'FAIL'}


def attempt(arm, target, out):
    import yt_dlp
    from yt_dlp.networking.impersonate import ImpersonateTarget
    from yt_dlp.extractor.tiktok import TikTokBaseIE
    from yt_dlp.utils import ExtractorError
    path = os.path.join(out, 'ab-attempt-%s.json' % arm)
    # Exclusive reservation before any extraction: never reuse an attempt.
    with open(path, 'x', encoding='utf-8') as f:
        f.write(json.dumps({'arm': arm, 'reserved_utc': utc(), 'metadata_status': 'NOT_COMPLETED'}))
    rep = {'arm': arm, 'original_url': URL, 'requested_target': target or None,
           'start_utc': utc(), 'yt_dlp': yt_dlp.version.__version__, 'requests': [],
           'cookie_jar': 'fresh independent in-memory jar; no supplied cookies',
           'response_cap': RESPONSE_CAP, 'aggregate_cap': AGG_CAP, 'deadline_sec': DEADLINE}
    log = SafeLogger()
    budget = Budget(RESPONSE_CAP, AGG_CAP)
    responses = []
    t0 = time.monotonic()

    def alarm(*_):
        raise TimeoutError('TOTAL_ANALYZE_DEADLINE_30s')

    def no_solver(*_):
        rep['solver_blocked'] = True
        raise ExtractorError('LAB_NO_SOLVER: webpage lacks parsed rehydration metadata; challenge solving disabled')

    original_solver = getattr(TikTokBaseIE, '_solve_challenge_and_set_cookies', None)
    if original_solver is not None:
        TikTokBaseIE._solve_challenge_and_set_cookies = no_solver
    opts = {'proxy': os.environ['MEDIA_PROXY'], 'quiet': True, 'noprogress': True,
            'no_warnings': False, 'logger': log, 'noplaylist': True, 'cachedir': False,
            'socket_timeout': 10, 'retries': 1, 'fragment_retries': 1, 'extractor_retries': 0,
            'js_runtimes': {'node': {}}, 'remote_components': []}
    signal.signal(signal.SIGALRM, alarm)
    signal.setitimer(signal.ITIMER_REAL, DEADLINE)
    try:
        if yt_dlp.version.__version__ != '2026.08.19':
            raise ValueError('Unexpected yt-dlp version')
        if arm == 'B':
            opts['impersonate'] = ImpersonateTarget.from_str(target)
        with yt_dlp.YoutubeDL(opts) as ydl:
            avail = [str(t) for t, _ in ydl._get_available_impersonate_targets()]
            rep['available_targets'] = avail
            rep['effective_options'] = {k: str(ydl.params.get(k)) for k in opts if k != 'logger'}
            if arm == 'A' and avail:
                raise ValueError('Invalid comparison: A unexpectedly has impersonation targets')
            if arm == 'B' and target not in avail:
                raise ValueError('B target not available; no request made')
            if list(ydl.cookiejar):
                raise ValueError('Cookie jar must be fresh')
            instrument_dispatch(ydl._request_director, rep, budget, responses, t0)
            info = ydl.extract_info(URL, download=False)
            fm = []
            for f in info.get('formats', []):
                row = {k: f.get(k) for k in ('format_id', 'format_note', 'ext', 'protocol', 'vcodec',
                                            'acodec', 'height', 'width', 'filesize', 'filesize_approx', 'has_drm')}
                note = str(f.get('format_note') or '').lower()
                row['watermark_class'] = 'watermarked' if 'watermark' in note or f.get('format_id') == 'download' else 'unknown'
                row['source_url_sanitized'] = sanitize(f.get('url'), 240)
                fm.append(row)
            rep['result'] = {'id': info.get('id'), 'type': info.get('_type'),
                             'extractor': info.get('extractor_key'), 'duration': info.get('duration'),
                             'webpage_url': sanitize(info.get('webpage_url'), 240), 'formats': fm}
    except BaseException as e:
        rep['error'] = sanitize(type(e).__name__ + ': ' + str(e), 600)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        for response in responses:
            try:
                response.close()
            except Exception:
                pass
        if original_solver is not None:
            TikTokBaseIE._solve_challenge_and_set_cookies = original_solver
    rep.update({'logger': log.lines, 'seconds': round(time.monotonic() - t0, 3),
                'total_decoded_bytes': budget.total, 'end_utc': utc(),
                'process_peak_rss_kib': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                'metadata_status': metadata_outcome(rep), 'harness_status': 'COMPLETED',
                'watermark_verified': False})
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(rep, f, indent=2, ensure_ascii=False)
    print(json.dumps({k: rep[k] for k in ('arm', 'metadata_status', 'harness_status', 'seconds')}))
    return rep


if __name__ == '__main__':
    arm = os.environ['AB_ARM']
    if arm not in ('A', 'B'):
        raise ValueError('Unknown arm')
    rep = attempt(arm, os.environ.get('AB_TARGET', ''), '/out')
    # Exit20 is metadata failure with a completed harness. Infrastructure exceptions remain nonzero separately.
    sys.exit(0 if rep['metadata_status'] == 'PASS' else 20)
