"""OFFLINE ONLY: public Requests adapter double; no runtime import points here."""
import base64
import gzip
import hashlib
import io
import json
import pathlib
import time

import requests
import urllib3

EXPECTED = '7000000000000000001'
URL = 'https://www.tiktok.com/@fixture/photo/' + EXPECTED
TARGET = URL.replace('/photo/', '/video/')
IMAGE = 'https://media.tiktokcdn.com/FAKE_PATH_TOKEN/image.jpeg?token=FAKE_QUERY_TOKEN'


def challenge():
    seed = b'photo-core-fixture'
    digest = hashlib.sha256(seed + b'0').digest()
    value = base64.b64encode(json.dumps({'v': {'a': base64.b64encode(seed).decode(),
                                            'c': base64.b64encode(digest).decode()}}).encode()).decode()
    return ('<html>Please wait...<div id="cs" class="' + value +
            '"></div><div id="wci" class="fixture_cookie"></div></html>').encode()


def body(mode='normal'):
    count = 51 if mode == 'count51' else 2
    images = [{'imageWidth': 64, 'imageHeight': 64,
               'imageURL': {'urlList': [IMAGE.replace('image.jpeg', f'image{i}.jpeg')]}} for i in range(count)]
    if mode == 'dimension-change':
        images[0]['imageWidth'] = 32
    if mode == 'count-change':
        images.pop()
    if mode == 'unsafe-url':
        images[0]['imageURL']['urlList'] = ['http://media.tiktokcdn.com/image.jpeg?fixture']
    item = {'id': EXPECTED if mode != 'wrong-body' else str(int(EXPECTED) + 1), 'desc': 'Fixture only',
            'author': {'uniqueId': 'fixture'}, 'privateItem': mode == 'private',
            'video': {'duration': 2, 'width': 64, 'height': 64, 'playAddr': IMAGE},
            'music': {'playUrl': IMAGE}, 'imagePost': {'images': images}}
    if mode == 'nonphoto':
        del item['imagePost']
    if mode == 'bad-dimensions':
        images[0]['imageWidth'] = True
    value = {'__DEFAULT_SCOPE__': {'webapp.video-detail': {'statusCode': 0, 'itemInfo': {'itemStruct': item}}}}
    return ('<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">' +
            json.dumps(value) + '</script>').encode()


def reply(data, mime='text/html', status=200, compressed=False):
    class Reply(requests.Response):
        def __init__(self):
            super().__init__()
            self.closed_by_core = False
        def close(self):
            self.closed_by_core = True
            super().close()
    response = Reply()
    response.status_code = status
    payload = gzip.compress(data) if compressed else data
    response.headers = requests.structures.CaseInsensitiveDict({'content-type': mime, 'content-length': str(len(payload))})
    if compressed:
        response.headers['content-encoding'] = 'gzip'
    if status == 302:
        response.headers['location'] = IMAGE
    response.raw = urllib3.HTTPResponse(body=io.BytesIO(payload), headers=response.headers,
                                      preload_content=False, decode_content=False)
    return response


