"""AGPL-3.0 WED SNAP photo core, intentionally NOT wired to a CLI or application.

Callers must run each call in a separate supervised child. The parent owns the
absolute wall deadline/process-group reap and post-SIGKILL job cleanup, as with
the existing app adapter. Importing this module grants no source capability.
"""
from dataclasses import dataclass
import math
import os
import pathlib
import re
import stat
import subprocess
import time
import urllib.parse

import requests
from yt_dlp.networking import Request
from yt_dlp.utils import DownloadError
from .adapter import Rejected, bound, owned_folder
from .core import Budget, GuardedYDL, versions
from .photo_proxy import PhotoProxyAdapter
from .photo_contract import PhotoError, require, summary, select, public_metadata
from .photo_file import inspect_jpeg
from .prepare_operations import Operations

MIB = 1024 * 1024


@dataclass(frozen=True)
class PhotoLimits:
    input_bytes: int = 36 * MIB
    output_bytes: int = 16 * MIB
    metadata_seconds: float = 30
    prepare_seconds: float = 180

    def validate(self):
        require(type(self.input_bytes) is int and 0 < self.input_bytes <= 36 * MIB
                and type(self.output_bytes) is int and 0 < self.output_bytes <= 16 * MIB, 'LIMIT_EXCEEDED')
        for value, cap in ((self.metadata_seconds, 30), (self.prepare_seconds, 180)):
            require(type(value) in (int, float) and math.isfinite(value) and 0 < value <= cap, 'LIMIT_EXCEEDED')
        return self

    @classmethod
    def from_env(cls):
        return cls(min(36 * MIB, bound('ADAPTER_MAX_INPUT', 250 * MIB, 250 * MIB)),
                   min(16 * MIB, bound('ADAPTER_MAX_OUTPUT', 200 * MIB, 200 * MIB)),
                   bound('ADAPTER_ANALYZE_TIMEOUT', 30, 30),
                   bound('ADAPTER_PREPARE_TIMEOUT', 180, 180)).validate()


def input_photo(url):
    try:
        u = urllib.parse.urlsplit(url)
        require(u.scheme == 'https' and u.hostname in ('www.tiktok.com', 'tiktok.com')
                and not u.username and not u.password and not u.port and not u.query and not u.fragment,
                'INVALID_URL')
        match = re.fullmatch(r'/@[A-Za-z0-9_.-]+/photo/([0-9]{15,22})', u.path)
        require(match is not None, 'INVALID_URL')
        return 'https://www.tiktok.com' + u.path.replace('/photo/', '/video/'), match[1]
    except (TypeError, ValueError):
        raise PhotoError('INVALID_URL') from None


class PhotoBudget(Budget):
    def __init__(self, limits, phase, cancelled=None):
        self.cancelled = cancelled
        self.prepare_end = time.monotonic() + (limits.metadata_seconds if phase == 'analyze' else limits.prepare_seconds)
        self.metadata_bytes = 0
        super().__init__(limits.input_bytes, limits.output_bytes, self.prepare_end, limits.metadata_seconds)

    def check(self):
        if self.cancelled is not None and self.cancelled():
            raise PhotoError('CANCELLED')
        super().check()

    def begin_image(self):
        self.check()
        now = time.monotonic()
        require(self.prepare_end - now > 10, 'SOURCE_TIMEOUT')
        self.metadata_bytes = self.total
        self.mode = 'prepare'
        self.requests = 0
        self.max_requests = 1
        self.total = 0
        # The aggregate counter is never reset. Metadata has already consumed input.
        self.response_cap = min(20 * MIB, self.input_cap - self.network_total)
        self.total_cap = self.response_cap
        require(self.response_cap > 0, 'LIMIT_EXCEEDED')
        self.deadline = min(now + 60, self.prepare_end - 10)


