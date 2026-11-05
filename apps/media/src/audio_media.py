"""WED SNAP selection/file glue. yt-dlp downloads; FFmpeg encodes/decodes MP3."""
import hashlib,json,math,os,pathlib,re,time,urllib.parse
from tiktok.prepare_operations import Operations

INPUT_CAP=36*1024*1024
OUTPUT_CAP=16*1024*1024
PREFIX=re.compile(r'mp3_[a-f0-9]{64}')
SAFE=re.compile(r'[A-Za-z0-9_.+-]{1,80}')

class AudioError(Exception):pass
def require(ok,code='FORMAT_UNAVAILABLE'):
    if not ok:raise AudioError(code)
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def descriptor(platform,content_id,source_type,duration,source):
    require(platform in ('youtube','tiktok','facebook') and source_type in ('video','photo'))
    require(type(content_id) is str and re.fullmatch(r'[A-Za-z0-9_-]{6,22}',content_id))
    if platform=='facebook':require(source_type=='video' and re.fullmatch(r'[0-9]{6,22}',content_id) and source['origin']=='format')
    require(type(duration) in (int,float) and math.isfinite(duration) and 0<duration<=600)
    duration=round(float(duration),3);duration=int(duration) if duration.is_integer() else duration
    require(set(source)=={'id','ext','acodec','vcodec','width','height','origin'})
    require(all(type(source[k]) is str and SAFE.fullmatch(source[k]) for k in ('id','ext','acodec','vcodec')))
    require(source['ext'] in ('m4a','mp3','aac','mp4','webm') and source['origin'] in ('format','music'))
    require(all(type(source[k]) is int and 0<=source[k]<=8192 for k in ('width','height')))
    selection=dict(version='wed-audio-v1',platform=platform,contentId=content_id,sourceType=source_type,duration=duration,source=source)
    return dict(id='mp3_'+hashlib.sha256(canonical(selection)).hexdigest(),kind='audio',label='MP3 · âm thanh',size=None,selection=selection)

def choice(formats,platform,content_id,duration,*,source_type='video'):
    rows=[]
    for f in formats:
        # TikTok's public extract_info(process=False) leaves protocol unset;
        # the explicit URL scheme below is the transport authority in that case.
        # Facebook DASH entries can be complete HTTPS AAC files: manifest_url
        # records provenance, while protocol=https and no fragments select the
        # native direct downloader. Keep manifest-backed sources off elsewhere.
        direct_facebook=platform=='facebook' and f.get('protocol')=='https' and f.get('ext')=='m4a' and f.get('vcodec')=='none' and str(f.get('acodec','')).startswith('mp4a')
        if platform=='facebook' and not direct_facebook:continue
        if f.get('protocol') not in (None,'https') or f.get('has_drm') or f.get('acodec') in (None,'none') or f.get('fragments') or (f.get('manifest_url') and not direct_facebook):continue
        if any(word in str(f.get('format_id','')).lower() for word in ('download','watermark')):continue
        u=urllib.parse.urlsplit(f.get('url') or '')
        if u.scheme!='https' or not u.hostname or u.username or u.password or u.fragment or u.path.lower().endswith(('.m3u8','.mpd')):continue
        size=f.get('filesize') or f.get('filesize_approx')
        if size and (type(size) not in (int,float) or size>INPUT_CAP):continue
        ext=f.get('ext');video=f.get('vcodec') not in (None,'none')
        if ext not in ('m4a','mp3','aac','mp4','webm'):continue
        if video and not (type(f.get('width')) is int and type(f.get('height')) is int and min(f['width'],f['height'])<=1080 and max(f['width'],f['height'])<=1920):continue
        source=dict(id='facebook-aac' if platform=='facebook' else str(f.get('format_id','')),ext=ext,acodec=str(f['acodec']),vcodec=str(f.get('vcodec') or 'none'),width=f.get('width',0) if video else 0,height=f.get('height',0) if video else 0,origin='format')
        try:public=descriptor(platform,content_id,source_type,duration,source)
        except AudioError:continue
        rows.append((video,-float(f.get('abr') or 0),public,f))
    if not rows:return None,None
    _,_,public,source=sorted(rows,key=lambda r:(r[0],r[1],r[2]['id']))[0]
    return public,source

def music_choice(private):
    music=private.get('audio')
    if type(music) is not dict:return None,None
    try:
        u=urllib.parse.urlsplit(music['url'])
        require(u.scheme=='https' and u.hostname and not u.username and not u.password and not u.fragment and (u.port is None or u.port==443))
        require(any(u.hostname==d or u.hostname.endswith('.'+d) for d in ('tiktok.com','tiktokcdn.com','tiktokv.com','byteoversea.com','ibytedtos.com')))
        public=descriptor('tiktok',private['id'],'photo',music['duration'],dict(id='music_'+music['id'],ext=music['ext'],acodec='unknown',vcodec='none',width=0,height=0,origin='music'))
        return public,music['url']
    except (AudioError,KeyError,TypeError,ValueError):return None,None

