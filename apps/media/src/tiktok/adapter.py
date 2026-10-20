# AGPL-3.0 WED SNAP integration: one analyze OR prepare per child, no persisted source secrets.
import copy,hashlib,json,math,os,pathlib,re,subprocess,time,urllib.parse,uuid
from .core import Budget,GuardedYDL,allowed_formats,versions
from .candidate_file import inspect_file
from .prepare_operations import Operations

class Rejected(Exception):pass
def bound(name,default,maximum):
    try:value=int(os.environ.get(name,str(default)))
    except ValueError:raise Rejected('LIMIT_EXCEEDED')
    if not 0<value<=maximum:raise Rejected('LIMIT_EXCEEDED')
    return value
def input_id(url):
    try:u=urllib.parse.urlsplit(url)
    except ValueError:raise Rejected('INVALID_URL')
    if u.scheme!='https' or u.username or u.password or u.port or u.query or u.fragment:raise Rejected('INVALID_URL')
    if u.hostname not in ('tiktok.com','www.tiktok.com'):raise Rejected('UNSUPPORTED_CONTENT')
    m=re.fullmatch(r'/@[\w.-]+/video/(\d{15,22})',u.path)
    if not m:raise Rejected('UNSUPPORTED_CONTENT')
    return 'https://www.tiktok.com'+u.path,m.group(1)
def owned_folder(value):
    root=pathlib.Path(os.environ.get('MEDIA_ROOT','/media'))
    folder=pathlib.Path(value)
    try:
        if root.is_symlink() or folder.is_symlink() or folder.parent!=root or str(uuid.UUID(folder.name))!=folder.name:
            raise Rejected('INVALID_ASSET_PATH')
        folder.mkdir(exist_ok=True)
        if not folder.is_dir() or folder.resolve().parent!=root.resolve():raise Rejected('INVALID_ASSET_PATH')
        for name in ('media.mp4','media.mp4.part','media.mp4.ytdl','tiktok-operations.jsonl','tiktok-boundaries.jsonl'):
            if (folder/name).is_symlink():raise Rejected('INVALID_ASSET_PATH')
    except (OSError,ValueError):raise Rejected('INVALID_ASSET_PATH')
    return folder
def public_id(info,f):
    # Only public, stable metadata; no URL/cookie/signed-query or other secret enters this fingerprint.
    fields=[str(info['id']),f['format_id'],f.get('vcodec'),f.get('acodec'),f.get('width'),f.get('height'),info['duration']]
    digest=hashlib.sha256(json.dumps(fields,separators=(',',':')).encode()).hexdigest()[:32]
    return 'tt1_'+f['format_id']+'_'+digest
def error_code(error,budget=None):
    if isinstance(error,Rejected):return error.args[0]
    if budget and budget.failure:
        return 'SOURCE_TIMEOUT' if budget.failure in ('DEADLINE','SOURCE_TIMEOUT') else 'LIMIT_EXCEEDED' if budget.failure in ('BYTE_LIMIT','OUTPUT_LIMIT') else 'CONTENT_UNAVAILABLE'
    if type(error) is subprocess.TimeoutExpired:return 'SOURCE_TIMEOUT'
    if type(error) is RuntimeError and error.args:
        code=error.args[0]
        if code in ('PREPARE_DEADLINE',):return 'SOURCE_TIMEOUT'
        if code in ('DURATION_POLICY','FILE_LIMIT_OR_MISSING','METADATA_DURATION_POLICY'):return 'LIMIT_EXCEEDED'
        if code in ('NO_ALLOWED_PLAY_FORMAT','MP4_CONTAINER_REQUIRED','H264_AUDIO_REQUIRED','FILE_METADATA_DURATION_MISMATCH','FFPROBE_FAIL','DECODE_FAIL'):return 'FORMAT_UNAVAILABLE'
    return 'CONTENT_UNAVAILABLE'

