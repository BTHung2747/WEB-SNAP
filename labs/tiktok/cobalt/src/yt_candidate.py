# AGPL-3.0 lab integration. yt-dlp owns TikTok parser/challenge/format normalization.
# Public high-level extraction; Requests/urllib3 own HTTP, TLS, cookies and decompression.
import copy,hashlib,importlib.metadata as md,io,json,math,pathlib,re,subprocess,sys,time,urllib.parse
import requests,urllib3,yt_dlp
from yt_dlp.networking import Request,Response
from yt_dlp.networking.exceptions import RequestError
from candidate_file import inspect_file
from send_diagnostics import observed_send,worker_class
from prepare_operations import Operations
from connection_boundaries import BoundaryObserver,ObservedAdapter

PROXY='http://egress:8888'
META_RESPONSE=8*1024*1024;META_TOTAL=16*1024*1024;PREP_IN=250*1024*1024;PREP_OUT=200*1024*1024
TIKTOK_SHA='3257fdea744811ea2e1bfee665a97d6ab85517339ee672f2e43e238e6b997c9e'

class Silent:
    def debug(self,*a,**k):pass
    def info(self,*a,**k):pass
    def warning(self,*a,**k):pass
    def error(self,*a,**k):pass

def versions():
    expected={'yt-dlp':'2026.8.19','requests':'2.34.2','urllib3':'2.8.0','brotli':'1.2.0'}
    for name,version in expected.items():
        if md.version(name)!=version:raise RuntimeError('VERSION_MISMATCH')
    module=pathlib.Path(md.distribution('yt-dlp').locate_file('yt_dlp/extractor/tiktok.py'))
    if hashlib.sha256(module.read_bytes()).hexdigest()!=TIKTOK_SHA:raise RuntimeError('EXTRACTOR_SOURCE_HASH_MISMATCH')
    return expected

def https(url):
    u=urllib.parse.urlsplit(url)
    if u.scheme!='https' or u.username or u.password or (u.port and u.port!=443):raise RequestError('HTTPS_POLICY')
    return u

class Budget:
    def __init__(self,response_cap=META_RESPONSE,total_cap=META_TOTAL):
        if not 0<response_cap<=META_RESPONSE or not 0<total_cap<=META_TOTAL:raise ValueError('CAP_POLICY')
        self.mode='metadata';self.response_cap=response_cap;self.total_cap=total_cap
        self.max_requests=2;self.requests=0;self.total=0;self.deadline=time.monotonic()+30
        self.failure=None;self.rows=[]
        self.latest_body=None
    def fail(self,code):
        self.failure=code;raise RequestError(code)
    def check(self):
        if time.monotonic()>=self.deadline:self.fail('DEADLINE')
    def http_timeout(self,row):
        remaining=self.deadline-time.monotonic()
        if remaining<=0:self.fail('DEADLINE')
        connect=min(10,remaining);read=min(20,remaining)
        row['effectiveTimeout']={'connectSeconds':connect,'readCeilingSeconds':read,
                                 'totalSeconds':remaining,'phaseRemainingSeconds':remaining}
        return urllib3.util.Timeout(total=remaining,connect=connect,read=read)
    def sent(self):
        self.check()
        if self.requests>=self.max_requests:self.fail('REQUEST_LIMIT')
        self.requests+=1
        row={'index':self.requests,'phase':self.mode,'method':'GET','url':'[url-redacted]','decodedBytes':0}
        self.rows.append(row);return row
    def prepare(self):
        self.mode='prepare';self.response_cap=PREP_IN;self.total_cap=PREP_IN;self.max_requests=1
        self.requests=0;self.total=0;self.deadline=time.monotonic()+180;self.failure=None

