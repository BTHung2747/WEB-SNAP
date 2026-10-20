import sys, json, pathlib, os, subprocess, math
# TikTok is an explicit default-off branch; the legacy YouTube implementation below is unchanged.
if len(sys.argv)>=4:
    from urllib.parse import urlsplit
    try:_dispatch_host=urlsplit(sys.argv[2]).hostname
    except ValueError:_dispatch_host=None
    if _dispatch_host in ('tiktok.com','www.tiktok.com','vt.tiktok.com','vm.tiktok.com'):
        if os.environ.get('TIKTOK_ADAPTER_ENABLED')!='1':
            print(json.dumps({'error':'UNSUPPORTED_PLATFORM'}));sys.exit(1)
        sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent.parent/'apps/media/src'))
        if '/photo/' in urlsplit(sys.argv[2]).path:
            from tiktok.photo_adapter import main as tiktok_main
        else:
            from tiktok.adapter import main as tiktok_main
        sys.exit(tiktok_main(sys.argv[1:]))
import yt_dlp
class Rejected(Exception):pass
phase,url,folder=sys.argv[1:4]
folder=pathlib.Path(folder);folder.mkdir(parents=True,exist_ok=True)
max_input=int(os.environ.get('ADAPTER_MAX_INPUT','262144000'))
max_output=int(os.environ.get('ADAPTER_MAX_OUTPUT','209715200'))
duration_limit=int(os.environ.get('ADAPTER_MAX_DURATION','600'))
counts={}
network_bytes=0
class BoundedYoutubeDL(yt_dlp.YoutubeDL):
    def urlopen(self, req):
        response=super().urlopen(req)
        cap=8388608 if phase=='analyze' else max_input
        try:
            length=int(response.headers.get('Content-Length') or 0)
            if length>cap:response.close();raise Rejected('LIMIT_EXCEEDED')
        except ValueError:pass
        original=response.read;read_bytes=0
        def bounded_read(amt=None):
            nonlocal read_bytes
            global network_bytes
            # Only one detection byte beyond BOTH the response and aggregate budgets.
            remaining=min(cap-read_bytes,max_input-network_bytes)
            if remaining<0:response.close();raise Rejected('LIMIT_EXCEEDED')
            requested=min(amt,remaining+1) if amt is not None and amt>=0 else remaining+1
            data=original(requested);read_bytes+=len(data);network_bytes+=len(data)
            if read_bytes>cap or network_bytes>max_input:response.close();raise Rejected('LIMIT_EXCEEDED')
            return data
        response.read=bounded_read
        return response
def hook(d):
    key=d.get('filename','unknown');counts[key]=max(counts.get(key,0),d.get('downloaded_bytes',0))
    if sum(counts.values())>max_input:raise Rejected('LIMIT_EXCEEDED')
    total=sum(f.stat().st_size for f in folder.rglob('*') if f.is_file())
    if total>max_input+max_output:raise Rejected('LIMIT_EXCEEDED')
opts={'proxy':os.environ.get('MEDIA_PROXY','http://egress:8888'),'quiet':True,'noprogress':True,'no_warnings':True,'noplaylist':True,'cachedir':False,'socket_timeout':10,'retries':1,'fragment_retries':1,'extractor_retries':0,'js_runtimes':{'node':{}},'remote_components':[], 'max_filesize':max_input,'progress_hooks':[hook], 'concurrent_fragment_downloads':1,'hls_prefer_native':True,'external_downloader':{'default':'native'},'outtmpl':str(folder/'media.%(ext)s'),'merge_output_format':'mp4','overwrites':False}
if phase=='prepare':opts['format']=sys.argv[4]
def valid(info):
    if info.get('_type') in ('playlist','multi_video') or info.get('is_live') or info.get('live_status') in ('is_live','is_upcoming'):raise Rejected('UNSUPPORTED_CONTENT')
    if info.get('availability') in ('private','premium_only','subscriber_only','needs_auth'):raise Rejected('AUTH_REQUIRED')
    if not isinstance(info.get('duration'),(int,float)) or not math.isfinite(info['duration']) or info['duration']>duration_limit:raise Rejected('LIMIT_EXCEEDED')
    if info.get('age_limit',0)>0:raise Rejected('AUTH_REQUIRED')
