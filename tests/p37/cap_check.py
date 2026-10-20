"""P37.2 capability check. Run with --network none. No request is made. Writes /out/capability.json."""
import sys, json, os, importlib, importlib.metadata as md, platform, datetime
sys.path.insert(0, '/p37')
from lab372 import sanitize, SafeLogger

rep = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'python': platform.python_version(), 'platform': platform.platform(),
       'uid': os.getuid(), 'cwd_writable_tmp': os.access('/tmp', os.W_OK)}
import yt_dlp
rep['yt_dlp'] = yt_dlp.version.__version__
rep['yt_dlp_variant'] = getattr(yt_dlp.version, 'VARIANT', None)
pk = {}
for name in ('requests', 'urllib3', 'brotli', 'websockets', 'certifi', 'curl_cffi', 'cffi', 'yt-dlp-ejs', 'pycryptodomex', 'mutagen'):
    try:
        pk[name] = md.version(name)
    except md.PackageNotFoundError:
        pk[name] = None
rep['dist_versions'] = pk
for mod in ('curl_cffi', 'curl_cffi.requests'):
    try:
        m = importlib.import_module(mod); rep['import_' + mod] = 'ok ' + str(getattr(m, '__version__', ''))
    except Exception as e:
        rep['import_' + mod] = 'FAIL ' + type(e).__name__ + ': ' + sanitize(str(e), 200)
log = SafeLogger()
try:
    with yt_dlp.YoutubeDL({'quiet': True, 'no_warnings': False, 'logger': log, 'cachedir': False, 'js_runtimes': {'node': {}}, 'remote_components': []}) as ydl:
        rd = ydl._request_director
        rep['request_handlers'] = sorted(rd.handlers.keys())
        try:
            targets = ydl._get_available_impersonate_targets()
            rep['impersonate_targets'] = [{'target': str(t), 'handler': h} for t, h in targets]
        except Exception as e:
            rep['impersonate_targets_error'] = type(e).__name__ + ': ' + sanitize(str(e), 200)
        rep['effective_options'] = {k: ydl.params.get(k) for k in ('proxy', 'socket_timeout', 'retries', 'extractor_retries', 'noplaylist', 'impersonate', 'http_headers', 'nocheckcertificate', 'legacyserverconnect')}
except Exception as e:
    rep['ydl_error'] = type(e).__name__ + ': ' + sanitize(str(e), 300)
rep['logger_lines'] = log.lines
try:
    from yt_dlp.networking.impersonate import ImpersonateTarget
    rep['impersonate_api'] = 'ImpersonateTarget importable'
except Exception as e:
    rep['impersonate_api'] = 'FAIL ' + type(e).__name__
with open('/out/capability.json', 'w', encoding='utf-8') as f:
    json.dump(rep, f, indent=2, ensure_ascii=False)
print(json.dumps({k: rep[k] for k in ('yt_dlp', 'request_handlers', 'impersonate_targets') if k in rep}, ensure_ascii=False))
print('curl_cffi dist =', pk['curl_cffi'], '| import:', rep.get('import_curl_cffi'))