class BoundedBody(io.RawIOBase):
    def __init__(self,response,budget,row):
        super().__init__();self.response=response;self.budget=budget;self.row=row;self.used=0
    def readable(self):return True
    def read(self,amount=None):
        all_bytes=amount is None or amount<0
        wanted=amount if not all_bytes else None
        chunks=[];size=0
        try:
            while all_bytes or size<wanted:
                self.budget.check()
                remaining=min(self.budget.response_cap-self.used,self.budget.total_cap-self.budget.total)
                n=min(16384,remaining+1,wanted-size if not all_bytes else 16384)
                if n<=0:self.budget.fail('BYTE_LIMIT')
                data=self.response.raw.read(n,decode_content=True)
                self.budget.check()
                if not data:break
                self.used+=len(data);self.budget.total+=len(data);self.row['decodedBytes']=self.used
                if self.used>self.budget.response_cap or self.budget.total>self.budget.total_cap:self.budget.fail('BYTE_LIMIT')
                chunks.append(data);size+=len(data)
            result=b''.join(chunks)
            if all_bytes and self.budget.mode=='metadata':self.budget.latest_body=result
            return result
        except Exception:
            self.close();raise
    def close(self):
        if not self.closed:self.response.close()
        super().close()

class GuardedYDL(yt_dlp.YoutubeDL):
    def __init__(self,budget,session_factory=None,allow_network=False):
        self.budget=budget;self.allowed_url=None;self.session=None
        self.send_enabled=allow_network or session_factory is not None
        opts={'quiet':True,'no_warnings':True,'logger':Silent(),'noplaylist':True,'cachedir':False,
              'cookiefile':None,'cookiesfrombrowser':None,'usenetrc':False,'proxy':PROXY,
              'socket_timeout':10,'retries':0,'fragment_retries':0,'extractor_retries':0,
              'check_formats':False,'remote_components':[],'js_runtimes':{'node':{}},
              'allowed_extractors':['TikTok'],'extractor_args':{'tiktok':{'app_info':[]}},
              'max_filesize':PREP_OUT,'postprocessors':[],'format':'best',
              'outtmpl':{'default':'/out/video.%(ext)s'},'overwrites':False,
              'external_downloader':{'default':'native'}}
        super().__init__(opts)
        self.boundary_observer=BoundaryObserver()
        self.session=(session_factory or requests.Session)()
        self.session.trust_env=False;self.session.cookies=self.cookiejar
        if session_factory is None:self.session.mount('https://',ObservedAdapter(max_retries=0))
    def urlopen(self,request):
        if not self.send_enabled:self.budget.fail('SOURCE_DISABLED')
        if isinstance(request,str):request=Request(request)
        self.budget.check();u=https(request.url)
        if request.url!=self.allowed_url or request.method!='GET' or request.data is not None:self.budget.fail('REQUEST_POLICY')
        headers=dict(self.params['http_headers']);headers.update(dict(request.headers))
        for k in list(headers):
            if k.lower() in ('authorization','proxy-authorization'):self.budget.fail('CREDENTIAL_HEADER_DENIED')
            if k.lower()=='cookie':
                if headers[k]!=self.cookiejar.get_cookie_header(request.url):self.budget.fail('CREDENTIAL_HEADER_DENIED')
                del headers[k] # Requests prepares domain-scoped cookies from the shared RAM jar.
        row=self.budget.sent()
        row['transport']='Requests.HTTPAdapter';row['TLSverify']=True
        row['impersonationRequested']=bool(request.extensions.get('impersonate'));row['actualImpersonation']=False
        # Session.request(allow_redirects=False) still prepares .next and may consume a redirect body.
        # Public Adapter.send prevents redirects and preloading before our decoded read cap.
        prepared=self.session.prepare_request(requests.Request('GET',request.url,headers=headers))
        timeout=self.budget.http_timeout(row)
        with self.boundary_observer.request(row,self.budget.mode):
            response=observed_send(self.session.get_adapter(request.url),prepared,row,self.budget.mode,stream=True,timeout=timeout,verify=True,
                proxies={'http':PROXY,'https':PROXY})
        self.budget.check();row['status']=response.status_code
        requests.cookies.extract_cookies_to_jar(self.cookiejar,prepared,response.raw)
        if 300<=response.status_code<400:
            response.close();self.budget.fail('REDIRECT_DENIED')
        if response.status_code>=400:
            response.close();self.budget.fail('HTTP_STATUS')
        wrapped=Response(BoundedBody(response,self.budget,row),request.url,response.headers,status=response.status_code)
        return wrapped
    def close(self):
        try:
            if self.session is not None:self.session.close()
            self.cookiejar.clear()
        finally:super().close()

