"""Optional job-local previews. No source URLs/cookies in cache or public packets.

Requests/yt-dlp retain transport ownership; FFmpeg owns image decoding/scaling.
The parent grants a separate counted capability and accepts its closure proof
before publishing previews.json. A failed optional batch cannot poison metadata.
"""
import hashlib
import imghdr
import json
import math
import multiprocessing
import os
import pathlib
import re
import select
import stat
import subprocess
import sys
import threading
import time

KEY = re.compile(r'(?:video|ttp1_[0-9]{2}_[a-f0-9]{64})')
HEX = re.compile(r'[a-f0-9]{64}')
SOURCE_CAP = 512 * 1024
TOTAL_CAP = 8 * 1024 * 1024
JPEG_CAP = 128 * 1024
SIDE = 320


def remaining(end):
    value = end - time.monotonic()
    if value <= 0: raise ValueError('PREVIEW_DEADLINE')
    return value


def read_regular(path, cap):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        st = os.fstat(stream.fileno())
        if not stat.S_ISREG(st.st_mode) or not 0 < st.st_size <= cap: raise ValueError('PREVIEW_SIZE')
        data = stream.read(cap + 1)
        if len(data) != st.st_size: raise ValueError('PREVIEW_SIZE')
        return data


def native(args, end, data=None):
    p = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=remaining(end))
    remaining(end)
    if p.returncode: raise ValueError('PREVIEW_NATIVE')
    return p.stdout


def normalized(path, end, cap=SOURCE_CAP):
    # Validate only local bounded raster images before decoding; never hand a
    # URL, playlist, SVG or HTML to FFmpeg. This is also used on original JPEGs
    # at prepare; no second source GET and no comparison of lossy thumbnails.
    source = read_regular(path, cap)
    if imghdr.what(None, source) not in ('jpeg', 'png', 'webp'): raise ValueError('PREVIEW_TYPE')
    p = json.loads(native(['ffprobe', '-v', 'error', '-max_alloc', '67108864', '-protocol_whitelist', 'pipe',
        '-show_entries', 'stream=codec_type,codec_name,width,height', '-of', 'json', '-i', 'pipe:0'], end, source))
    streams = p.get('streams', [])
    if len(streams) != 1: raise ValueError('PREVIEW_STREAMS')
    s = streams[0]; w = s.get('width'); h = s.get('height')
    if s.get('codec_type') != 'video' or s.get('codec_name') not in ('mjpeg', 'png', 'webp') or type(w) is not int or type(h) is not int or not 0 < w <= 8192 or not 0 < h <= 8192 or w*h > 16000000:
        raise ValueError('PREVIEW_PIXELS')
    raw = native(['ffmpeg', '-v', 'error', '-nostdin', '-max_alloc', '67108864', '-threads', '1',
        '-protocol_whitelist', 'pipe', '-i', 'pipe:0', '-filter_threads', '1',
        '-vf', f'scale={SIDE}:{SIDE}:force_original_aspect_ratio=decrease,pad={SIDE}:{SIDE}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=rgb24',
        '-frames:v', '1', '-threads', '1', '-f', 'rawvideo', 'pipe:1'], end, source)
    if len(raw) != SIDE*SIDE*3: raise ValueError('PREVIEW_DECODE')
    return raw


def jpeg(raw, end):
    data = native(['ffmpeg', '-v', 'error', '-nostdin', '-threads', '1', '-f', 'rawvideo', '-pixel_format', 'rgb24',
        '-video_size', f'{SIDE}x{SIDE}', '-i', 'pipe:0', '-filter_threads', '1', '-frames:v', '1',
        '-c:v', 'mjpeg', '-q:v', '5', '-threads', '1', '-f', 'image2pipe', 'pipe:1'], end, raw)
    if not 4 < len(data) <= JPEG_CAP or not data.startswith(b'\xff\xd8\xff') or not data.endswith(b'\xff\xd9'):
        raise ValueError('PREVIEW_SIZE')
    return data


