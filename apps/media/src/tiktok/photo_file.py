"""AGPL-3.0 JPEG contract ported from tested photo-runtime/worker.py:contract.

FFmpeg/ffprobe own media parsing and full decoding; no image manipulation.
"""
import hashlib
import imghdr
import json

from .photo_contract import require


def inspect_jpeg(path, mime, operations, expected, check):
    check()
    require(type(mime) is str and mime.split(';', 1)[0].strip().lower() == 'image/jpeg'
            and imghdr.what(path) == 'jpeg', 'JPEG_REQUIRED')
    with operations.step('CONTRACT', operations.timeout(60)):
        probe = operations.native('FFPROBE', [
            'ffprobe', '-v', 'error', '-max_alloc', '67108864', '-show_entries',
            'stream=codec_name,codec_type,width,height', '-of', 'json', str(path)], 10, capture=True)
        streams = json.loads(probe.stdout)['streams']
        require(len(streams) == 1 and streams[0].get('codec_type') == 'video'
                and streams[0].get('codec_name') == 'mjpeg', 'JPEG_REQUIRED')
        w, h = streams[0].get('width'), streams[0].get('height')
        require(type(w) is int and type(h) is int and 0 < w <= 8192 and 0 < h <= 8192
                and w * h <= 16000000, 'PHOTO_DIMENSIONS')
        require(w == expected['width'] and h == expected['height'], 'DIMENSION_MISMATCH')
        count = operations.native('FFPROBE', [
            'ffprobe', '-v', 'error', '-max_alloc', '67108864', '-count_frames',
            '-show_entries', 'stream=nb_read_frames', '-of', 'json', str(path)], 10, capture=True)
        counted = json.loads(count.stdout)['streams']
        require(len(counted) == 1 and counted[0].get('nb_read_frames') == '1', 'STATIC_IMAGE_REQUIRED')
        check()
        operations.native('DECODE', [
            'ffmpeg', '-v', 'error', '-nostdin', '-xerror', '-max_alloc', '67108864', '-threads', '1',
            '-err_detect', 'explode', '-i', str(path), '-f', 'null', '-'], 30, reserve=5)
        check()
    with operations.step('HASH', operations.timeout(60)):
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for data in iter(lambda: stream.read(65536), b''):
                digest.update(data)
                check()
    return dict(magic='jpeg', mime='image/jpeg', width=w, height=h, pixels=w * h,
                frames=1, fullDecode='PASS'), digest.hexdigest()