def choose(info,expected_id):
    if not isinstance(info,dict) or str(info.get('id'))!=expected_id or info.get('_type','video')!='video':raise RuntimeError('CONTENT_POLICY')
    duration=info.get('duration')
    if not isinstance(duration,(int,float)) or not math.isfinite(duration) or not 0<duration<=600 or info.get('is_live'):raise RuntimeError('DURATION_POLICY')
    candidates=[]
    for f in info.get('formats') or []:
        fid=f.get('format_id','')
        # Pinned web formatter emits 'play' or a parsed h264 bitrate id for PlayAddr.
        if not (fid=='play' or re.fullmatch(r'h264_\d+p_\d+',fid)):continue
        if f.get('ext')!='mp4' or f.get('vcodec') not in ('h264','avc1') or f.get('acodec') in (None,'none') or f.get('has_drm'):continue
        if 'watermark' in str(f.get('format_note','')).lower():continue
        u=https(f['url'])
        if f.get('protocol') not in (None,'http','https') or f.get('fragments') or f.get('manifest_url') or u.path.lower().endswith(('.m3u8','.mpd')):continue
        if f.get('filesize') and f['filesize']>PREP_OUT:continue
        candidates.append(f)
    if not candidates:raise RuntimeError('NO_ALLOWED_PLAY_FORMAT')
    return max(candidates,key=lambda f:(f.get('format_id')=='play',f.get('height') or 0,f.get('tbr') or 0))

class Candidate:
    def __init__(self,session_factory=None,allow_network=False,budget=None):
        self.versions=versions();self.budget=budget or Budget()
        self.ydl=GuardedYDL(self.budget,session_factory,allow_network);self.info=None;self.selected=None;self.expected_id=None
    def __enter__(self):return self
    def __exit__(self,*args):self.ydl.close()
    def analyze(self,url,expected_id):
        u=https(url)
        if u.hostname!='www.tiktok.com' or not re.fullmatch(r'/@[\w.-]+/video/'+re.escape(expected_id),u.path) or u.query or u.fragment:raise RuntimeError('INPUT_POLICY')
        self.expected_id=expected_id;self.ydl.allowed_url=url
        # All parsing, JS challenge, short-lived cookie creation/clearing and web format normalization stay inside the installed extractor.
        self.info=self.ydl.extract_info(url,download=False,ie_key='TikTok',process=False)
        self.budget.check()
        # Public extractor id is URL-derived. Reuse existing Cobalt parser for independent body id/type,
        # never a new parser or another webpage fetch. Private body goes only through a bounded pipe.
        if self.budget.latest_body is None:raise RuntimeError('FINAL_BODY_REQUIRED')
        validation=subprocess.run(['node','/lab/src/validate_cobalt_body.mjs',expected_id],
            input=self.budget.latest_body,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)
        if validation.returncode or len(validation.stdout)>4096:raise RuntimeError('COBALT_BODY_VALIDATION_FAILED')
        checked=json.loads(validation.stdout)
        if checked.get('status')!='PASS' or checked.get('id')!=expected_id:raise RuntimeError('COBALT_BODY_VALIDATION_FAILED')
        self.selected=choose(self.info,expected_id)
        if abs(self.info['duration']-checked['duration'])>1:raise RuntimeError('DURATION_MISMATCH')
        self.budget.check();self.budget.latest_body=None
        return {'metadata':'PASS','id':expected_id,'duration':self.info['duration'],
                'format':{k:self.selected.get(k) for k in ('format_id','ext','vcodec','acodec','width','height','filesize')},
                'provenance':'yt-dlp-web-play-or-bitrate','bodyIdAndTypeVerifiedByCobalt':True,'file':'NOT_RUN','watermark':'NOT_RUN',
                'requestCount':self.budget.requests,'decodedBytes':self.budget.total,'requests':self.budget.rows}
    def prepare(self,folder):
        if self.selected is None:raise RuntimeError('METADATA_REQUIRED')
        folder=pathlib.Path(folder).resolve()
        if folder!=pathlib.Path('/out'):raise RuntimeError('OWN_OUTPUT_POLICY')
        names=[folder/'video.mp4',folder/'video.mp4.part',folder/'video.mp4.ytdl']
        if any(p.exists() for p in names):raise RuntimeError('OWN_OUTPUT_EXISTS')
        self.budget.prepare();self.ydl.allowed_url=self.selected['url']
        self.prepare_trace=Operations(self.budget.deadline)
        def output_guard(_):
            self.budget.check()
            if sum(p.stat().st_size for p in names if p.is_file())>PREP_OUT:self.budget.fail('OUTPUT_LIMIT')
        # Static options were normalized by the constructor; do not replace outtmpl with a raw string.
        self.ydl.add_progress_hook(output_guard)
        info=copy.deepcopy(self.info);info['formats']=[copy.deepcopy(self.selected)]
        try:
            with self.prepare_trace.step('DOWNLOADER',self.prepare_trace.timeout(180)):
                self.ydl.process_ie_result(info,download=True) # Same instance/RAM cookies, no fallback.
                self.budget.check()
            with self.prepare_trace.step('OUTPUT_CHECK',self.prepare_trace.timeout(180)):
                file=names[0]
                if not file.is_file() or file.stat().st_size>PREP_OUT:raise RuntimeError('FILE_LIMIT_OR_MISSING')
            inspected=inspect_file(file,self.info['duration'],self.prepare_trace)
            with self.prepare_trace.step('HASH',self.prepare_trace.timeout(180)):
                self.budget.check();h=hashlib.sha256()
                with file.open('rb') as fp:
                    for chunk in iter(lambda:fp.read(1024*1024),b''):h.update(chunk);self.budget.check()
            return {'file':'PASS','bytes':file.stat().st_size,'inputBytes':self.budget.total,'requestCount':self.budget.requests,'requests':self.budget.rows,'sha256':h.hexdigest(),**inspected,'operations':self.prepare_trace.terminals,'visualAudioWatermark':'NOT_REVIEWED'}
        except Exception:
            for p in names:
                if p.is_file():p.unlink()
            raise