class Adapter(requests.adapters.HTTPAdapter):
    def __init__(self, owner):
        super().__init__(max_retries=0)
        self.owner = owner

    def send(self, prepared, **options):
        s = self.owner
        def respond(*args, **kwargs):
            response = reply(*args, **kwargs)
            s.responses.append(response)
            return response
        assert prepared.method == 'GET' and prepared.body is None
        assert options['stream'] is True and options['verify'] is True
        assert options['proxies'] == {'http': 'http://egress:8888', 'https': 'http://egress:8888'}
        assert not s.trust_env
        timeout = options['timeout']
        assert 0 < timeout.connect_timeout <= 10 and 0 < timeout.read_timeout <= 20
        if prepared.url == TARGET:
            s.metadata += 1
            assert s.metadata <= 2
            if s.mode == 'blocked':
                (s.folder/'blocked-entered.json').write_text(json.dumps({'event':'ADAPTER_ENTERED','time':time.monotonic()}))
                time.sleep(10)  # Deliberately violates adapter timeout: OS parent must stop this.
            if s.metadata == 1:
                assert not prepared.headers.get('Cookie')
                data = challenge()
                if s.mode == 'aggregate':
                    data += b' ' * (600 * 1024)
                if s.mode == 'metadata-over8':
                    data = b'x' * (8 * 1024 * 1024 + 1)
                if s.mode == 'metadata-exact16':
                    data += b' ' * (8*1024*1024-len(data))
                return respond(data, compressed=s.mode == 'metadata-over8')
            assert 'fixture_cookie=' in prepared.headers.get('Cookie', '')
            if s.mode == 'tls-after-challenge':
                raise requests.exceptions.SSLError('https://FAKE_PATH_TOKEN/?FAKE_QUERY_TOKEN')
            if s.mode == 'body-timeout':
                response = respond(body())
                class Broken:
                    def read(self, *a, **k):
                        raise urllib3.exceptions.ReadTimeoutError(None, None, 'FAKE_QUERY_TOKEN')
                    def close(self):
                        pass
                response.raw = Broken()
                return response
            data = body(s.mode)
            if s.mode == 'aggregate':
                data += b' ' * (600 * 1024)
            if s.mode == 'metadata-exact16':
                data += b' ' * (8*1024*1024-len(data))
            return respond(data)
        assert prepared.url in [IMAGE.replace('image.jpeg', f'image{i}.jpeg') for i in range(2)]
        s.images += 1
        assert s.images == 1 and s.metadata == 2
        assert 'fixture_cookie=' not in prepared.headers.get('Cookie', '')
        if s.mode == 'cancel':
            s.cancelled[0] = True
        if s.mode == 'redirect':
            return respond(b'x', status=302)
        if s.mode == 'http403':
            return respond(b'x', status=403)
        if s.mode == 'collision':
            (s.folder / 'image.jpg').write_bytes(b'OTHER_OWNER')
        data = s.jpeg.read_bytes()
        if s.mode == 'large-jpeg':
            # Legal ignored APP15 segments: a valid >8MiB JPEG without huge pixels.
            offset = data.index(b'\xff\xda')  # Known synthetic fixture's scan marker; retain magic prefix.
            data = data[:offset] + (b'\xff\xef\xff\xff' + b'x' * 65533) * 145 + data[offset:]
        if s.mode == 'false-jpeg':
            data = b'GIF89a' + b'x' * 100
        if s.mode == 'truncated':
            data = data[:30]
        if s.mode == 'wrong-media-dimensions':
            data = (s.jpeg.parent / 'wrong.jpg').read_bytes()
        response = respond(data, 'text/html' if s.mode == 'wrong-mime' else 'image/jpeg')
        if s.mode == 'cancel-after-part':
            original = response.raw
            class CancelBody:
                def read(self, *args, **kwargs):
                    chunk = original.read(*args, **kwargs)
                    if not chunk:
                        s.cancelled[0] = True
                    return chunk
                def close(self):
                    original.close()
            response.raw = CancelBody()
        return response


class Factory:
    def __init__(self, mode, jpeg, folder, cancelled=None):
        self.mode, self.jpeg, self.folder = mode, pathlib.Path(jpeg), pathlib.Path(folder)
        self.cancelled = cancelled if cancelled is not None else [False]
        self.sessions = []

    def __call__(self):
        owner = self
        class Session(requests.Session):
            def __init__(self):
                super().__init__()
                self.mode, self.jpeg, self.folder = owner.mode, owner.jpeg, owner.folder
                self.cancelled = owner.cancelled
                self.metadata = self.images = 0
                self.responses = []
                self.closed_by_core = False
                self.mount('https://', Adapter(self))
            def close(self):
                self.closed_by_core = True
                super().close()
                if self.mode == 'close-error':
                    raise requests.exceptions.SSLError('FAKE_PATH_TOKEN/FAKE_QUERY_TOKEN')
        session = Session()
        self.sessions.append(session)
        return session

    def stats(self):
        return [dict(metadataGET=s.metadata, imageGET=s.images, closed=s.closed_by_core,
                     responsesClosed=all(r.closed_by_core for r in s.responses),
                     cookiesRemaining=len(s.cookies)) for s in self.sessions]
