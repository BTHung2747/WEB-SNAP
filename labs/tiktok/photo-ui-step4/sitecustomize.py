"""LAB ONLY: fake libc answers; admission still validates every public row."""
import os,socket,time
if os.environ.get('EGRESS_TLS_MEDIA_FIXTURE')=='1' and 'youtube.com' in ' '.join(__import__('sys').argv[:3]):
    import yt_dlp,json,pathlib,sys
    def fake_extract(self,*args,**kwargs):return {'id':'fixture','title':'YouTube fixture','duration':2,'formats':[{'format_id':'18','ext':'mp4','protocol':'https','vcodec':'h264','acodec':'aac','height':64}]}
    yt_dlp.YoutubeDL.extract_info=fake_extract
    target=pathlib.Path('/control/jobs')/pathlib.Path(sys.argv[3]).name;target.mkdir(parents=True,exist_ok=True)
    (target/'legacy-env.json').write_text(json.dumps(dict(connectScopePresent=bool(os.environ.get('WED_EGRESS_PHASE') or os.environ.get('WED_EGRESS_CAP')),controlSecretPresent=bool(os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET')))))
if os.environ.get('EGRESS_TLS_MEDIA_FIXTURE')=='1':import media_site
if os.environ.get('EGRESS_TLS_MEDIA_FIXTURE')=='1' and __import__('sys').argv[0].endswith('media_adapter.py'):
    import json,pathlib,sys,signal,time,hashlib
    from tiktok import photo_adapter
    try:case=json.loads((pathlib.Path('/control/jobs')/pathlib.Path(sys.argv[3]).name/'case.json').read_text())['mode']
    except FileNotFoundError:case='normal'
    real=photo_adapter.main
    def main(args):
        assert not os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET')
        result=real(args);sys.stdout.flush()
        folder=pathlib.Path(args[2]);control=pathlib.Path('/control/jobs')/folder.name;control.mkdir(parents=True,exist_ok=True)
        file=folder/'image.jpg'
        # Preserve numeric native Operations evidence before the lab tmpfs is removed.
        if (folder/'tiktok-operations.jsonl').exists():
            import shutil
            shutil.copyfile(folder/'tiktok-operations.jsonl',control/'operations.jsonl')
        with (control/'native.jsonl').open('a') as f:f.write(json.dumps(dict(phase=args[0],pid=os.getpid(),pgid=os.getpgrp(),coreExit=result,fileExists=file.exists(),controlSecretAbsent=not bool(os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET')),sha256=hashlib.sha256(file.read_bytes()).hexdigest() if file.exists() else None))+'\n')
        if result==0 and case=='deadline-gate':time.sleep(3.5)
        if result==0 and case==args[0]+'-exit20':return 20
        if result==0 and case==args[0]+'-hang':signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(180)
        return result
    photo_adapter.main=main
if os.environ.get('EGRESS_STEP3_FIXTURE')=='1':
    original=socket.getaddrinfo
    def dns(host,port,*args,**kwargs):
        if host in ('fixture.tiktok.com','www.tiktok.com','media.tiktokcdn.com'):
            return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]*3
        return original(host,port,*args,**kwargs)
    socket.getaddrinfo=dns
