"""P37.1 probe (lab only, metadata only; never downloads media).

Per input, per pass (max 2 passes enforced by pass files in /out):
  1. raw redirect chain via the lab egress CONNECT proxy, redirects followed manually (<=5 hops);
     records status / size / <title> / markers per hop. Locations are sanitized (no query/fragment/userinfo).
  2. raw yt-dlp extract_info(download=False) summary (format fields only, no URLs).
  3. PRODUCTION infra/media_adapter.py `analyze` executed unmodified as a subprocess (argv array, no shell).
Each input has a hard 30 s total deadline per step. All text written out is sanitized by sanitize().
"""
import sys, os, re, json, time, signal, datetime, subprocess, tempfile, http.client, glob, urllib.parse

INPUTS = [
    ('video1', 'https://www.tiktok.com/@arunal_loyria/video/7611475556395191573'),
    ('video2_short_nobutton', 'https://vt.tiktok.com/ZSbxenGuS/'),
    ('video3_short_button', 'https://vt.tiktok.com/ZSbxd2AVY/'),
    ('photo', 'https://www.tiktok.com/@sariafgo1205/photo/7691702429523430676'),
]
OUT = '/out'
PROXY = os.environ.get('MEDIA_PROXY', 'http://egress:8888')
DEADLINE = 30
PAGE_CAP = 1024 * 1024
RAW_RESPONSE_CAP = 8 * 1024 * 1024
RAW_AGG_CAP = 16 * 1024 * 1024
ADAPTER = '/app/infra/media_adapter.py'

URL_RE = re.compile(r'https?://[^\s\'"<>)\]]+', re.I)
SECRET_RE = re.compile(r'(?i)(mstoken|x-bogus|_signature|signature|token|cookie|sessionid|tt_chain_token|auth|key|sign)=[^\s&\'"]+')


def sanitize(text, limit=400):
    text = str(text)
    def url(m):
        u = urllib.parse.urlsplit(m.group(0))
        host = u.hostname or ''
        path = u.path
        if len(path) > 80:
            path = path[:80] + '...'
        return '%s://%s%s[q-redacted]' % (u.scheme, host, path) if (u.query or u.fragment) else '%s://%s%s' % (u.scheme, host, path)
    text = URL_RE.sub(url, text)
    text = SECRET_RE.sub(lambda m: m.group(1) + '=[redacted]', text)
    return text[:limit]


def clean_url(value):
    u = urllib.parse.urlsplit(value)
    return urllib.parse.urlunsplit((u.scheme, u.hostname or '', u.path, '', ''))


class Deadline(Exception):
    pass


def _alarm(signum, frame):
    raise Deadline('deadline %ss exceeded' % DEADLINE)


def with_deadline(fn):
    signal.signal(signal.SIGALRM, _alarm)
    signal.setitimer(signal.ITIMER_REAL, DEADLINE)
    try:
        return fn()
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def page_chain(start):
    """Manual redirects through CONNECT proxy; returns list of hop summaries."""
    from yt_dlp.utils.networking import std_headers
    ph = urllib.parse.urlsplit(PROXY)
    hops, url = [], start
    for _ in range(6):
        u = urllib.parse.urlsplit(url)
        conn = http.client.HTTPSConnection(ph.hostname, ph.port or 8888, timeout=10)
        conn.set_tunnel(u.hostname, 443)
        hop = {'url': clean_url(url)}
        try:
            path = u.path + ('?' + u.query if u.query else '')
            conn.request('GET', path or '/', headers=dict(std_headers, Host=u.hostname))
            r = conn.getresponse()
            body = r.read(PAGE_CAP + 1)
            text = body[:PAGE_CAP].decode('utf-8', 'ignore')
            low = text.lower()
            title = None
            if '<title>' in low:
                i = low.find('<title>')
                title = sanitize(text[i + 7:low.find('</title>', i)], 120)
            hop.update({'status': r.status, 'content_type': r.getheader('Content-Type'), 'bytes_read': min(len(body), PAGE_CAP),
                        'truncated_at_cap': len(body) > PAGE_CAP, 'title': title,
                        'has_rehydration_json': '__UNIVERSAL_DATA_FOR_REHYDRATION__' in text,
                        'has_sigi_state': 'SIGI_STATE' in text,
                        'maintenance_marker': 'maintenance' in low,
                        'captcha_marker': any(k in low for k in ('captcha', 'verify-center', 'tiktok-verify'))})
            loc = r.getheader('Location')
            hops.append(hop)
            if r.status in (301, 302, 303, 307, 308) and loc:
                url = urllib.parse.urljoin(url, loc)
                hop['location'] = clean_url(url)
                continue
            break
        except Exception as e:
            hop['error'] = sanitize(type(e).__name__ + ': ' + str(e), 200)
            hops.append(hop)
            break
        finally:
            conn.close()
    return hops


