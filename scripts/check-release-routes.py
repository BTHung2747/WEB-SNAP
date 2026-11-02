"""CI-only HTTP contract check: shared none-netns loopback, no live API/source."""
import http.client
from html.parser import HTMLParser
import json
import signal
import struct
import time
from urllib.parse import urljoin
import xml.etree.ElementTree as ET

HOST = 'release.example.invalid'
CANONICAL = 'https://savlivo.online'
PUBLIC = ('/', '/privacy', '/terms', '/report', '/ung-ho')
MAX_BODY = 256 * 1024
MAX_TOTAL = 2 * 1024 * 1024
ERROR_CODES = frozenset(('DEADLINE', 'ENCODING', 'BODY_CAP', 'STATUS', 'CSP', 'MIME',
                        'HTML_IDENTITY', 'ROBOTS_HEADER', 'PNG', 'PNG_DIMENSIONS',
                        'SVG', 'ROBOTS_FILE', 'SITEMAP_URLS', 'LOCATION',
                        'API_STATIC_FALLBACK', 'MISSING_STATIC_FALLBACK', 'READINESS'))


class GateError(Exception):
    def __init__(self, code):
        self.code = code if type(code) is str and code in ERROR_CODES else 'CHECK_ERROR'
        super().__init__(self.code)


class Head(HTMLParser):
    def __init__(self):
        super().__init__()
        self.canonicals = []
        self.title = False
        self.text = ''

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'title':
            self.title = True
        if tag == 'link' and attrs.get('rel') == 'canonical':
            self.canonicals.append(attrs.get('href'))

    def handle_endtag(self, tag):
        if tag == 'title':
            self.title = False

    def handle_data(self, data):
        if self.title:
            self.text += data


def require(ok, code):
    if not ok:
        raise GateError(code)


