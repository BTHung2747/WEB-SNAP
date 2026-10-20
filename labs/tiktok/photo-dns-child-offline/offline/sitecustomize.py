"""Only mounted for offline proxy helper processes, never on any source container."""
import os,socket
if os.environ.get('STEP5_OFFLINE_DNS')=='1':
    original=socket.getaddrinfo
    def dns(host,port,*a,**kw):
        if host in ('www.tiktok.com','media.tiktokcdn.com'):
            return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
        return original(host,port,*a,**kw)
    socket.getaddrinfo=dns
