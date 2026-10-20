"""P37.2 A/B analyze attempts (PREPARED, NOT EXECUTED: needs approved lab image with curl_cffi).
One yt-dlp analyze per arm on the owner's short URL, instrumented; max 2 attempts total (pass files refuse more).
A = production-equivalent options (default transport). B = same options + impersonate=<AB_TARGET>.
Nothing besides the extractor's own requests is made (no extra prefetch). Output is sanitized, no body persisted.
"""
import sys, os, re, json, time, signal, datetime
sys.path.insert(0, '/p37')
from lab372 import sanitize, Budget, bound_response, SafeLogger, LimitExceeded

URL = 'https://vt.tiktok.com/ZSbxenGuS/'
OUT = '/out'
PROXY = os.environ.get('MEDIA_PROXY', 'http://egress:8888')
TARGET = os.environ.get('AB_TARGET', '')
DEADLINE = 30
RESPONSE_CAP, AGG_CAP = 8 * 1024 * 1024, 16 * 1024 * 1024   # not wider than production analyze (8 MiB / response)


class Deadline(Exception):
    pass


def _alarm(*_):
    raise Deadline('deadline %ss' % DEADLINE)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def classify(f):
    note = (f.get('format_note') or '').lower()
    fid = str(f.get('format_id') or '').lower()
    if 'watermark' in note or fid == 'download':
        return 'watermarked'
    return 'unknown'   # source-field based only; never evidence of "no watermark"


def attempt(arm):
    import yt_dlp
    from yt_dlp.networking.impersonate import ImpersonateTarget
    path = os.path.join(OUT, 'ab-attempt-%s.json' % arm)
    if os.path.exists(path):
        print(json.dumps({'refused': 'attempt %s already exists' % arm})); return None
    rep = {'arm': arm, 'target': TARGET if arm == 'B' else None, 'start_utc': utc(), 'yt_dlp': yt_dlp.version.__version__, 'requests': []}
    log = SafeLogger(); budget = Budget(RESPONSE_CAP, AGG_CAP)

    class Instrumented(yt_dlp.YoutubeDL):
        def urlopen(self, req):
            row = {'url': sanitize(getattr(req, 'url', req), 160), 't': round(time.monotonic() - t0, 2)}
            rep['requests'].append(row)
            resp = super().urlopen(req)
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
                    'has_sigi_state': 'SIGI_STATE' in text,
                    'maintenance_marker': 'maintenance' in low,
                    'captcha_marker': any(k in low for k in ('captcha', 'verify-center', 'tiktok-verify'))
                })
                if state.get('error'):
                    row['read_error'] = sanitize(state['error'])

            state = bound_response(resp, budget, sniff=sniff, on_finalize=compute_markers)

            # Determine actual request handler & effective target if verifiable, else 'unknown'
            # Do NOT deduce from response class name!
            handler_name = 'unknown'
            effective_target = 'unknown'
            handler_obj = getattr(resp, 'handler', None) or getattr(resp, 'request_handler', None) or getattr(req, 'handler', None)
            if handler_obj:
                handler_name = getattr(handler_obj, 'RH_NAME', None) or type(handler_obj).__name__
                effective_target = str(getattr(handler_obj, '_impersonate_target', None) or getattr(handler_obj, 'impersonate_target', None) or 'unknown')

            row.update({
                'status': getattr(resp, 'status', None),
                'final_url': sanitize(getattr(resp, 'url', ''), 160),
                'content_type': resp.headers.get('Content-Type') if hasattr(resp, 'headers') else None,
                'content_encoding': resp.headers.get('Content-Encoding') if hasattr(resp, 'headers') else None,
                'actual_handler': handler_name,
                'effective_target': effective_target
            })
            return resp

    opts = {'proxy': PROXY, 'quiet': True, 'noprogress': True, 'no_warnings': False, 'logger': log, 'noplaylist': True, 'cachedir': False,
            'socket_timeout': 10, 'retries': 1, 'fragment_retries': 1, 'extractor_retries': 0, 'js_runtimes': {'node': {}}, 'remote_components': []}
    t0 = time.monotonic()
    if hasattr(signal, 'SIGALRM'):
        signal.signal(signal.SIGALRM, _alarm)
        signal.setitimer(signal.ITIMER_REAL, DEADLINE)
    try:
        if arm == 'B':
            opts['impersonate'] = ImpersonateTarget.from_str(TARGET)
        with Instrumented(opts) as ydl:
            if arm == 'B':
                avail = [str(t) for t, _ in ydl._get_available_impersonate_targets()]
                rep['available_targets'] = avail
                if not avail:
                    rep['error'] = 'NO_IMPERSONATE_TARGET_AVAILABLE (no request made)'; rep['requests'] = []
                    raise StopIteration
            info = ydl.extract_info(URL, download=False)
        fm = [{k: f.get(k) for k in ('format_id', 'format_note', 'ext', 'protocol', 'vcodec', 'acodec', 'height', 'width', 'filesize', 'filesize_approx', 'tbr', 'has_drm')} | {'watermark_class': classify(f)} for f in info.get('formats', [])]
        rep['result'] = {'id': info.get('id'), 'type': info.get('_type'), 'extractor': info.get('extractor_key'), 'duration': info.get('duration'),
                         'webpage_url': sanitize(info.get('webpage_url', ''), 160), 'formats': fm}
    except StopIteration:
        pass
    except BaseException as e:   # noqa
        rep['error'] = sanitize(type(e).__name__ + ': ' + str(e), 400)
    finally:
        if hasattr(signal, 'setitimer'):
            signal.setitimer(signal.ITIMER_REAL, 0)
    rep['logger'] = log.lines; rep['seconds'] = round(time.monotonic() - t0, 2); rep['total_decoded_bytes'] = budget.total; rep['end_utc'] = utc()
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(rep, f, indent=2, ensure_ascii=False)
    print(json.dumps({'arm': arm, 'seconds': rep['seconds'], 'ok': 'result' in rep, 'error': rep.get('error')}))
    return rep


if __name__ == '__main__':
    attempt('A')
    time.sleep(20)
    attempt('B')
