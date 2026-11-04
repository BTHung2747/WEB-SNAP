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
        if _dispatch_host in ('vt.tiktok.com','vm.tiktok.com') or urlsplit(sys.argv[2]).path.startswith('/t/'):
            from tiktok.shortlink import main as tiktok_main
        elif '/photo/' in urlsplit(sys.argv[2]).path:
            from tiktok.photo_adapter import main as tiktok_main
        else:
            if os.environ.get('TIKTOK_VIDEO_ENABLED')!='1':
                print(json.dumps({'error':'UNSUPPORTED_PLATFORM'}));sys.exit(1)
            from tiktok.adapter import main as tiktok_main
        sys.exit(tiktok_main(sys.argv[1:]))
import yt_dlp
import time,copy
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent.parent/'apps/media/src'))
from video_policy import full_hd
from audio_media import choice as audio_choice, encode as encode_audio, PREFIX as AUDIO_ID, AudioError, INPUT_CAP as AUDIO_INPUT, OUTPUT_CAP as AUDIO_OUTPUT
class Rejected(Exception):pass
def youtube_error_cause(error):
    from yt_dlp.utils import DownloadError
    for _ in range(2):
        if type(error) is not DownloadError:
            break
        wrapped = getattr(error, 'exc_info', None)
        if type(wrapped) is not tuple or len(wrapped) != 3 or not isinstance(wrapped[1], Exception):
            break
        error = wrapped[1]
    return error

def youtube_message_reason(error):
    """Classify the pinned extractor's message without inferring why access was challenged."""
    from yt_dlp.utils import ExtractorError
    import re
    if type(error) is not ExtractorError or getattr(error, 'expected', False) is not True:return 'UNKNOWN'
    text=getattr(error, 'orig_msg', None)
    if type(text) is not str or len(text)>4096:return 'UNKNOWN'
    # _video.py appends _base.py's login hint; common.py supplies its first part.
    # Require that exact construction, not free-form exception keywords.
    hint=('Use --cookies-from-browser or --cookies for the authentication. '
          'See  https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp  for how to manually pass cookies. '
          'Also see  https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies  for tips on effectively exporting YouTube cookies')
    suffix='. '+hint
    if not text.endswith(suffix):return 'UNKNOWN'
    source=text[:-len(suffix)]
    first_sentence = source.split('. ', 1)[0]
    if re.fullmatch(r"sign in to confirm you['’]re not a bot", first_sentence, re.I | re.ASCII):
        return 'SOURCE_BOT_VERIFICATION_MESSAGE'
    if not re.search(r'\bsign in\b',source,re.I):return 'UNKNOWN'
    return 'SOURCE_AGE_MESSAGE' if re.search(r'\bconfirm your age\b',source,re.I) else 'SOURCE_SIGN_IN_MESSAGE'
