"""AGPL-3.0: bounded redirect glue, Requests/urllib3 own HTTP/cookies/TLS."""
import hashlib,os,re,time,urllib.parse
import requests
from .core import Budget,BoundedBody,PROXY
from .photo_proxy import PhotoProxyAdapter
from .session_owner import SessionOwner
from .send_diagnostics import classify

class ShortError(Exception):pass
def public_error(error):
    from .adapter import error_code
    from .photo_contract import PhotoError
    code=error.args[0] if type(error) is ShortError and error.args else error.code if isinstance(error,PhotoError) else error_code(error)
    return code if code in ('INVALID_URL','UNSUPPORTED_CONTENT','UNSUPPORTED_PLATFORM','AUTH_REQUIRED','FORMAT_UNAVAILABLE',
                            'SOURCE_TIMEOUT','LIMIT_EXCEEDED','CONTENT_UNAVAILABLE','INVALID_ASSET_PATH') else 'CONTENT_UNAVAILABLE'
def route(raw,base=None):
    if type(raw) is not str or len(raw)>2048 or re.search(r'[\x00-\x20\x7f\\]',raw):raise ShortError('INVALID_URL')
    try:
        u=urllib.parse.urlsplit(urllib.parse.urljoin(base,raw) if base else raw)
        if u.scheme!='https' or u.username or u.password or u.port is not None:raise ValueError()
        if u.hostname in ('vt.tiktok.com','vm.tiktok.com'):
            if not re.fullmatch(r'/[A-Za-z0-9_-]{3,64}/?',u.path):raise ValueError()
            return {'url':urllib.parse.urlunsplit(('https',u.hostname,u.path.rstrip('/'),'','')),'kind':'short'}
        if u.hostname not in ('www.tiktok.com','tiktok.com'):raise ValueError()
        if re.fullmatch(r'/t/[A-Za-z0-9_-]{3,64}/?',u.path):return {'url':'https://www.tiktok.com'+u.path.rstrip('/'),'kind':'short'}
        match=re.fullmatch(r'/@([A-Za-z0-9_.-]+)/(video|photo)/([0-9]{15,22})/?',u.path)
        if not match:raise ValueError()
        canonical=f'https://www.tiktok.com/@{match[1]}/{match[2]}/{match[3]}'
        if len(canonical)>2048:raise ValueError()
        return {'url':canonical,'kind':match[2],'id':match[3]}
    except ValueError:raise ShortError('INVALID_URL') from None

def resolve_short(url,deadline,session_factory=None,*,budget=None):
    target=route(url)
    binding='ts1_'+hashlib.sha256(target['url'].encode()).hexdigest()
    if target['kind']!='short' or os.environ.get('WED_MEDIA_PROFILE')!='tiktok-short-analyze' or os.environ.get('WED_MEDIA_SELECTION')!=binding:raise ShortError('UNSUPPORTED_CONTENT')
    budget=Budget(deadline=deadline) if budget is None else budget;seen=set()
    base=(session_factory or requests.Session)();base.trust_env=False
    try:
        if session_factory is None:base.mount('https://',PhotoProxyAdapter(max_retries=0))
        session=SessionOwner(base)
    except BaseException:
        try:base.close()
        finally:base.cookies.clear()
        raise
    try:
        for _ in range(2):
            budget.check();current=target['url']
            if current in seen:raise ShortError('CONTENT_UNAVAILABLE')
            seen.add(current);row=budget.sent()
            request=session.prepare_request(requests.Request('GET',current))
            response=None
            try:
                # Direct public Adapter.send: no Session redirect prefetch/auto-follow.
                response=session.get_adapter(current).send(request,stream=True,verify=True,
                    timeout=budget.http_timeout(row),proxies={'http':PROXY,'https':PROXY})
                budget.check()
                if response.status_code not in (301,302,303,307,308):raise ShortError('CONTENT_UNAVAILABLE')
                values=response.raw.headers.getlist('Location')
                if len(values)!=1:raise ShortError('CONTENT_UNAVAILABLE')
                requests.cookies.extract_cookies_to_jar(base.cookies,request,response.raw)
                target=route(values[0],current)
                # Reach EOF through the existing decoded cap/deadline wrapper before
                # releasing the response. Never cache HTML or drain without bounds.
                body=BoundedBody(response,budget,row)
                try:
                    while body.read(16384):pass
                finally:body.close()
            finally:
                if response is not None:response.close()
            if target['kind']!='short':return target
        raise ShortError('CONTENT_UNAVAILABLE')
    except ShortError:raise
    except Exception as error:
        if budget.failure=='BYTE_LIMIT':raise ShortError('LIMIT_EXCEEDED') from None
        timed_out=budget.failure in ('DEADLINE','SOURCE_TIMEOUT') or classify(error)[0] in ('READ_TIMEOUT','CONNECT_TIMEOUT','TIMEOUT_UNKNOWN')
        raise ShortError('SOURCE_TIMEOUT' if timed_out else 'CONTENT_UNAVAILABLE') from None
    finally:
        try:session.close()
        finally:base.cookies.clear()

def analyze_short(url,folder,session_factory=None):
    from .adapter import bound,execute,error_code
    deadline=time.monotonic()+bound('ADAPTER_ANALYZE_TIMEOUT',30,30)
    budget=Budget(input_cap=bound('ADAPTER_MAX_INPUT',262144000,262144000),deadline=deadline)
    resolved=resolve_short(url,deadline,session_factory,budget=budget)
    if os.environ.get('TIKTOK_ADAPTER_ENABLED')!='1' or 'tiktok' not in os.environ.get('VERIFIED_PLATFORMS','').split(','):raise ShortError('UNSUPPORTED_PLATFORM')
    flag='TIKTOK_PHOTO_ENABLED' if resolved['kind']=='photo' else 'TIKTOK_VIDEO_ENABLED'
    if os.environ.get(flag)!='1':raise ShortError('UNSUPPORTED_PLATFORM')
    if time.monotonic()>=deadline:raise ShortError('SOURCE_TIMEOUT')
    if resolved['kind']=='video':result=execute('analyze',resolved['url'],folder,session_factory=session_factory,analyze_deadline=deadline,analyze_input_used=budget.network_total)
    else:
        from .photo_core import analyze_album,PhotoLimits
        limits=PhotoLimits.from_env()
        limits=PhotoLimits(limits.input_bytes,limits.output_bytes,min(limits.metadata_seconds,deadline-time.monotonic()),limits.prepare_seconds)
        result=analyze_album(resolved['url'],folder,limits=limits,session_factory=session_factory,analyze_deadline=deadline,analyze_input_used=budget.network_total)
    if time.monotonic()>=deadline:raise ShortError('SOURCE_TIMEOUT')
    return {**result,'resolved':resolved}

def main(args):
    import json
    try:
        if len(args)!=3 or args[0]!='analyze':raise ShortError('UNSUPPORTED_CONTENT')
        from .photo_proxy import phase_credentials
        phase_credentials()
        print(json.dumps(analyze_short(args[1],args[2]),ensure_ascii=False));return 0
    except Exception as error:
        print(json.dumps({'error':public_error(error)}));return 1
