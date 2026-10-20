import subprocess,json,sys,re,os
p=subprocess.run(['yt-dlp','--ignore-config','--no-playlist','--no-cache-dir','--js-runtimes','node','--proxy',os.environ.get('MEDIA_PROXY',''),'--dump-single-json','--skip-download','--',sys.argv[1]],capture_output=True,text=True,timeout=45)
if p.returncode:
    print(re.sub(r'https?://\S+','[URL REDACTED]',p.stderr)[-3000:])
else:
    info=json.loads(p.stdout)
    print(json.dumps({'title':info.get('title'),'formats':[{k:f.get(k) for k in ['format_id','ext','protocol','height','vcodec','acodec','filesize','has_drm']} for f in info.get('formats',[])]},indent=2))
    print(re.sub(r'https?://\S+','[URL REDACTED]',p.stderr)[-3000:])
