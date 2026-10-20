"""Fixture-only DNS child override: no public resolver fallback."""
import json,os,pathlib,socket
if os.environ.get('STEP5_OFFLINE_DNS')=='1':
    def fixture_dns(host,port,*args,**kwargs):
        allowed=host in ('www.tiktok.com','media.tiktokcdn.com')
        with pathlib.Path('/control/fixture-dns.jsonl').open('a') as file:
            file.write(json.dumps(dict(event='FIXTURE_DNS' if allowed else 'DENIED_DNS',publicQueries=0,rawRows=3 if allowed else 0))+'\n')
        if not allowed:raise socket.gaierror(socket.EAI_NONAME,'FIXTURE_ONLY')
        return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
    socket.getaddrinfo=fixture_dns