def raw_ytdlp(url):
    import yt_dlp
    agg = {'n': 0}

    class Bounded(yt_dlp.YoutubeDL):
        def urlopen(self, req):
            resp = super().urlopen(req)
            orig = resp.read
            seen = {'n': 0}
            def read(amt=None):
                data = orig(amt)
                seen['n'] += len(data); agg['n'] += len(data)
                if seen['n'] > RAW_RESPONSE_CAP or agg['n'] > RAW_AGG_CAP:
                    resp.close(); raise Deadline('LIMIT_EXCEEDED')
                return data
            resp.read = read
            return resp
    opts = {'proxy': PROXY, 'quiet': True, 'noprogress': True, 'no_warnings': True, 'noplaylist': True, 'cachedir': False,
            'socket_timeout': 10, 'retries': 1, 'extractor_retries': 0, 'js_runtimes': {'node': {}}, 'remote_components': []}
    fields = ['format_id', 'format_note', 'ext', 'protocol', 'vcodec', 'acodec', 'height', 'width', 'filesize', 'filesize_approx', 'tbr', 'has_drm']
    def go():
        with Bounded(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        return {'extractor': info.get('extractor_key'), 'id': info.get('id'), 'type': info.get('_type'),
                'duration': info.get('duration'), 'availability': info.get('availability'), 'age_limit': info.get('age_limit'),
                'webpage_url': clean_url(info['webpage_url']) if info.get('webpage_url') else None,
                'formats': [{k: f.get(k) for k in fields} for f in info.get('formats', [])]}
    return with_deadline(go)


def production_analyze(url):
    folder = tempfile.mkdtemp(prefix='analyze-', dir='/tmp')
    env = dict(os.environ, ADAPTER_MAX_INPUT='262144000', ADAPTER_MAX_OUTPUT='209715200', ADAPTER_MAX_DURATION='600', MEDIA_PROXY=PROXY)
    t0 = time.monotonic()
    p = subprocess.Popen(['python3', ADAPTER, 'analyze', url, folder], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, start_new_session=True)
    try:
        out, err = p.communicate(timeout=DEADLINE)
        timed_out = False
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL); out, err = p.communicate(); timed_out = True
    last = (out.strip().splitlines() or [''])[-1]
    try:
        parsed = json.loads(last)
    except Exception:
        parsed = None
    if isinstance(parsed, dict) and 'formats' in parsed:
        parsed = {'title': sanitize(parsed.get('title', ''), 80), 'duration': parsed.get('duration'),
                  'formats': [{k: f.get(k) for k in ('id', 'label', 'size', 'height', 'kind')} for f in parsed['formats']]}
    return {'exit': p.returncode, 'timed_out': timed_out, 'seconds': round(time.monotonic() - t0, 2),
            'result': parsed, 'stderr_sanitized': sanitize(err.strip(), 500)}


def main():
    done = sorted(glob.glob(os.path.join(OUT, 'probe-pass*.json')))
    n = len(done) + 1
    if n > 2:
        print(json.dumps({'refused': 'max 2 passes reached'})); sys.exit(3)
    import yt_dlp
    report = {'pass': n, 'start_utc': utc(), 'yt_dlp': yt_dlp.version.__version__, 'proxy': 'egress:8888(lab)', 'deadline_s': DEADLINE, 'inputs': []}
    for label, url in INPUTS:
        row = {'label': label, 'input': url, 'started_utc': utc()}
        try:
            row['page_chain'] = with_deadline(lambda: page_chain(url))
        except Exception as e:
            row['page_chain_error'] = sanitize(type(e).__name__ + ': ' + str(e), 200)
        try:
            row['raw_ytdlp'] = raw_ytdlp(url)
        except BaseException as e:
            row['raw_ytdlp_error'] = sanitize(type(e).__name__ + ': ' + str(e), 300)
        row['production_analyze'] = production_analyze(url)
        row['finished_utc'] = utc()
        report['inputs'].append(row)
    report['end_utc'] = utc()
    path = os.path.join(OUT, 'probe-pass%d.json' % n)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps({'pass': n, 'written': os.path.basename(path), 'inputs': len(report['inputs'])}))


if __name__ == '__main__':
    main()