class OwnedCache:
    def __init__(self, folder): self.folder = folder; self.owned = {}
    def put(self, name, data):
        path = self.folder/name
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as f:
            s = os.fstat(f.fileno()); self.owned[path] = (s.st_dev, s.st_ino); f.write(data)
        return path
    def remove(self, path):
        try:
            s = path.lstat()
            if self.owned.get(path) == (s.st_dev, s.st_ino) and stat.S_ISREG(s.st_mode): path.unlink()
        except FileNotFoundError: pass
    def cleanup(self):
        for path in self.owned: self.remove(path)


def capability(count, deadline):
    # Internal stdin/stdout handshake, not public JSON. Metadata is already
    # validated and its session closed. The parent clamps count and binds job.
    if os.environ.get('WED_PREVIEW_REQUEST') != '1' or remaining(deadline) < 3: return None
    print(json.dumps({'_preview': {'count': count}}, separators=(',', ':')), flush=True)
    if not select.select([sys.stdin], [], [], min(1.5, remaining(deadline)))[0]: return None
    raw = sys.stdin.buffer.readline(2049)
    if len(raw) > 2048: return None
    p = json.loads(raw)
    if set(p) != {'phase', 'cap', 'seconds'} or not all(type(p[k]) is str and HEX.fullmatch(p[k]) for k in ('phase', 'cap')) or type(p['seconds']) not in (int, float) or not math.isfinite(p['seconds']) or not 0 < p['seconds'] <= 30: return None
    return (p['phase'], p['cap']), time.monotonic() + p['seconds']


def _fetch(pipe, url, credentials, end, cap, folder, session_factory):
    """One HTTP read, no decoder/subprocess descendants. Never print secrets.
    A parent kill closes every inherited process socket, even if a library read
    or close is blocked. The egress proof then rejects this optional phase.
    """
    ydl = None; body = b''; used = 0; ok = False
    try:
        import requests
        from yt_dlp.networking import Request
        from .core import Budget, GuardedYDL
        from .photo_proxy import PhotoProxyAdapter
        from .session_owner import SessionOwner
        b = Budget(cap, JPEG_CAP, end, 6)
        b.mode = 'preview'; b.max_requests = 1; b.response_cap = min(SOURCE_CAP, cap); b.total_cap = cap
        def factory():
            base = requests.Session()
            try:
                base.mount('https://', PhotoProxyAdapter(max_retries=0, credentials=credentials))
                return SessionOwner(base)
            except BaseException:
                base.close(); raise
        ydl = GuardedYDL(b, folder, session_factory or factory); ydl.allowed_url = url
        try:
            with ydl.urlopen(Request(url)) as response:
                mime = response.headers.get('Content-Type', '').split(';')[0].lower()
                if mime not in ('image/jpeg', 'image/png', 'image/webp'): raise ValueError('PREVIEW_TYPE')
                body = response.read()
        finally: used = b.network_total
        ydl.close(); ydl = None; b.check(); ok = True
    except Exception: pass
    finally:
        if ydl is not None:
            try: ydl.close()
            except Exception: ok = False
        try:
            header = json.dumps(dict(ok=ok, used=used), separators=(',', ':')).encode()
            pipe.send_bytes(header + b'\n' + (body if ok else b''))
        finally: pipe.close()