def formats(info):
    fs=info.get('formats',[]);rows=[]
    for f in fs:
        fid=str(f.get('format_id',''))
        if not fid or not all(c.isalnum() or c in '_-' for c in fid):continue
        # Progressive HTTPS MP4; separate HTTPS H.264/AAC streams are merged by copy.
        if f.get('ext')=='mp4' and f.get('protocol')=='https' and f.get('vcodec','none')!='none' and f.get('acodec','none')!='none' and not f.get('has_drm'):
            size=f.get('filesize');
            if size and size>max_output:continue
            rows.append({'id':fid,'label':str(f.get('height') or '?')+'p · MP4 · có tiếng','size':size,'height':f.get('height'),'kind':'video'})
    audio=[a for a in fs if a.get('ext')=='m4a' and a.get('protocol')=='https' and a.get('vcodec','none')=='none' and str(a.get('acodec','')).startswith('mp4a') and not a.get('has_drm') and all(c.isalnum() or c in '_-' for c in str(a.get('format_id','')))]
    audio=sorted(audio,key=lambda a:a.get('abr') or 0,reverse=True)
    if audio:
        a=audio[0]
        for v in fs:
            if v.get('ext')!='mp4' or v.get('protocol')!='https' or v.get('acodec','none')!='none' or not str(v.get('vcodec','')).startswith(('avc1','h264')) or v.get('has_drm'):continue
            fid=str(v.get('format_id',''))
            if not fid or not all(c.isalnum() or c in '_-' for c in fid):continue
            size=v.get('filesize')+a.get('filesize') if v.get('filesize') and a.get('filesize') else None
            if size and (size>max_output or size>max_input):continue
            rows.append({'id':fid+'+'+str(a['format_id']),'label':str(v.get('height') or '?')+'p · MP4 · có tiếng','size':size,'height':v.get('height'),'kind':'video'})
    return sorted(rows,key=lambda r:r.get('height') or 0)[:30]
try:
    with BoundedYoutubeDL(opts) as ydl:
        info=ydl.extract_info(url,download=False);valid(info);rows=formats(info)
        if not rows:raise Rejected('FORMAT_UNAVAILABLE')
        if phase=='analyze':
            # Preview is downloaded through the same SSRF-controlled proxy; no signed URL is exposed.
            thumb=info.get('thumbnail')
            if thumb and thumb.startswith('https://'):
                try:
                    with ydl.urlopen(thumb) as response:data=response.read(2097153)
                    if len(data)<=2097152 and (data.startswith(b'\xff\xd8\xff') or data.startswith(b'\x89PNG\r\n\x1a\n')):(folder/'preview').write_bytes(data)
                except Exception:pass
            print(json.dumps({'title':str(info.get('title','Video'))[:300],'duration':info['duration'],'formats':rows},ensure_ascii=False))
        else:
            selected=sys.argv[4]
            if selected not in [r['id'] for r in rows]:raise Rejected('FORMAT_UNAVAILABLE')
            ydl.params['format']=selected
            ydl.process_ie_result(info,download=True)
            files=[f for f in folder.glob('media.*') if f.suffix=='.mp4']
            if len(files)!=1 or files[0].stat().st_size>max_output:raise Rejected('LIMIT_EXCEEDED')
            p=subprocess.run(['ffprobe','-v','error','-show_entries','stream=codec_type,height:format=duration','-of','json',str(files[0])],capture_output=True,text=True,timeout=10)
            if p.returncode:raise Rejected('FORMAT_UNAVAILABLE')
            probe=json.loads(p.stdout);kinds=[s['codec_type'] for s in probe.get('streams',[])]
            if 'video' not in kinds or 'audio' not in kinds:raise Rejected('FORMAT_UNAVAILABLE')
            chosen=next(r for r in rows if r['id']==selected)
            if chosen.get('height') and not any(s.get('height')==chosen['height'] for s in probe.get('streams',[]) if s.get('codec_type')=='video'):raise Rejected('FORMAT_UNAVAILABLE')
            try:probed_duration=float(probe['format'].get('duration'))
            except (TypeError,ValueError):raise Rejected('LIMIT_EXCEEDED')
            if not math.isfinite(probed_duration) or probed_duration>duration_limit:raise Rejected('LIMIT_EXCEEDED')
            print(json.dumps({'file':'media.mp4','size':files[0].stat().st_size,'inputBytes':network_bytes}))
except Exception as e:
    message=str(e).lower()
    code=str(e) if isinstance(e,Rejected) else ('AUTH_REQUIRED' if any(s in message for s in ['sign in','login','log in','private']) else 'FORMAT_UNAVAILABLE' if 'requested format is not available' in message else 'SOURCE_TIMEOUT' if 'timed out' in message else 'LIMIT_EXCEEDED' if 'filesize' in message else 'CONTENT_UNAVAILABLE')
    # Do not print extractor exception: it can contain a signed URL or headers.
    print(json.dumps({'error':code}));sys.exit(1)
