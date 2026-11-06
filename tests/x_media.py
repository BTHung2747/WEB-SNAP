"""X adapter regression tests with source I/O and FFprobe replaced by fixtures."""
import contextlib
import copy
import io
import json
import pathlib
import runpy
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import yt_dlp
from yt_dlp.downloader.http import HttpFD


SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'apps/media/src/media_adapter.py'
sys.path.insert(0, str(SOURCE.parent))
URL = 'https://x.com/i/web/status/1234567890'
MEDIA_ID = '1234567891'
CHOICE = f'x_mp4_{MEDIA_ID}_1080x1920'
CDN = 'https://video.twimg.com/ext_tw_video/1234567891/pu/vid/avc1'
THUMBNAIL = 'https://pbs.twimg.com/ext_tw_video_thumb/1234567891/pu/img/preview.jpg'
JPEG = b'\xff\xd8\xfffixture'


def variant(width, height, bitrate):
    return dict(format_id=f'http-{bitrate}', url=f'{CDN}/{width}x{height}/{bitrate}.mp4',
                width=width, height=height, tbr=bitrate)


def invoke(metadata, selected=None, *, audio=True, actual_duration=2.0, stale=False):
    seen = []
    stdout = io.StringIO()
    probe = dict(format=dict(format_name='mov,mp4,m4a,3gp,3g2,mj2', duration=actual_duration,
                             tags={'major_brand': 'isom'}),
                 streams=[dict(codec_type='video', width=1080, height=1920, duration=actual_duration)])
    if audio:
        probe['streams'].append(dict(codec_type='audio', duration=actual_duration))

    def extract(_, url, *, download, process):
        seen.append((url, download, process))
        return copy.deepcopy(metadata)

    def preview(_, url):
        seen.append(url)
        response = io.BytesIO(JPEG)
        response.headers = {'Content-Length': str(len(JPEG))}
        return response

    def download(_, filename, info):
        seen.append(info['url'])
        pathlib.Path(filename).write_bytes(b'MP4 fixture')
        return True

    with tempfile.TemporaryDirectory() as folder:
        output = pathlib.Path(folder)
        if stale:
            (output / 'media.mp4').write_bytes(b'stale')
        args = ['prepare' if selected else 'analyze', URL, folder]
        if selected:
            args.append(selected)
        with patch.object(sys, 'argv', [str(SOURCE), *args]), \
             patch.object(yt_dlp.YoutubeDL, 'extract_info', extract), \
             patch.object(yt_dlp.YoutubeDL, 'urlopen', preview), \
             patch.object(HttpFD, 'real_download', download), \
             patch('subprocess.run', return_value=SimpleNamespace(returncode=0, stdout=json.dumps(probe))), \
             contextlib.redirect_stdout(stdout):
            try:
                runpy.run_path(str(SOURCE), run_name='__main__')
            except SystemExit as error:
                if error.code != 1:
                    raise
        image = (output / 'preview').read_bytes() if (output / 'preview').is_file() else None
    return json.loads(stdout.getvalue()), seen, image


class XMedia(unittest.TestCase):
    def setUp(self):
        self.metadata = dict(extractor_key='Twitter', extractor='twitter', id=MEDIA_ID,
                             display_id='1234567890', title='X test video', duration=2.0,
                             webpage_url=URL, thumbnails=[{'url': THUMBNAIL}],
                             formats=[variant(720, 1280, 1300), variant(1080, 1920, 4000)])

    def test_raw_metadata_exposes_preview_and_only_eligible_mp4(self):
        self.metadata['formats'].extend([variant(2160, 3840, 8000),
            dict(variant(1080, 1920, 7000), url='https://other.example/video.mp4'),
            dict(variant(1080, 1920, 6000), protocol='m3u8_native')])
        result, seen, image = invoke(self.metadata)
        self.assertEqual(result['title'], 'X test video')
        self.assertEqual([row['id'] for row in result['formats']], [CHOICE, f'x_mp4_{MEDIA_ID}_720x1280'])
        self.assertTrue(result['formats'][0]['highest'])
        self.assertEqual(seen, [(URL, False, False), THUMBNAIL])
        self.assertEqual(image, JPEG)
        self.assertNotIn('twimg.com', json.dumps(result))

    def test_prepare_selects_exact_resolution_and_supports_silent_video(self):
        selected = variant(1080, 1920, 5000)
        self.metadata['formats'].append(selected)
        for audio in (True, False):
            result, seen, _ = invoke(self.metadata, CHOICE, audio=audio)
            self.assertEqual(result['file'], 'media.mp4')
            self.assertEqual(seen, [(URL, False, False), selected['url']])

    def test_rejects_changed_attachment_missing_choice_and_stale_file(self):
        for changes, stale, expected in [({'id': '2222222222'}, False, 'FORMAT_UNAVAILABLE'),
            ({'formats': [variant(720, 1280, 1300)]}, False, 'FORMAT_UNAVAILABLE'),
            ({}, True, 'INVALID_ASSET_PATH')]:
            result, seen, _ = invoke(dict(self.metadata, **changes), CHOICE, stale=stale)
            self.assertEqual(result, {'error': expected})
            self.assertEqual(seen, [(URL, False, False)])

    def test_rejects_other_post_private_external_and_multiple_videos(self):
        for changes, expected in [({'display_id': '2222222222'}, 'FORMAT_UNAVAILABLE'),
            ({'availability': 'private'}, 'AUTH_REQUIRED'),
            ({'_type': 'url'}, 'UNSUPPORTED_CONTENT'),
            ({'_type': 'playlist'}, 'UNSUPPORTED_CONTENT')]:
            result, seen, _ = invoke(dict(self.metadata, **changes))
            self.assertEqual(result, {'error': expected})
            self.assertEqual(seen, [(URL, False, False)])

    def test_rejects_truncated_mp4(self):
        result, _, _ = invoke(self.metadata, CHOICE, actual_duration=1.0)
        self.assertEqual(result, {'error': 'FORMAT_UNAVAILABLE'})


if __name__ == '__main__':
    unittest.main()
