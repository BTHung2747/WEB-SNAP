"""HTTPS CONNECT only. Resolve, reject all non-global IPs, connect to the validated IP.
Worker is on an internal Docker network: it cannot bypass this proxy for Internet access.
TLS is end-to-end; encrypted traffic is opaque (metadata caps enforced by media adapter).
"""
import socket, socketserver, select, ipaddress, os, time
from trace import TraceSink,CURRENT,call
TRACE=TraceSink('/out/proxy-trace.jsonl')
DOMAINS = os.environ.get('EGRESS_DOMAINS', 'youtube.com,youtu.be,googlevideo.com,ytimg.com,googleapis.com,tiktok.com,tiktokcdn.com,tiktokv.com,byteoversea.com,ibytedtos.com,fb.watch,facebook.com,fbcdn.net,fbsbx.com,x.com,twitter.com,twimg.com').split(',')
def allowed(host):
    return '@' not in host and any(host == d or host.endswith('.' + d) for d in DOMAINS if d)
def public_addresses(host):
    if not allowed(host): raise ValueError('host denied')
    return call('DNS_LOOKUP',validated_addresses,host,after=lambda addresses:{
        'ipv4Count':sum(a[0]==socket.AF_INET for a in addresses),
        'ipv6Count':sum(a[0]==socket.AF_INET6 for a in addresses)})
def validated_addresses(host):
    addresses = socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
    if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses): raise ValueError('non-public DNS denied')
    return addresses
class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        upstream=None;handle_started=time.monotonic()
        connection=TRACE.connection();token=CURRENT.set(connection);opened=False;close_code='NOT_OPENED'
        try:
            self.connection.settimeout(10)
            line=self.rfile.readline(4097)
            if len(line)>4096: raise ValueError('request too large')
            method,target,version=line.decode('ascii').strip().split(' ')
            if method!='CONNECT' or not version.startswith('HTTP/1.'): raise ValueError('CONNECT only')
            host,port=target.rsplit(':',1);host=host.lower().rstrip('.')
            if port!='443' or not host or ':' in host or '@' in host: raise ValueError('port denied')
            total=0
            while True:
                h=self.rfile.readline(4097);total+=len(h)
                if total>16384: raise ValueError('headers too large')
                if h in (b'\r\n',b'\n',b''): break
            addresses=public_addresses(host)
            for index,(family,kind,proto,_,addr) in enumerate(addresses,1):
                try:
                    upstream=socket.socket(family,kind,proto);upstream.settimeout(10)
                    call('UPSTREAM_TCP_CONNECT',upstream.connect,addr,attemptIndex=index,
                         family='IPv4' if family==socket.AF_INET else 'IPv6' if family==socket.AF_INET6 else 'OTHER',
                         timeoutSeconds=upstream.gettimeout(),deadlineMonotonicSeconds=time.monotonic()+upstream.gettimeout())
                    break
                except OSError:
                    if upstream: upstream.close()
                    upstream=None
            if upstream is None: raise ValueError('unreachable')
            call('CONNECT_200_SENT',self.connection.sendall,b'HTTP/1.1 200 Connection established\r\n\r\n')
            opened=True;close_code='TIME_BOUND'
            last=time.monotonic();end=last+240
            while time.monotonic()<end and time.monotonic()-last<30:
                ready,_,_=select.select([self.connection,upstream],[],[],1)
                for source in ready:
                    buf=source.recv(65536)
                    if not buf:close_code='PEER_EOF';return
                    (upstream if source is self.connection else self.connection).sendall(buf);last=time.monotonic()
        except Exception:
            close_code='ERROR'
            try:self.connection.sendall(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n')
            except OSError:pass
        finally:
            try:
                if upstream:upstream.close()
            finally:
                connection.emit('TUNNEL_CLOSE','END',elapsed=time.monotonic()-handle_started,
                                code=close_code if opened else 'NOT_OPENED')
                CURRENT.reset(token)
class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address=True
    daemon_threads=True
    request_queue_size=16
if __name__=='__main__':
    Server(('0.0.0.0',8888),Handler).serve_forever()
