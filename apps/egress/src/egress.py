"""HTTPS CONNECT only. Resolve, reject all non-global IPs, connect to the validated IP.
Worker is on an internal Docker network: it cannot bypass this proxy for Internet access.
TLS is end-to-end; encrypted traffic is opaque (metadata caps enforced by media adapter).
"""
import socket, socketserver, select, ipaddress, os, time, pathlib, sys, io, http.client
if os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1':
    _base=pathlib.Path(__file__).resolve().parent
    sys.path.insert(0,str(_base/'vendor' if (_base/'vendor').is_dir() else _base.parent/'vendor'))
    from tiktok_policy.runtime import enabled as policy_enabled,server_class
else:
    def policy_enabled(host):return False
DOMAINS = os.environ.get('EGRESS_DOMAINS', 'youtube.com,youtu.be,googlevideo.com,ytimg.com,googleapis.com,tiktok.com,tiktokcdn.com,tiktokv.com,byteoversea.com,ibytedtos.com,fb.watch,facebook.com,fbcdn.net,fbsbx.com,x.com,twitter.com,twimg.com').split(',')
def allowed(host):
    return '@' not in host and any(host == d or host.endswith('.' + d) for d in DOMAINS if d)
def public_addresses(host):
    if not allowed(host): raise ValueError('host denied')
    addresses = socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses): raise ValueError('non-public DNS denied')
    return addresses
class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        upstream=None;policy=None;stage='SETUP';direction='UNKNOWN'
        try:
            self.connection.settimeout(10)
            line=self.rfile.readline(4097)
            if len(line)>4096: raise ValueError('request too large')
            if line.startswith(b'POST ') and os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1':
                from tiktok_policy.control import ControlHandler
                ControlHandler(self,line);return
            method,target,version=line.decode('ascii').strip().split(' ')
            if method!='CONNECT' or not version.startswith('HTTP/1.'): raise ValueError('CONNECT only')
            host,port=target.rsplit(':',1);host=host.lower().rstrip('.')
            if port!='443' or not host or ':' in host or '@' in host: raise ValueError('port denied')
            total=0;header_lines=[]
            while True:
                h=self.rfile.readline(4097);total+=len(h)
                if total>16384: raise ValueError('headers too large')
                if h in (b'\r\n',b'\n',b''): break
                header_lines.append(h)
            auth=None
            if os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1':
                from tiktok_policy.control import credentials
                auth=credentials(http.client.parse_headers(io.BytesIO(b''.join(header_lines)+b'\r\n')))
                if auth is not None and not policy_enabled(host):raise ValueError('PHASE_SCOPE')
            if policy_enabled(host):
                if not allowed(host):raise ValueError('host denied')
                policy=self.server.register_policy(self.request,auth)
                upstream=policy.connect(host)
            else:
                addresses=public_addresses(host)
                for family,kind,proto,_,addr in addresses:
                    try:
                        upstream=socket.socket(family,kind,proto);upstream.settimeout(10);upstream.connect(addr);break
                    except OSError:
                        if upstream: upstream.close()
                        upstream=None
            if upstream is None: raise ValueError('unreachable')
            stage='HANDOFF';direction='UNKNOWN'
            if policy:policy.before_handoff()
            direction='CLIENT'
            self.connection.sendall(b'HTTP/1.1 200 Connection established\r\n\r\n')
            direction='UNKNOWN'
            if policy:policy.after_handoff()
            last=time.monotonic();end=last+240
            while time.monotonic()<end and time.monotonic()-last<30:
                stage='RELAY_READ';direction='UNKNOWN'
                ready,_,_=select.select([self.connection,upstream],[],[],1)
                for source in ready:
                    stage='RELAY_READ';direction='CLIENT' if source is self.connection else 'UPSTREAM'
                    buf=source.recv(65536)
                    if not buf:return
                    stage='RELAY_WRITE';direction='UPSTREAM' if source is self.connection else 'CLIENT'
                    (upstream if source is self.connection else self.connection).sendall(buf);last=time.monotonic()
        except Exception as error:
            if policy:
                policy.failed=True;policy.observe_failure(stage,direction,error)
            try:self.connection.sendall(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n')
            except OSError:pass
        finally:
            if upstream:
                try:upstream.close()
                except BaseException as error:
                    if policy:policy.observe_failure('FINISH','UPSTREAM',error)
                    raise
            if policy:policy.finish()
class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address=True
    daemon_threads=True
    request_queue_size=16
if os.environ.get('TIKTOK_EGRESS_POLICY_ENABLED')=='1':Server=server_class(Server)
if __name__=='__main__':
    Server(('0.0.0.0',8888),Handler).serve_forever()