def fetch(url, credentials, end, cap, folder, session_factory=None):
    # Docker's pinned Linux/Python3.11, single-threaded analyze child. Explicit
    # public fork context retains fixture seams but creates the Session AFTER
    # fork, without sharing a pool/socket. It stays in the supervised job PGID.
    # Pipe payload/response are bounded RAM only. No URL on command line/file.
    if threading.active_count() != 1 or len(os.listdir('/proc/self/task')) != 1: raise ValueError('PREVIEW_THREADS')
    remaining(end)
    if not 0 < cap <= TOTAL_CAP: raise ValueError('PREVIEW_SIZE')
    context = multiprocessing.get_context('fork')
    receiver, sender = context.Pipe(duplex=False)
    process = context.Process(target=_fetch, args=(sender,url,credentials,end,cap,folder,session_factory))
    try:
        process.start(); sender.close()
        if not receiver.poll(remaining(end)): raise ValueError('PREVIEW_DEADLINE')
        packet = receiver.recv_bytes(SOURCE_CAP + 128)
        process.join(remaining(end))
        if process.is_alive() or process.exitcode != 0: raise ValueError('PREVIEW_WORKER')
        header, body = packet.split(b'\n', 1); p = json.loads(header)
        if set(p) != {'ok','used'} or p['ok'] is not True or type(p['used']) is not int or not 0 < p['used'] == len(body) <= min(SOURCE_CAP,cap): raise ValueError('PREVIEW_FETCH')
        return body
    finally:
        sender.close(); receiver.close()
        if process.pid is not None:
            if process.is_alive(): process.kill()
            process.join(1)
            if process.is_alive(): raise ValueError('PREVIEW_REAP')
            process.close()


def generate(folder, candidates, deadline, *, grant=capability, session_factory=None):
    """At most one attempt per chosen metadata image. Stop batch on first error.

    Missing/failed optional proof makes the parent discard the unpublished cache.
    All source URLs remain in candidates RAM; never returned or written.
    """
    if os.environ.get('WED_PREVIEW_REQUEST') != '1': return
    owned = OwnedCache(folder); rows = []
    try:
        chosen = list(candidates)[:50]
        if not chosen or len({k for k, _ in chosen}) != len(chosen) or any(not KEY.fullmatch(k) for k, _ in chosen): return
        granted = grant(len(chosen), deadline)
        if granted is None: return
        creds, parent_end = granted
        end = min(deadline - 2, parent_end - 2, time.monotonic() + 6)
        remaining(end)
        disk = total = 0
        for key, url in chosen:
            remaining(end)
            source = fetch(url, creds, end, TOTAL_CAP-total, folder, session_factory)
            total += len(source)
            temp = owned.put('preview-input.part', source)
            try: raw = normalized(temp, end)
            finally: owned.remove(temp)
            data = jpeg(raw, end); disk += len(data)
            if disk > TOTAL_CAP: raise ValueError('PREVIEW_SIZE')
            owned.put('preview-' + key + '.jpg', data)
            row = dict(key=key, mime='image/jpeg', width=SIDE, height=SIDE, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
            if key != 'video': row['normalizedSha256'] = hashlib.sha256(raw).hexdigest()
            rows.append(row)
        remaining(end)
        # A candidate index is NOT API-visible until the parent takes proof.
        data = json.dumps(dict(version=1, entries=rows), separators=(',', ':')).encode()
        if len(data) > 24576: raise ValueError('PREVIEW_INDEX')
        owned.put('previews.pending.json', data)
    except Exception:
        owned.cleanup()  # Optional failure: no public exception/secret/log.


def verify_photo(folder, key, path, deadline, cap):
    """If analyze cached this image, fresh prepare must match normalized pixels.
    Structural v1 keys alone are not content identities. No preview => old
    structural contract remains, with no invented content-proof claim.
    """
    manifest = folder/'previews.json'
    if not os.path.lexists(manifest): return
    p = json.loads(read_regular(manifest, 24576))
    if set(p) != {'version', 'entries'} or p['version'] != 1 or type(p['entries']) is not list or len(p['entries']) > 50:
        raise ValueError('PREVIEW_INDEX')
    matching = [e for e in p['entries'] if type(e) is dict and e.get('key') == key]
    if not matching: return
    if len(matching) != 1 or not HEX.fullmatch(matching[0].get('normalizedSha256', '')): raise ValueError('PREVIEW_INDEX')
    if hashlib.sha256(normalized(path, deadline, cap)).hexdigest() != matching[0]['normalizedSha256']:
        raise ValueError('PREVIEW_CONTENT_CHANGED')