def execute(phase,url,folder,selected=None,session_factory=None):
    if phase not in ('analyze','prepare'):raise Rejected('UNSUPPORTED_CONTENT')
    url,expected=input_id(url);folder=owned_folder(folder);versions()
    max_input=bound('ADAPTER_MAX_INPUT',262144000,262144000)
    max_output=bound('ADAPTER_MAX_OUTPUT',209715200,209715200)
    max_duration=bound('ADAPTER_MAX_DURATION',600,600)
    analyze_seconds=bound('ADAPTER_ANALYZE_TIMEOUT',30,30)
    total_seconds=analyze_seconds if phase=='analyze' else bound('ADAPTER_PREPARE_TIMEOUT',180,180)
    deadline=time.monotonic()+total_seconds
    budget=Budget(max_input,max_output,deadline,analyze_seconds)
    ydl=GuardedYDL(budget,folder,session_factory)
    names=[folder/name for name in ('media.mp4','media.mp4.part','media.mp4.ytdl')]
    existing={p for p in names if p.exists()}
    try:
        ydl.allowed_url=url
        info=ydl.extract_info(url,download=False,ie_key='TikTok',process=False);budget.check()
        if info.get('_type','video')!='video' or info.get('is_live') or info.get('live_status') in ('is_live','is_upcoming'):
            raise Rejected('UNSUPPORTED_CONTENT')
        if info.get('availability') in ('private','premium_only','subscriber_only','needs_auth') or info.get('age_limit',0)>0:
            raise Rejected('AUTH_REQUIRED')
        duration=info.get('duration')
        if not isinstance(duration,(int,float)) or not math.isfinite(duration) or not 0<duration<=max_duration:
            raise Rejected('LIMIT_EXCEEDED')
        if budget.latest_body is None:raise Rejected('CONTENT_UNAVAILABLE')
        remaining=budget.deadline-time.monotonic()
        if remaining<=0:raise Rejected('SOURCE_TIMEOUT')
        validation=subprocess.run(['node',str(pathlib.Path(__file__).with_name('validate_cobalt_body.mjs')),expected],
            input=budget.latest_body,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=min(2,remaining))
        budget.latest_body=None;budget.check()
        if len(validation.stdout)>4096:raise Rejected('CONTENT_UNAVAILABLE')
        checked=json.loads(validation.stdout)
        if validation.returncode:
            raise Rejected(checked.get('error') if checked.get('error') in ('AUTH_REQUIRED','UNSUPPORTED_CONTENT','CONTENT_UNAVAILABLE') else 'CONTENT_UNAVAILABLE')
        if checked.get('id')!=expected or abs(duration-checked['duration'])>1:raise Rejected('CONTENT_UNAVAILABLE')
        candidates=allowed_formats(info,expected,min(max_output,max_input))
        mapping={public_id(info,f):f for f in candidates}
        if len(mapping)!=len(candidates):raise Rejected('FORMAT_UNAVAILABLE')
        rows=[{'id':fid,'label':str(f.get('height') or '?')+'p · MP4 · có tiếng',
               'size':f.get('filesize'),'height':f.get('height'),'kind':'video'} for fid,f in mapping.items()]
        rows=sorted(rows,key=lambda r:r.get('height') or 0)[:30]
        if phase=='analyze':
            title=re.sub(r'https?://\S+','[url-redacted]',str(info.get('title') or 'Video'))[:300]
            return {'title':title,'duration':duration,'formats':rows}
        # Fresh extraction in this new child, independent of analyze cookie/URL/session.
        if selected not in {r['id'] for r in rows}:raise Rejected('FORMAT_UNAVAILABLE')
        if existing:raise Rejected('INVALID_ASSET_PATH')
        format=mapping[selected];budget.prepare();ydl.allowed_url=format['url']
        operations=Operations(deadline,root=folder)
        def output_guard(_):
            budget.check()
            if sum(p.stat().st_size for p in names if p.is_file())>max_output:budget.fail('OUTPUT_LIMIT')
        ydl.add_progress_hook(output_guard)
        fresh=copy.deepcopy(info);fresh['formats']=[copy.deepcopy(format)]
        with operations.step('DOWNLOADER',operations.timeout(180)):
            ydl.process_ie_result(fresh,download=True);budget.check()
        with operations.step('OUTPUT_CHECK',operations.timeout(180)):
            if not names[0].is_file() or names[0].is_symlink() or names[0].stat().st_size>max_output:
                raise Rejected('LIMIT_EXCEEDED')
        inspected=inspect_file(names[0],duration,operations,max_duration=max_duration);budget.check()
        videos=[s for s in inspected['ffprobe'].get('streams',[]) if s.get('codec_type')=='video' and s.get('codec_name')=='h264']
        if not any(all(not format.get(k) or s.get(k)==format[k] for k in ('width','height')) for s in videos):
            raise Rejected('FORMAT_UNAVAILABLE')
        with operations.step('HASH',operations.timeout(180)):
            h=hashlib.sha256()
            with names[0].open('rb') as f:
                for data in iter(lambda:f.read(1024*1024),b''):h.update(data);budget.check()
        return {'file':'media.mp4','size':names[0].stat().st_size,'inputBytes':budget.network_total}
    except Exception as error:
        for path in names:
            if path not in existing and path.is_file() and not path.is_symlink():path.unlink()
        raise Rejected(error_code(error,budget)) from None
    finally:ydl.close()

def main(args):
    try:
        if os.environ.get('TIKTOK_ADAPTER_ENABLED')!='1':raise Rejected('UNSUPPORTED_PLATFORM')
        if len(args) not in (3,4):raise Rejected('UNSUPPORTED_CONTENT')
        result=execute(*args)
        print(json.dumps(result,ensure_ascii=False));return 0
    except Exception as error:
        print(json.dumps({'error':error_code(error)}));return 1