def encode(source,folder,selected,input_bytes,deadline,*,max_output=OUTPUT_CAP,check=lambda:None):
    """Local-only conversion with owned inode publication and unchanged PG supervision."""
    require(PREFIX.fullmatch(selected['id']) and 0<max_output<=OUTPUT_CAP)
    require(type(input_bytes) is int and 0<input_bytes<=INPUT_CAP,'LIMIT_EXCEEDED')
    folder=pathlib.Path(folder);source=pathlib.Path(source)
    require(source.parent.resolve()==folder.resolve() and source.is_file() and not source.is_symlink(),'INVALID_ASSET_PATH')
    part=folder/'media.mp3.part';final=folder/'media.mp3';owned={}
    require(not os.path.lexists(part) and not os.path.lexists(final),'INVALID_ASSET_PATH')
    fd=os.open(part,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    st=os.fstat(fd);owned[part]=(st.st_dev,st.st_ino);os.close(fd)
    ops=Operations(deadline,root=folder,sink='audio-operations.jsonl')
    try:
        check();require(deadline-time.monotonic()>10,'SOURCE_TIMEOUT')
        p=ops.native('FFPROBE',['ffprobe','-v','error','-max_alloc','67108864','-protocol_whitelist','file,pipe','-show_entries','stream=codec_type,codec_name:format=duration','-of','json',str(source)],10,True,reserve=10)
        require(len(p.stdout)<=16384);probe=json.loads(p.stdout)
        require(any(s.get('codec_type')=='audio' for s in probe.get('streams',[])))
        expected=selected['selection']['duration'];tolerance=max(1,min(2,expected*.01))
        require(abs(float(probe['format']['duration'])-expected)<=tolerance)
        require(max_output>65536,'LIMIT_EXCEEDED')
        ops.native('ENCODE',['ffmpeg','-nostdin','-v','error','-y','-max_alloc','67108864','-protocol_whitelist','file,pipe','-threads','1','-filter_threads','1','-i',str(source),'-map','0:a:0','-vn','-map_metadata','-1','-c:a','libmp3lame','-b:a','192k','-threads','1','-id3v2_version','3','-fs',str(max_output-65536),'-f','mp3',str(part)],180,reserve=10)
        check();require(0<part.stat().st_size<=max_output,'LIMIT_EXCEEDED')
        p=ops.native('FFPROBE',['ffprobe','-v','error','-max_alloc','67108864','-protocol_whitelist','file,pipe','-show_entries','stream=codec_type,codec_name,channels:format=format_name,duration','-of','json',str(part)],10,True,reserve=5)
        require(len(p.stdout)<=16384);probe=json.loads(p.stdout);streams=probe.get('streams',[])
        require(probe.get('format',{}).get('format_name')=='mp3' and len(streams)==1 and streams[0].get('codec_type')=='audio' and streams[0].get('codec_name')=='mp3' and streams[0].get('channels') in (1,2))
        duration=float(probe['format']['duration']);require(math.isfinite(duration) and 0<duration<=600+tolerance and abs(duration-expected)<=tolerance)
        ops.native('DECODE',['ffmpeg','-nostdin','-v','error','-xerror','-threads','1','-filter_threads','1','-protocol_whitelist','file,pipe','-i',str(part),'-map','0:a:0','-f','null','-'],180,reserve=3)
        digest=hashlib.sha256()
        with part.open('rb') as f:
            for data in iter(lambda:f.read(1024*1024),b''):digest.update(data);check();require(time.monotonic()<deadline,'SOURCE_TIMEOUT')
        os.link(part,final,follow_symlinks=False);owned[final]=owned[part];part.unlink()
        check();require(time.monotonic()<deadline,'SOURCE_TIMEOUT')
        result=dict(file='media.mp3',size=final.stat().st_size,inputBytes=input_bytes,sha256=digest.hexdigest(),selectedFormat=selected['id'],contract=dict(mime='audio/mpeg',container='mp3',audioCodec='mp3',videoStreams=0,channels=streams[0]['channels'],duration=duration,fullDecode='PASS'))
        return result
    except BaseException:
        for path,identity in owned.items():
            try:
                st=path.lstat()
                if (st.st_dev,st.st_ino)==identity and not path.is_symlink():path.unlink()
            except FileNotFoundError:pass
        raise