class _SessionOwner:
    """Delegate public Session/Adapter APIs; retain responses until physical close.

    GuardedYDL can reject a deadline/cancel after Adapter.send returns and before
    its body wrapper exists. Owning that returned Response closes this gap without
    changing HTTP/TLS, exceptions, redirect behavior or cookie preparation.
    """
    def __init__(self, base):
        self.base = base
        self.responses = []
        self.closed = False

    @property
    def cookies(self):
        return self.base.cookies

    @cookies.setter
    def cookies(self, value):
        self.base.cookies = value

    @property
    def trust_env(self):
        return self.base.trust_env

    @trust_env.setter
    def trust_env(self, value):
        self.base.trust_env = value

    def prepare_request(self, request):
        return self.base.prepare_request(request)

    def get_adapter(self, url):
        adapter = self.base.get_adapter(url)
        owner = self

        class ResponseOwner:
            def send(self, *args, **kwargs):
                response = adapter.send(*args, **kwargs)
                owner.responses.append(response)
                return response
        return ResponseOwner()

    def close(self):
        if self.closed:
            return
        self.closed = True
        failed = False
        for response in self.responses:
            try:
                response.close()
            except Exception:
                failed = True
        self.responses.clear()
        try:
            self.base.close()
        except Exception:
            failed = True
        finally:
            self.base.cookies.clear()
        require(not failed, 'CONTENT_UNAVAILABLE')


class PhotoYDL(GuardedYDL):
    """Delegate transport unchanged; prevent a stale challenge body being reused."""
    def __init__(self, budget, folder, session_factory=None):
        self.source_failed = False
        # Explicit public adapter construction keeps the existing observer/retry0
        # when GuardedYDL receives our owning session factory.
        base = (session_factory or requests.Session)()
        if session_factory is None:
            base.mount('https://', PhotoProxyAdapter(max_retries=0))
        lease = _SessionOwner(base)
        try:
            super().__init__(budget, folder, session_factory=lambda: lease)
        except BaseException:
            lease.close()
            raise

    def urlopen(self, request):
        if self.budget.mode == 'metadata':
            self.budget.latest_body = None
        try:
            return super().urlopen(request)
        except BaseException:
            self.source_failed = True
            raise

    def close(self):
        try:
            super().close()
        finally:
            # RAM credentials/body must clear even if a library close fails.
            self.cookiejar.clear()
            self.budget.latest_body = None


def _metadata(ydl, target, expected):
    ydl.allowed_url = target
    try:
        ydl.extract_info(target, download=False, ie_key='TikTok', process=False)
    except DownloadError:
        # TikTokIE can reject imagePost as a video after reading the final body.
        # Failed transport/cap/deadline or a partially read response never qualifies.
        if ydl.source_failed or ydl.budget.failure or ydl.budget.latest_body is None:
            raise
    b = ydl.budget
    b.check()
    require(b.latest_body is not None, 'PHOTO_METADATA_UNAVAILABLE')
    try:
        packet = subprocess.run(['node', str(pathlib.Path(__file__).with_name('photo_picker.mjs')), expected],
                                input=b.latest_body, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                timeout=min(2, b.deadline - time.monotonic()))
    finally:
        b.latest_body = None
    b.check()
    require(packet.returncode == 0 and len(packet.stdout) <= 128 * 1024, 'PHOTO_METADATA_UNAVAILABLE')
    import json
    private = json.loads(packet.stdout)
    public = summary(private, expected)
    return private, public


