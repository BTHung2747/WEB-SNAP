"""LAB ONLY: fake libc answers; admission still validates every public row."""
import os,socket,time
if os.environ.get('EGRESS_TLS_MEDIA_FIXTURE')=='1':import media_site
if os.environ.get('EGRESS_STEP3_FIXTURE')=='1':
    original=socket.getaddrinfo
    def dns(host,port,*args,**kwargs):
        if host in ('fixture.tiktok.com','www.tiktok.com','media.tiktokcdn.com'):
            return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
        return original(host,port,*args,**kwargs)
    socket.getaddrinfo=dns
