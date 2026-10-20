"""P37.2 shared helpers (lab only): sanitize, clamp-before-read bounded reader, structured logger."""
import re, urllib.parse

URL_RE = re.compile(r'https?://[^\s\'"<>)\]]+', re.I)
SECRET_RE = re.compile(r'(?i)\b(mstoken|x-bogus|_signature|signature|token|cookie|sessionid|tt_chain_token|auth|key|sign|expires|policy|credential|password|secret|bearer)=[^\s&\'"]+')
HDR_RE = re.compile(r'(?i)\b(authorization|proxy-authorization|cookie|set-cookie|x-tt-[\w-]+)\s*:\s*[^\r\n]+')


def sanitize(text, limit=400):
    """Drop query/fragment/userinfo from every URL, mask token-like pairs and sensitive headers."""
    if text is None:
        return None
    text = str(text)

    def sanitize_url(m):
        raw = m.group(0)
        try:
            u = urllib.parse.urlsplit(raw)
            port = u.port
        except ValueError:
            return '[url]'
        host = u.hostname or ''
        if port:
            host = f"{host}:{port}"
        path = u.path if len(u.path) <= 80 else u.path[:80] + '...'
        has_q_or_f = bool(u.query or u.fragment)
        return '%s://%s%s%s' % (u.scheme, host, path, '[q-redacted]' if has_q_or_f else '')

    text = URL_RE.sub(sanitize_url, text)
    text = HDR_RE.sub(lambda m: m.group(1) + ': [redacted]', text)
    text = SECRET_RE.sub(lambda m: m.group(1) + '=[redacted]', text)
    return text[:limit]


class LimitExceeded(Exception):
    pass


class Budget:
    """Aggregate budget shared by all responses of one attempt."""
    def __init__(self, response_cap, aggregate_cap):
        self.response_cap = response_cap
        self.aggregate_cap = aggregate_cap
        self.total = 0


def bound_response(resp, budget, sniff=None, on_finalize=None):
    """Replace resp.read and resp.close with a bounded reader that clamps requested size
    BEFORE reading (remaining+1, like production), so nothing larger than cap+1 byte is ever allocated.
    Finalizes markers and decoded bytes when:
    - Caller reads in one shot via read(None) or read()
    - Caller reads in chunks until EOF (data == b'')
    - resp.close() is called
    - Limit is exceeded, or an error/timeout occurs during read
    `sniff(bytes)` receives chunks (for marker detection) and is never persisted.
    `on_finalize(state)` is called exactly once with final state."""
    original_read = resp.read
    original_close = getattr(resp, 'close', lambda: None)
    state = {'n': 0, 'finalized': False, 'error': None}

    def _do_finalize(err=None):
        if not state['finalized']:
            state['finalized'] = True
            if err:
                state['error'] = sanitize(err)
            if on_finalize:
                try:
                    on_finalize(state)
                except Exception:
                    pass

    def read(amt=None):
        if amt == 0:
            return b''  # Zero-length reads are not evidence of EOF.
        remaining = min(budget.response_cap - state['n'], budget.aggregate_cap - budget.total)
        if remaining < 0:
            _do_finalize('LIMIT_EXCEEDED')
            try:
                original_close()
            except Exception:
                pass
            raise LimitExceeded('LIMIT_EXCEEDED')

        want = remaining + 1
        requested = min(amt, want) if (amt is not None and amt >= 0) else want
        try:
            data = original_read(requested)
        except BaseException as e:
            _do_finalize(type(e).__name__ + ': ' + str(e))
            raise

        data_len = len(data) if data else 0
        state['n'] += data_len
        budget.total += data_len

        if state['n'] > budget.response_cap or budget.total > budget.aggregate_cap:
            _do_finalize('LIMIT_EXCEEDED')
            try:
                original_close()
            except Exception:
                pass
            raise LimitExceeded('LIMIT_EXCEEDED')

        if sniff and data:
            try:
                sniff(data)
            except Exception:
                pass

        # Finalize if EOF is detected:
        # 1. data is empty (stream EOF)
        # 2. caller performed a one-shot read (amt is None or amt < 0) and received less than requested clamp
        if not data or ((amt is None or amt < 0) and data_len < requested):
            _do_finalize()

        return data

    def close():
        _do_finalize('CLOSED')
        return original_close()

    resp.read = read
    resp.close = close
    return state


class SafeLogger:
    """yt-dlp logger that keeps sanitized, length-limited lines (warnings are NOT hidden)."""
    def __init__(self):
        self.lines = []

    def _add(self, level, msg):
        if len(self.lines) < 40:
            self.lines.append({'level': level, 'msg': sanitize(msg, 300)})

    def debug(self, msg):
        if msg.startswith('[debug] '):
            return
        self._add('info', msg)

    def info(self, msg):
        self._add('info', msg)

    def warning(self, msg):
        self._add('warning', msg)

    def error(self, msg):
        self._add('error', msg)
