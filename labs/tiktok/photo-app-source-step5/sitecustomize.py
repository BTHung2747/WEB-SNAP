"""OFFLINE ENTRY ONLY, never mounted on a source import path."""
import os,socket
if os.environ.get('STEP5_OFFLINE_TLS')=='1':import media_site
if os.environ.get('EGRESS_STEP3_FIXTURE')=='1':
    original=socket.getaddrinfo
    def dns(host,port,*a,**kw):
        if host in ('www.tiktok.com','media.tiktokcdn.com'):
            return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
        return original(host,port,*a,**kw)
    socket.getaddrinfo=dns