def worker(url,expected_id,allow_network=False,session_factory=None,fixture_debug=False):
    # Two small public protocol packets. Private formats, cookies and signed URLs never leave this process.
    stage='metadata'
    try:
        with Candidate(allow_network=allow_network,session_factory=session_factory) as candidate:
            summary=candidate.analyze(url,expected_id);print(json.dumps({'stage':stage,'status':'PASS','summary':summary}),flush=True)
            command=sys.stdin.readline(32).strip()
            if command!='prepare':return 0
            stage='prepare';result=candidate.prepare('/out')
            print(json.dumps({'stage':stage,'status':'PASS','result':result}),flush=True);return 0
    except Exception as error:
        guard=locals().get('candidate')
        packet={'stage':stage,'status':'FAIL','error':guard.budget.failure if guard and guard.budget.failure else 'YTDLP_OR_FILE_FAILURE',
                          'exception':worker_class(error),'requests':guard.budget.rows if guard else [],
                          'requestCount':guard.budget.requests if guard else 0,'decodedBytes':guard.budget.total if guard else 0,
                          'file':'NOT_RUN' if stage=='metadata' else 'FAIL'}
        if guard and hasattr(guard,'prepare_trace'):packet['operations']=guard.prepare_trace.terminals
        if fixture_debug and session_factory is not None:
            import traceback
            name=getattr(error,'name',None)
            packet['fixtureDebug']={'attribute':name if isinstance(name,str) and re.fullmatch(r'\w{1,80}',name) else None,
                'frames':[{'file':pathlib.Path(f.filename).name,'line':f.lineno,'function':f.name} for f in traceback.extract_tb(error.__traceback__)]}
        print(json.dumps(packet),flush=True);return 20

if __name__=='__main__':
    if len(sys.argv)<4 or sys.argv[1]!='--worker':raise SystemExit('Offline candidate module; source execution requires an explicitly authorized driver')
    sys.exit(worker(sys.argv[2],sys.argv[3],allow_network='--allow-network' in sys.argv[4:]))
