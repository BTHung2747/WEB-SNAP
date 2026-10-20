"""P37 source probe (lab only). Metadata only, download=False. Output has no URLs/headers/cookies."""
import sys, json, os, datetime, yt_dlp
urls = sys.argv[2:]
out = sys.argv[1]
opts = {'proxy': os.environ.get('MEDIA_PROXY', 'http://egress:8888'), 'quiet': True, 'noprogress': True,
        'no_warnings': True, 'noplaylist': True, 'cachedir': False, 'socket_timeout': 10, 'retries': 1,
        'extractor_retries': 0, 'js_runtimes': {'node': {}}, 'remote_components': []}
FIELDS = ['format_id', 'format_note', 'ext', 'protocol', 'vcodec', 'acodec', 'height', 'width',
          'filesize', 'filesize_approx', 'tbr', 'has_drm', 'preference', 'quality', 'source_preference']
report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'yt_dlp': yt_dlp.version.__version__, 'samples': []}
for url in urls:
    row = {'input': url}
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        row.update({'extractor': info.get('extractor_key'), 'id': info.get('id'), 'type': info.get('_type'),
                    'duration': info.get('duration'), 'webpage_url': (info.get('webpage_url') or '').split('?')[0],
                    'uploader_id': info.get('uploader_id'), 'availability': info.get('availability'),
                    'age_limit': info.get('age_limit'), 'title': (info.get('title') or '')[:80],
                    'formats': [{k: f.get(k) for k in FIELDS} for f in info.get('formats', [])],
                    'entries': len(info.get('entries') or []) if info.get('entries') is not None else None})
    except Exception as e:
        msg = str(e)
        for token in ('http://', 'https://'):
            msg = msg.replace(token, '[url]:')
        row['error'] = type(e).__name__ + ': ' + msg[:400]
    report['samples'].append(row)
open(out, 'w', encoding='utf-8').write(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({'done': True, 'samples': len(report['samples'])}))
