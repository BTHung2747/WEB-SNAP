"""Only metadata/extractor + test route are stubbed. HttpFD/read/error mapping are REAL."""
import hashlib
import json
import os
import pathlib
import runpy
import time
import uuid
import yt_dlp

assert os.environ.get('P3_TEST_GUARD') == 'wed-snap-p3-test'
assert os.environ.get('REDIS_URL') == 'redis://redis:6379/14'
assert os.environ['DATABASE_URL'].endswith('/wed_snap_p3_test')
import sys
phase, url, folder = sys.argv[1:4]
assert phase == 'prepare'
folder = pathlib.Path(folder); uuid.UUID(folder.name)
control = pathlib.Path('/control') / folder.name
context = json.loads((control / 'socket.json').read_text())
uuid.UUID(context['run'])
assert context['mode'] in ('control', 'close', 'stall')
source = pathlib.Path('/app/production/media_adapter.py')
assert hashlib.sha256(source.read_bytes()).hexdigest() == context['sourceSha']
parts = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
identity = dict(pid=os.getpid(), pgid=os.getpgrp(), startTicks=parts[19], namespace=os.readlink('/proc/self/ns/pid'))
def event(name, **extra):
    with (control / 'events.jsonl').open('a') as f:
        f.write(json.dumps(dict(event=name, at=time.time() * 1000, **identity, **extra)) + '\n')
        f.flush()
event('socket_invoked', sourceSha=context['sourceSha'])
original_extract = yt_dlp.YoutubeDL.extract_info
def metadata(self, requested, download=False, **kwargs):
    assert requested == url and download is False
    assert self.params['socket_timeout'] == 10 and self.params['retries'] == 1
    assert self.params['fragment_retries'] == 1 and self.params['extractor_retries'] == 0
    # Only this test entrypoint routes to the guarded private source, without production egress.
    self.params['proxy'] = ''
    self.add_progress_hook(lambda d: event('download_progress', downloadedBytes=d.get('downloaded_bytes', 0),
                                         status=d['status']))
    event('transport_config', socketTimeout=10, retries=1, downloader='native HttpFD', metadataStub=True, routeStub=True,
          python=sys.version.split()[0], ytDlp=yt_dlp.version.__version__)
    return dict(id=folder.name, title='P3 local valid MP4', extractor='P3Socket', extractor_key='P3Socket',
                webpage_url=url, duration=4, formats=[dict(format_id='18', ext='mp4', protocol='https',
                url=f"http://socket-test:8765/media/{context['run']}/{folder.name}/{context['mode']}",
                height=72, width=128, vcodec='mp4v', acodec='mp4a', filesize=None)])
yt_dlp.YoutubeDL.extract_info = metadata
try:
    # No replacement of urlopen, response.read, process_ie_result, hook, limits or error mapping.
    runpy.run_path(str(source), run_name='__main__')
finally:
    yt_dlp.YoutubeDL.extract_info = original_extract
    event('entry_finished')
