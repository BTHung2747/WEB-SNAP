# WED SNAP lab integration (AGPL-3.0); yt-dlp/FFmpeg perform media transfer/inspection.
import hashlib, importlib.metadata as md, json, math, pathlib, re, subprocess, sys, urllib.parse
import yt_dlp
from yt_dlp.extractor.tiktok import TikTokIE
CAP_IN, CAP_OUT = 250 * 1024 * 1024, 200 * 1024 * 1024
source = json.load(sys.stdin)
folder = pathlib.Path(sys.argv[1])
folder.mkdir(parents=True, exist_ok=True)
total = 0
def safe(text):
    text = re.sub(r'https?://[^\s\'"<>]+', '[url-redacted]', str(text), flags=re.I)
    return re.sub(r'(?i)(cookie|set-cookie|authorization|proxy-authorization)\s*:[^\r\n]*', r'\1: [redacted]', text)
class Logger:
    def debug(self, message): pass
    def warning(self, message): pass
    def error(self, message): pass
class Bounded(yt_dlp.YoutubeDL):
    def urlopen(self, request):
        global total
        response = super().urlopen(request)
        original = response.read
        consumed = 0
        def read(amount=None):
            nonlocal consumed
            global total
            remaining = min(CAP_IN-consumed, CAP_IN-total)
            want = min(amount, remaining+1) if amount is not None and amount >= 0 else remaining+1
            data = original(want)
            consumed += len(data); total += len(data)
            if consumed > CAP_IN or total > CAP_IN:
                response.close(); raise RuntimeError('INPUT_LIMIT_EXCEEDED')
            return data
        response.read = read
        return response
def hook(data):
    if sum(p.stat().st_size for p in folder.glob('media*') if p.is_file()) > CAP_OUT:
        raise RuntimeError('OUTPUT_LIMIT_EXCEEDED')
report = {'status': 'FAIL', 'source_provenance': source.get('provenance')}
try:
    if yt_dlp.version.__version__ != '2026.08.19': raise RuntimeError('VERSION_MISMATCH')
    path = pathlib.Path(md.distribution('yt-dlp').locate_file('yt_dlp/extractor/tiktok.py'))
    if hashlib.sha256(path.read_bytes()).hexdigest() != '3257fdea744811ea2e1bfee665a97d6ab85517339ee672f2e43e238e6b997c9e': raise RuntimeError('PRIVATE_API_SOURCE_HASH_MISMATCH')
    if source.get('provenance') != 'playAddr' or not 0 < source['duration'] <= 600: raise RuntimeError('SOURCE_POLICY_REJECTED')
    u = urllib.parse.urlsplit(source['source'])
    if u.scheme != 'https' or u.username or (u.port and u.port != 443): raise RuntimeError('SOURCE_POLICY_REJECTED')
    opts = {'proxy': 'http://egress:8888', 'quiet': True, 'logger': Logger(), 'noprogress': True,
            'noplaylist': True, 'cachedir': False, 'socket_timeout': 10, 'retries': 0, 'fragment_retries': 0,
            'extractor_retries': 0, 'js_runtimes': {'node': {}}, 'remote_components': [],
            'max_filesize': CAP_OUT, 'progress_hooks': [hook], 'overwrites': False,
            'outtmpl': str(folder/'media.%(ext)s'), 'external_downloader': {'default': 'native'},
            'http_headers': {'Referer': source['webpage'], 'Cookie': source.get('cookie', '')}}
    with Bounded(opts) as ydl:
        ie = TikTokIE(ydl)
        formats = ie._extract_web_formats({'video': source['video']})
        selected = [f for f in formats if f.get('url') == source['source'] and f.get('ext') == 'mp4'
                    and f.get('vcodec') in ('h264', 'avc1') and f.get('acodec') != 'none'
                    and f.get('format_id') != 'download' and 'watermark' not in str(f.get('format_note', '')).lower()
                    and not f.get('has_drm')]
        if not selected: raise RuntimeError('NO_H264_AUDIO_PLAY_FORMAT')
        candidate = selected[0]
        if candidate.get('filesize') and candidate['filesize'] > CAP_OUT: raise RuntimeError('OUTPUT_LIMIT_EXCEEDED')
        report['format'] = {k: candidate.get(k) for k in ('format_id', 'vcodec', 'acodec', 'height', 'width', 'filesize')}
        # One URL only, no alternate format/source fallback and no metadata refetch.
        info = {'id': source['id'], 'title': 'TikTok lab video', 'duration': source['duration'], 'formats': [candidate], 'webpage_url': source['webpage']}
        ydl.params['format'] = 'best'
        ydl.process_ie_result(info, download=True)
    files = list(folder.glob('media.mp4'))
    if len(files) != 1 or files[0].stat().st_size > CAP_OUT: raise RuntimeError('OUTPUT_LIMIT_OR_FILE_MISSING')
    file = files[0]
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'stream=codec_type,codec_name,width,height:format=duration,size', '-of', 'json', str(file)], capture_output=True, text=True, timeout=10)
    if probe.returncode: raise RuntimeError('FFPROBE_FAIL')
    data = json.loads(probe.stdout)
    if not any(s.get('codec_name') == 'h264' and s.get('codec_type') == 'video' for s in data['streams']) or not any(s.get('codec_type') == 'audio' for s in data['streams']): raise RuntimeError('H264_OR_AUDIO_MISSING')
    duration = float(data['format']['duration'])
    if not math.isfinite(duration) or not 0 < duration <= 600: raise RuntimeError('DURATION_LIMIT')
    decode = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(file), '-f', 'null', '-'], capture_output=True, timeout=30)
    if decode.returncode: raise RuntimeError('DECODE_FAIL')
    h = hashlib.sha256()
    with file.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
    report.update(status='PASS', file='media.mp4', bytes=file.stat().st_size, input_bytes=total, sha256=h.hexdigest(), ffprobe=data, decode='PASS', visual_watermark='NOT_REVIEWED')
except Exception as error:
    report.update(error=safe(type(error).__name__+': '+str(error)), input_bytes=total)
    # Delete only known owned output names; retain report, no global cleanup.
    for p in folder.glob('media*'):
        if p.is_file(): p.unlink()
    print(json.dumps(report)); sys.exit(20)
print(json.dumps(report))