def youtube_diagnostic(folder, phase, gate, reason, error, cause):
    """One private numeric/enum receipt. Never serialize exception text or metadata."""
    try:
        from yt_dlp.utils import DownloadError,ExtractorError,GeoRestrictedError,UnavailableVideoError
        import uuid,stat
        root=pathlib.Path(os.environ.get('MEDIA_ROOT','/media'))
        if phase not in ('analyze','prepare') or folder.parent!=root or root.is_symlink() or folder.is_symlink() or str(uuid.UUID(folder.name))!=folder.name:return
        classes={DownloadError:'DownloadError',ExtractorError:'ExtractorError',GeoRestrictedError:'GeoRestrictedError',UnavailableVideoError:'UnavailableVideoError',Rejected:'Rejected',AudioError:'AudioError'}
        if type(cause) is GeoRestrictedError and reason=='UNKNOWN':reason='GEO_RESTRICTED'
        row=dict(version=1,phase=phase,gate=gate,reason=reason,exceptionClass=classes.get(type(error),'UNKNOWN'),causeClass=classes.get(type(cause),'UNKNOWN'))
        data=json.dumps(row,separators=(',',':'),allow_nan=False).encode()
        if len(data)>1024:return
        dfd=os.open(folder,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            fd=os.open('youtube-diagnostic.json',os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=dfd)
            with os.fdopen(fd,'wb') as stream:stream.write(data)
        finally:os.close(dfd)
    except Exception:pass # Failure cannot alter original error packet, exit, or cleanup.
phase,url,folder=sys.argv[1:4]
folder=pathlib.Path(folder);folder.mkdir(parents=True,exist_ok=True)
max_input=int(os.environ.get('ADAPTER_MAX_INPUT','262144000'))
max_output=int(os.environ.get('ADAPTER_MAX_OUTPUT','209715200'))
duration_limit=int(os.environ.get('ADAPTER_MAX_DURATION','600'))
audio_requested=phase=='prepare' and len(sys.argv)>4 and AUDIO_ID.fullmatch(sys.argv[4])
if audio_requested:max_input=min(max_input,AUDIO_INPUT);max_output=min(max_output,AUDIO_OUTPUT)
phase_deadline=time.monotonic()+int(os.environ.get('ADAPTER_ANALYZE_TIMEOUT','30') if phase=='analyze' else os.environ.get('ADAPTER_PREPARE_TIMEOUT','180'))
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
if phase=='prepare':opts['format']='best' if audio_requested else sys.argv[4]
diagnostic_gate='EXTRACTOR';diagnostic_reason='UNKNOWN'
def valid(info):
    global diagnostic_gate,diagnostic_reason
    diagnostic_gate='METADATA';diagnostic_reason='UNKNOWN'
    if info.get('_type') in ('playlist','multi_video') or info.get('is_live') or info.get('live_status') in ('is_live','is_upcoming'):raise Rejected('UNSUPPORTED_CONTENT')
    if info.get('availability') in ('private','premium_only','subscriber_only','needs_auth'):
        diagnostic_gate='METADATA_AUTH';diagnostic_reason={'private':'PRIVATE','premium_only':'PREMIUM_ONLY','subscriber_only':'SUBSCRIBER_ONLY','needs_auth':'NEEDS_AUTH'}[info['availability']]
        raise Rejected('AUTH_REQUIRED')
    if not isinstance(info.get('duration'),(int,float)) or not math.isfinite(info['duration']) or info['duration']>duration_limit:raise Rejected('LIMIT_EXCEEDED')
    if info.get('age_limit',0)>0:
        diagnostic_gate='METADATA_AGE';diagnostic_reason='AGE_RESTRICTED'
        raise Rejected('AUTH_REQUIRED')
    diagnostic_gate='PROCESSING'
def formats(info):
    fs=info.get('formats',[]);rows=[]
    for f in fs:
        fid=str(f.get('format_id',''))
        if not fid or not all(c.isalnum() or c in '_-' for c in fid):continue
        # Progressive HTTPS MP4; separate HTTPS H.264/AAC streams are merged by copy.
        if f.get('ext')=='mp4' and f.get('protocol')=='https' and f.get('vcodec','none')!='none' and f.get('acodec','none')!='none' and not f.get('has_drm') and full_hd(f.get('width'),f.get('height')):
            size=f.get('filesize');
            if size and size>max_output:continue
            codec=str(f.get('vcodec') or 'Codec chưa xác định').split('.')[0]
            rows.append({'id':fid,'label':str(f['width'])+' × '+str(f['height'])+' px · '+codec+' · có tiếng','size':size,'width':f['width'],'height':f['height'],'kind':'video'})
    audio=[a for a in fs if a.get('ext')=='m4a' and a.get('protocol')=='https' and a.get('vcodec','none')=='none' and str(a.get('acodec','')).startswith('mp4a') and not a.get('has_drm') and all(c.isalnum() or c in '_-' for c in str(a.get('format_id','')))]
    audio=sorted(audio,key=lambda a:a.get('abr') or 0,reverse=True)
    if audio:
        a=audio[0]
        for v in fs:
            if v.get('ext')!='mp4' or v.get('protocol')!='https' or v.get('acodec','none')!='none' or not str(v.get('vcodec','')).startswith(('avc1','h264')) or v.get('has_drm'):continue
            if not full_hd(v.get('width'),v.get('height')):continue
            fid=str(v.get('format_id',''))
            if not fid or not all(c.isalnum() or c in '_-' for c in fid):continue
            size=v.get('filesize')+a.get('filesize') if v.get('filesize') and a.get('filesize') else None
            if size and (size>max_output or size>max_input):continue
            rows.append({'id':fid+'+'+str(a['format_id']),'label':str(v['width'])+' × '+str(v['height'])+' px · H.264 · có tiếng','size':size,'width':v['width'],'height':v['height'],'kind':'video'})
    rank=lambda r:(r['width']*r['height'],min(r['width'],r['height']),max(r['width'],r['height']))
    # yt-dlp's auto-selected format_id is not a source-declared player default.
    for row in rows:row['sourceDefault']=False
    rows=sorted(rows,key=lambda r:(not r['sourceDefault'],tuple(-n for n in rank(r))))[:30]
    best=max((rank(r) for r in rows),default=None)
    for row in rows:row['highest']=rank(row)==best
    return rows
try:
    with BoundedYoutubeDL(opts) as ydl:
        info=ydl.extract_info(url,download=False,process=False) if audio_requested else ydl.extract_info(url,download=False)
        valid(info);rows=formats(info)
        audio_format,audio_source=audio_choice(info.get('formats') or [],'youtube',str(info.get('id') or ''),info['duration'])
        if audio_format:rows.append(audio_format)
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
        elif audio_requested:
            if not audio_format or sys.argv[4]!=audio_format['id']:raise Rejected('FORMAT_UNAVAILABLE')
            source=folder/('audio-source.'+audio_source['ext'])
            auxiliary=[folder/(source.name+suffix) for suffix in ('','.part','.ytdl')]
            if any(os.path.lexists(p) for p in auxiliary):raise Rejected('INVALID_ASSET_PATH')
            try:
                ydl.params['format']=str(audio_source['format_id']);ydl.params['outtmpl']={'default':str(source)}
                ydl.params['max_filesize']=max_input
                fresh=copy.deepcopy(info);fresh['formats']=[copy.deepcopy(audio_source)]
                ydl.process_ie_result(fresh,download=True)
                if time.monotonic()>=phase_deadline:raise Rejected('SOURCE_TIMEOUT')
                result=encode_audio(source,folder,audio_format,network_bytes,phase_deadline,max_output=max_output)
                print(json.dumps(result,ensure_ascii=False))
            finally:
                for p in auxiliary:
                    if p.is_file() and not p.is_symlink():p.unlink()
        else:
            selected=sys.argv[4]
            if selected not in [r['id'] for r in rows]:raise Rejected('FORMAT_UNAVAILABLE')
            ydl.params['format']=selected
            ydl.process_ie_result(info,download=True)
            files=[f for f in folder.glob('media.*') if f.suffix=='.mp4']
            if len(files)!=1 or files[0].stat().st_size>max_output:raise Rejected('LIMIT_EXCEEDED')
            p=subprocess.run(['ffprobe','-v','error','-show_entries','stream=codec_type,width,height:format=duration','-of','json',str(files[0])],capture_output=True,text=True,timeout=10)
            if p.returncode:raise Rejected('FORMAT_UNAVAILABLE')
            probe=json.loads(p.stdout);kinds=[s['codec_type'] for s in probe.get('streams',[])]
            if 'video' not in kinds or 'audio' not in kinds:raise Rejected('FORMAT_UNAVAILABLE')
            chosen=next(r for r in rows if r['id']==selected)
            videos=[s for s in probe.get('streams',[]) if s.get('codec_type')=='video']
            if not videos or any(not full_hd(s.get('width'),s.get('height')) for s in videos):raise Rejected('FORMAT_UNAVAILABLE')
            if not any(s.get('width')==chosen['width'] and s.get('height')==chosen['height'] for s in videos):raise Rejected('FORMAT_UNAVAILABLE')
            try:probed_duration=float(probe['format'].get('duration'))
            except (TypeError,ValueError):raise Rejected('LIMIT_EXCEEDED')
            if not math.isfinite(probed_duration) or probed_duration>duration_limit:raise Rejected('LIMIT_EXCEEDED')
            print(json.dumps({'file':'media.mp4','size':files[0].stat().st_size,'inputBytes':network_bytes}))
except Exception as e:
    cause = youtube_error_cause(e)
    source_reason = youtube_message_reason(cause) if diagnostic_reason == 'UNKNOWN' else diagnostic_reason
    youtube_diagnostic(folder, phase, diagnostic_gate, source_reason, e, cause)
    message=str(e).lower()
    code=str(e) if isinstance(e,(Rejected,AudioError)) and str(e) in ('AUTH_REQUIRED','FORMAT_UNAVAILABLE','SOURCE_TIMEOUT','LIMIT_EXCEEDED','CONTENT_UNAVAILABLE','INVALID_ASSET_PATH') else ('AUTH_REQUIRED' if any(s in message for s in ['sign in','login','log in','private']) else 'FORMAT_UNAVAILABLE' if 'requested format is not available' in message else 'SOURCE_TIMEOUT' if 'timed out' in message else 'LIMIT_EXCEEDED' if 'filesize' in message else 'CONTENT_UNAVAILABLE')
    if source_reason == 'SOURCE_BOT_VERIFICATION_MESSAGE':
        code = 'YOUTUBE_BOT_VERIFICATION_REQUIRED'
    # Do not print extractor exception: it can contain a signed URL or headers.
    print(json.dumps({'error':code}));sys.exit(1)