class _Output:
    """Exclusive fixed names; removal needs the inode created by this invocation."""
    def __init__(self, folder):
        self.part = folder / 'image.jpg.part'
        self.final = folder / 'image.jpg'
        self.identity = None
        self.published = False
        require(not os.path.lexists(self.part) and not os.path.lexists(self.final), 'PREEXISTING_OUTPUT')

    def open(self):
        fd = os.open(self.part, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        s = os.fstat(fd)
        self.identity = (s.st_dev, s.st_ino)
        return os.fdopen(fd, 'wb')

    def cleanup(self):
        if self.identity is None:
            return
        failed = False
        for path in (self.part, self.final):
            try:
                s = path.lstat()
                if stat.S_ISREG(s.st_mode) and (s.st_dev, s.st_ino) == self.identity:
                    path.unlink()
            except FileNotFoundError:
                pass
            except OSError:
                failed = True
        require(not failed, 'CLEANUP_FAILED')

    def publish(self):
        s = self.part.lstat()
        require(stat.S_ISREG(s.st_mode) and (s.st_dev, s.st_ino) == self.identity, 'INVALID_ASSET_PATH')
        # os.rename overwrites on POSIX. Link+unlink atomically publishes a complete
        # same-filesystem file with NO replacement, using only public stdlib APIs.
        try:
            os.link(self.part, self.final, follow_symlinks=False)
        except FileExistsError:
            raise PhotoError('OUTPUT_COLLISION') from None
        self.published = True
        self.part.unlink()


def _code(error, budget):
    if isinstance(error, PhotoError):
        return error.code
    if isinstance(error, Rejected) and error.args and error.args[0] in ('INVALID_ASSET_PATH', 'LIMIT_EXCEEDED'):
        return error.args[0]
    if budget is not None and budget.failure in ('DEADLINE', 'SOURCE_TIMEOUT'):
        return 'SOURCE_TIMEOUT'
    if budget is not None and budget.failure in ('BYTE_LIMIT', 'OUTPUT_LIMIT'):
        return 'LIMIT_EXCEEDED'
    if type(error) is subprocess.TimeoutExpired or (type(error) is RuntimeError and error.args == ('PREPARE_DEADLINE',)):
        return 'SOURCE_TIMEOUT'
    return 'CONTENT_UNAVAILABLE'


def _execute(phase, url, folder, selected=None, *, limits=None, session_factory=None, cancelled=None, diagnostics=None):
    budget = ydl = output = None
    success = False
    result = private = None
    try:
        target, expected = input_photo(url)
        require(diagnostics is None or type(diagnostics) is dict, 'CONTENT_UNAVAILABLE')
        folder = owned_folder(folder)
        for name in ('image.jpg', 'image.jpg.part'):
            require(not (folder / name).is_symlink(), 'INVALID_ASSET_PATH')
        limits = (PhotoLimits.from_env() if limits is None else limits).validate()
        versions()
        budget = PhotoBudget(limits, phase, cancelled)
        budget.check()
        if phase == 'prepare':
            output = _Output(folder)
        ydl = PhotoYDL(budget, folder, session_factory)
        private, public = _metadata(ydl, target, expected)
        if phase == 'analyze':
            result = public_metadata(public)
        else:
            chosen = select(public, selected)
            budget.begin_image()
            image = private['images'][chosen['index'] - 1]
            ydl.allowed_url = image['url']
            ops = Operations(budget.deadline, root=folder)
            with ops.step('DOWNLOADER', ops.timeout(60)):
                with ydl.urlopen(Request(image['url'])) as response:
                    mime = response.headers.get('Content-Type', '')
                    with output.open() as stream:
                        while True:
                            budget.check()
                            chunk = response.read(min(16384, limits.output_bytes - stream.tell() + 1))
                            if not chunk:
                                break
                            if stream.tell() + len(chunk) > limits.output_bytes:
                                budget.fail('OUTPUT_LIMIT')
                            stream.write(chunk)
                            budget.check()
            checked, digest = inspect_jpeg(output.part, mime, ops, chosen, budget.check)
            budget.check()
            require(0 < output.part.stat().st_size <= limits.output_bytes, 'LIMIT_EXCEEDED')
            output.publish()
            budget.check()
            result = dict(file='image.jpg', size=output.final.stat().st_size, inputBytes=budget.network_total,
                          sha256=digest, selectedIndex=chosen['index'], itemKey=chosen['itemKey'], contract=checked)
        # Physical close must succeed before a public result becomes successful.
        ydl.close()
        ydl = None
        budget.check()
        success = True
        return result
    except Exception as error:
        raise PhotoError(_code(error, budget)) from None
    finally:
        try:
            if ydl is not None:
                try:
                    ydl.close()
                except Exception:
                    raise PhotoError('CONTENT_UNAVAILABLE') from None
        finally:
            private = None
            if budget is not None:
                budget.latest_body = None
            if output is not None and not success:
                output.cleanup()
            if diagnostics is not None and budget is not None:
                # Trusted in-process numeric diagnostics, never a private picker/body.
                diagnostics.update(requests=budget.rows, inputBytes=budget.network_total,
                                   metadataBytes=budget.metadata_bytes if budget.mode == 'prepare' else budget.total,
                                   metadataResponseCap=min(8 * MIB, limits.input_bytes),
                                   metadataTotalCap=min(16 * MIB, limits.input_bytes),
                                   finalResponseCap=budget.response_cap)


def analyze_album(url, folder, **options):
    return _execute('analyze', url, folder, **options)


def prepare_photo(url, folder, selected, **options):
    return _execute('prepare', url, folder, selected, **options)
