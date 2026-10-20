"""Bounded real HTTP source on the isolated P3 private network; no outbound I/O."""
import hashlib
import json
import os
import pathlib
import socket
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

assert os.environ.get('P3_TEST_GUARD') == 'wed-snap-p3-test'
root = pathlib.Path('/control/socket-runs')
lock = threading.Lock()
runs = {}

def identity():
    p = pathlib.Path('/proc/self/stat').read_text().rsplit(') ', 1)[1].split()
    return dict(pid=os.getpid(), startTicks=p[19], namespace=os.readlink('/proc/self/ns/pid'))

def event(run, **fields):
    row = dict(at=time.time() * 1000, **fields)
    with lock:
        with (root / run / 'server.jsonl').open('a') as f:
            f.write(json.dumps(row) + '\n')
    print(json.dumps(dict(run=run, **row)), flush=True)

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *_args): pass
    def reply(self, data):
        body = json.dumps(data).encode()
        self.send_response(200); self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path == '/guard':
            return self.reply(dict(guard='wed-snap-p3-test', server='p3-real-socket-v1', **identity()))
        parts = self.path.split('/')
        assert len(parts) == 5 and parts[1] == 'media'
        _, _, run, job, mode = parts
        uuid.UUID(run); uuid.UUID(job)
        assert run in runs and mode in ('control', 'close', 'stall')
        state = runs[run]; payload = state['payload']
        with lock:
            count = state['counts'].get(job, 0) + 1; state['counts'][job] = count
        assert count <= 2, 'Finite retries: at most two GET attempts per job'
        # Resume is supported by the real HttpFD. Each response is independently bounded.
        header = self.headers.get('Range', '')
        offset = int(header.removeprefix('bytes=').split('-')[0]) if header else 0
        assert 0 <= offset < len(payload)
        remaining = payload[offset:]; assert len(remaining) <= 262144
        self.send_response(206 if header else 200)
        self.send_header('Content-Type', 'video/mp4')
        self.send_header('Content-Length', str(len(remaining)))
        if header: self.send_header('Content-Range', f'bytes {offset}-{len(payload)-1}/{len(payload)}')
        self.end_headers()
        event(run, event='request', job=job, mode=mode, attempt=count, offset=offset,
              declaredBytes=len(remaining), socketTimeout=10)
        initial = min(16384, len(remaining) // 2)
        sent = 0; reason = 'server-error'
        try:
            self.wfile.write(remaining[:initial]); self.wfile.flush(); sent = initial
            event(run, event='partial_sent', job=job, mode=mode, attempt=count, sentBytes=sent)
            gate = root / run / (job + '.allow')
            end = time.monotonic() + 5
            while not gate.exists():
                assert time.monotonic() < end, 'runner must assert pre-state within gate bound'
                time.sleep(0.01)
            event(run, event='trigger', job=job, mode=mode, attempt=count, sentBytes=sent)
            if mode == 'control':
                self.wfile.write(remaining[initial:]); self.wfile.flush(); sent = len(remaining)
                reason = 'full-body'
            elif mode == 'close':
                reason = 'deliberate-truncated-body'
            else:
                # No further bytes: real client read must expire at socket_timeout=10.
                # Finite server bound exceeds the client timeout and is below watchdog60s.
                time.sleep(16)
                reason = 'stall-server-bound-16s'
        except (BrokenPipeError, ConnectionResetError): reason = 'peer-disconnected'
        finally:
            event(run, event='close', job=job, mode=mode, attempt=count, sentBytes=sent,
                  declaredBytes=len(remaining), reason=reason)
            self.close_connection = True
            try: self.connection.shutdown(socket.SHUT_RDWR)
            except OSError: pass
    def do_POST(self):
        assert self.path == '/arm'
        length = int(self.headers.get('Content-Length', 0)); assert 0 < length <= 1024
        data = json.loads(self.rfile.read(length)); run = data['run']; uuid.UUID(run)
        assert run not in runs
        # Arm is only called AFTER host actual-container and runner server guards.
        path = pathlib.Path('/tmp') / (run + '.mp4')
        subprocess.run(['ffmpeg', '-v', 'error', '-threads', '1', '-f', 'lavfi', '-i',
                        'testsrc2=size=128x72:rate=12', '-f', 'lavfi', '-i', 'sine=frequency=440',
                        '-t', '4', '-c:v', 'mpeg4', '-threads', '1', '-q:v', '2', '-c:a', 'aac',
                        '-b:a', '32k', '-movflags', '+faststart', str(path)], check=True, timeout=15)
        payload = path.read_bytes(); path.unlink()
        assert 32768 < len(payload) <= 262144
        (root / run).mkdir(parents=True)
        runs[run] = dict(payload=payload, counts={})
        meta = dict(bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest(), duration=4, height=72)
        event(run, event='armed', **meta, **identity())
        self.reply(meta)

server = ThreadingHTTPServer(('0.0.0.0', 8765), Handler)
server.daemon_threads = True
print(json.dumps(dict(event='server_guard_ready', bind='private:8765', **identity())), flush=True)
server.serve_forever()
