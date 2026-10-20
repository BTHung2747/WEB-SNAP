"""P37 diagnostic: what does TikTok return to the lab egress? Prints status/size/markers only; no bodies saved."""
import sys, os, json, yt_dlp
from yt_dlp.networking import Request
opts = {'proxy': os.environ.get('MEDIA_PROXY', 'http://egress:8888'), 'quiet': True, 'no_warnings': True, 'socket_timeout': 10, 'cachedir': False}
res = []
with yt_dlp.YoutubeDL(opts) as ydl:
    for url in sys.argv[1:]:
        row = {'url': url}
        try:
            r = ydl.urlopen(Request(url))
            body = r.read(3_000_000)
            t = body.decode('utf-8', 'ignore')
            row.update({'status': r.status, 'final': r.url.split('?')[0], 'bytes': len(body),
                        'has_rehydration': '__UNIVERSAL_DATA_FOR_REHYDRATION__' in t,
                        'has_sigi': 'SIGI_STATE' in t, 'captcha': any(k in t.lower() for k in ('captcha', 'verify-', 'tiktok-verify')),
                        'content_type': r.headers.get('Content-Type'), 'title': t[t.find('<title>') + 7:t.find('</title>')][:80] if '<title>' in t else None})
        except Exception as e:
            m = str(e)
            row['error'] = type(e).__name__ + ': ' + m[:200].replace('https://', '[url]:')
        res.append(row)
print(json.dumps(res, indent=1))
