# AGPL-3.0 lab integration. yt-dlp owns TikTok parser/challenge/format normalization.
# Public high-level extraction; Requests/urllib3 own HTTP, TLS, cookies and decompression.
import copy,hashlib,importlib.metadata as md,io,json,math,pathlib,re,subprocess,sys,time,urllib.parse
import requests,urllib3,yt_dlp
from yt_dlp.networking import Request,Response
from yt_dlp.networking.exceptions import RequestError
from .candidate_file import inspect_file
from .send_diagnostics import observed_send,classify
from .prepare_operations import Operations
from .connection_boundaries import BoundaryObserver,ObservedAdapter

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
    def __init__(self,input_cap=PREP_IN,output_cap=PREP_OUT,deadline=None,metadata_seconds=30):
        response_cap=min(META_RESPONSE,input_cap);total_cap=min(META_TOTAL,input_cap)
        if not 0<response_cap<=META_RESPONSE or not 0<total_cap<=META_TOTAL:raise ValueError('CAP_POLICY')
        self.mode='metadata';self.response_cap=response_cap;self.total_cap=total_cap
        self.input_cap=input_cap;self.output_cap=output_cap;self.network_total=0
        self.phase_deadline=deadline if deadline is not None else time.monotonic()+30
        self.max_requests=2;self.requests=0;self.total=0
        self.deadline=min(self.phase_deadline,time.monotonic()+metadata_seconds)
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
        self.mode='prepare';self.response_cap=self.input_cap;self.total_cap=self.input_cap
        self.max_requests=1;self.requests=0;self.total=0;self.deadline=self.phase_deadline;self.failure=None

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
                remaining=min(self.budget.response_cap-self.used,self.budget.total_cap-self.budget.total,self.budget.input_cap-self.budget.network_total)
                n=min(16384,remaining+1,wanted-size if not all_bytes else 16384)
                if n<=0:self.budget.fail('BYTE_LIMIT')
                data=self.response.raw.read(n,decode_content=True)
                self.budget.check()
                if not data:break
                self.used+=len(data);self.budget.total+=len(data);self.budget.network_total+=len(data);self.row['decodedBytes']=self.used
                if self.used>self.budget.response_cap or self.budget.total>self.budget.total_cap or self.budget.network_total>self.budget.input_cap:self.budget.fail('BYTE_LIMIT')
                chunks.append(data);size+=len(data)
            result=b''.join(chunks)
            if all_bytes and self.budget.mode=='metadata':self.budget.latest_body=result
            return result
        except Exception as error:
            # Capture the library timeout before yt-dlp wraps it; keep the original exception and all budgets.
            code,_=classify(error)
            if self.budget.failure is None and code in ('READ_TIMEOUT','CONNECT_TIMEOUT','TIMEOUT_UNKNOWN'):
                self.budget.failure='SOURCE_TIMEOUT'
            self.close();raise
    def close(self):
        if not self.closed:self.response.close()
        super().close()

class GuardedYDL(yt_dlp.YoutubeDL):
    def __init__(self,budget,folder,session_factory=None):
        self.budget=budget;self.allowed_url=None;self.session=None
        opts={'quiet':True,'no_warnings':True,'logger':Silent(),'noplaylist':True,'cachedir':False,
              'cookiefile':None,'cookiesfrombrowser':None,'usenetrc':False,'proxy':PROXY,
              'socket_timeout':10,'retries':0,'fragment_retries':0,'extractor_retries':0,
              'check_formats':False,'remote_components':[],'js_runtimes':{'node':{}},
              'allowed_extractors':['TikTok'],'extractor_args':{'tiktok':{'app_info':[]}},
              'max_filesize':budget.output_cap,'postprocessors':[],'format':'best',
              'outtmpl':{'default':str(folder/'media.%(ext)s')},'overwrites':False,
              'external_downloader':{'default':'native'}}
        super().__init__(opts)
        self.boundary_observer=BoundaryObserver(root=folder)
        self.session=(session_factory or requests.Session)()
        self.session.trust_env=False;self.session.cookies=self.cookiejar
        if session_factory is None:self.session.mount('https://',ObservedAdapter(max_retries=0))
    def urlopen(self,request):
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
            try:
                response=observed_send(self.session.get_adapter(request.url),prepared,row,self.budget.mode,stream=True,timeout=timeout,verify=True,
                    proxies={'http':PROXY,'https':PROXY})
            except Exception as error:
                if classify(error)[0] in ('READ_TIMEOUT','CONNECT_TIMEOUT','TIMEOUT_UNKNOWN'):self.budget.failure='SOURCE_TIMEOUT'
                raise
        self.budget.check();row['status']=response.status_code
        requests.cookies.extract_cookies_to_jar(self.cookiejar,prepared,response.raw)
        if 300<=response.status_code<400:
            response.close();self.budget.fail('REDIRECT_DENIED')
        if response.status_code>=400:
            response.close();self.budget.fail('HTTP_STATUS')
        if self.budget.mode=='prepare' and response.headers.get('content-encoding','identity')=='identity':
            try:length=int(response.headers.get('content-length') or 0)
            except ValueError:length=0
            if length>self.budget.output_cap:response.close();self.budget.fail('OUTPUT_LIMIT')
        wrapped=Response(BoundedBody(response,self.budget,row),request.url,response.headers,status=response.status_code)
        return wrapped
    def close(self):
        try:
            if self.session is not None:self.session.close()
            self.cookiejar.clear()
        finally:super().close()

def allowed_formats(info,expected_id,output_cap):
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
        if f.get('filesize') and f['filesize']>output_cap:continue
        candidates.append(f)
    if not candidates:raise RuntimeError('NO_ALLOWED_PLAY_FORMAT')
    return candidates