def run():
    deadline = time.monotonic() + 50
    total = 0
    http_requests = 0
    observed_status = None
    results = []
    current = 'READINESS'

    def request(path, port=8080):
        nonlocal total, http_requests, observed_status
        observed_status = None
        http_requests += 1
        require(http_requests <= 42, 'DEADLINE')  # <=20 readiness +22 fixed cases.
        left = deadline - time.monotonic()
        require(left > 0, 'DEADLINE')
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=min(5, left))
        try:
            host = HOST if port == 8080 else '127.0.0.1:8090'
            connection.request('GET', path, headers={'Host': host, 'Accept-Encoding': 'identity'})
            response = connection.getresponse()
            observed_status = response.status
            require(response.getheader('Content-Encoding', 'identity').lower() == 'identity', 'ENCODING')
            body = response.read(MAX_BODY + 1)
            total += len(body)
            require(len(body) <= MAX_BODY and total <= MAX_TOTAL, 'BODY_CAP')
            require(time.monotonic() < deadline, 'DEADLINE')
            return response.status, response.headers, body
        finally:
            connection.close()

    def case(name, path, expected, kind, value=None):
        nonlocal current
        current = name
        status, headers, body = request(path)
        results.append({'case': name, 'status': status})
        require(status == expected, 'STATUS')
        mime = headers.get_content_type()
        script_policy = next((part.strip() for part in headers.get('Content-Security-Policy', '').split(';') if part.strip().startswith('script-src ')), '')
        require("'self'" in script_policy and "'unsafe-inline'" not in script_policy, 'CSP')
        if kind in ('PUBLIC', 'ADMIN'):
            require(mime == 'text/html', 'MIME')
            head = Head()
            head.feed(body.decode('utf-8'))
            require(head.canonicals == [CANONICAL + value] and 'WED SNAP' in head.text, 'HTML_IDENTITY')
            require(('noindex' in headers.get('X-Robots-Tag', '').lower()) == (kind == 'ADMIN'), 'ROBOTS_HEADER')
        elif kind == 'PNG':
            require(mime == 'image/png' and body[:8] == b'\x89PNG\r\n\x1a\n' and len(body) >= 24, 'PNG')
            require(struct.unpack('>II', body[16:24]) == value, 'PNG_DIMENSIONS')
        elif kind == 'SVG':
            require(mime == 'image/svg+xml' and ET.fromstring(body).tag == '{http://www.w3.org/2000/svg}svg', 'SVG')
        elif kind == 'ROBOTS':
            require(mime == 'text/plain' and b'Sitemap: https://savlivo.online/sitemap.xml' in body, 'ROBOTS_FILE')
        elif kind == 'SITEMAP':
            require(mime in ('application/xml', 'text/xml'), 'MIME')
            urls = [node.text for node in ET.fromstring(body).iter('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')]
            require(urls == [CANONICAL + path for path in PUBLIC] and b'lastmod' not in body, 'SITEMAP_URLS')
        elif kind == 'REDIRECT':
            require(urljoin('http://' + HOST + path, headers.get('Location', '')) == 'http://' + HOST + value, 'LOCATION')
        elif kind == 'API_UNAVAILABLE':
            require('noindex' in headers.get('X-Robots-Tag', '').lower(), 'ROBOTS_HEADER')
            require(b'id="root"' not in body and b'savlivo.online' not in body, 'API_STATIC_FALLBACK')
        elif kind == 'MISSING':
            require(b'id="root"' not in body, 'MISSING_STATIC_FALLBACK')

    try:
        ready = False
        for _ in range(20):
            try:
                ready = request('/healthz', 8090)[0] == 200
            except (OSError, http.client.HTTPException):
                pass
            if ready:
                break
            time.sleep(.25)
        require(ready, 'READINESS')
        for number, path in enumerate(PUBLIC):
            case('PUBLIC_' + str(number), path, 200, 'PUBLIC', path)
        for number, path in enumerate(('/admin', '/admin/settings')):
            case('ADMIN_' + str(number), path, 200, 'ADMIN', '/admin')
        case('FAVICON', '/favicon.png', 200, 'PNG', (96, 96))
        case('MOBILE_ICON', '/apple-touch-icon.png', 200, 'PNG', (180, 180))
        case('SHARE_IMAGE', '/brand/share.png', 200, 'PNG', (1200, 630))
        case('BRAND_SVG', '/brand/mark.svg', 200, 'SVG')
        case('ROBOTS', '/robots.txt', 200, 'ROBOTS')
        case('SITEMAP', '/sitemap.xml', 200, 'SITEMAP')
        for number, (path, target) in enumerate((('/index.html', '/'), ('/privacy/', '/privacy'), ('/terms/', '/terms'), ('/report/', '/report'), ('/ung-ho/', '/ung-ho'))):
            case('REDIRECT_' + str(number), path, 308, 'REDIRECT', target)
        for number, path in enumerate(('/missing-release-page', '/assets/missing-release.js', '/brand/missing-release.png')):
            case('MISSING_' + str(number), path, 404, 'MISSING')
        case('API_UPSTREAM_UNAVAILABLE', '/api/v1/health', 502, 'API_UNAVAILABLE')
        print(json.dumps({'event': 'release_http_routes', 'result': 'PASS', 'cases': results,
                          'responseBytes': total, 'httpRequests': http_requests,
                          'apiMeaning': 'EXPECTED_502_NOT_API_OR_SOURCE_PASS',
                          'sourceRequests': 0}), flush=True)
        return 0
    except Exception as error:
        code = error.code if type(error) is GateError else 'TIMEOUT' if isinstance(error, TimeoutError) else 'HTTP_ERROR' if isinstance(error, (OSError, http.client.HTTPException)) else 'CHECK_ERROR'
        print(json.dumps({'event': 'release_http_routes', 'result': 'FAIL', 'case': current,
                          'code': code, 'status': observed_status, 'cases': results}), flush=True)
        return 20


if __name__ == '__main__':
    def alarm(_signal, _frame):
        raise GateError('DEADLINE')
    signal.signal(signal.SIGALRM, alarm)
    signal.alarm(55)  # Independent of a blocked socket read; outer CI timeout remains.
    raise SystemExit(run())
