"""LAB glue: bounded allowlisted copies, no transport or exception rendering."""
import json,math,os,pathlib,re
CAP=512*1024
ENUMS=set('metadata prepare GET UNKNOWN HTTP_RESPONSE HTTP_STATUS READ_TIMEOUT CONNECT_TIMEOUT PROXY_ERROR TLS_ERROR DNS_ERROR CONNECTION_ERROR TIMEOUT_UNKNOWN REQUEST_ERROR OS_ERROR NEW_CONNECTION_ERROR PROTOCOL_ERROR RETRY_WRAPPER HTTP_ERROR BEGIN END ERROR OK CONNECTION_SETUP REQUEST_SEND RESPONSE_HEADERS DOWNLOADER OUTPUT_CHECK FFPROBE CONTRACT DECODE HASH SUBPROCESS_TIMEOUT UNKNOWN_ERROR PREPARE_DEADLINE'.split())
KEYS=set('requests inputBytes metadataBytes metadataResponseCap metadataTotalCap finalResponseCap index phase method decodedBytes status effectiveTimeout connectSeconds readCeilingSeconds totalSeconds phaseRemainingSeconds boundaries requestID connectionID reused terminal incomplete boundary event elapsed timeout code classes seconds sendDiagnostic proxyConnect originTLS headerWait operation returncode transport TLSverify impersonationRequested actualImpersonation'.split())
CLASSES=set('requests.ConnectTimeout requests.ReadTimeout requests.ProxyError requests.SSLError requests.ConnectionError requests.Timeout requests.HTTPError requests.RequestException urllib3.ConnectTimeoutError urllib3.ReadTimeoutError urllib3.ProxyError urllib3.SSLError urllib3.NewConnectionError urllib3.NameResolutionError urllib3.MaxRetryError urllib3.ProtocolError urllib3.TimeoutError builtins.TimeoutError builtins.OSError ssl.SSLError ssl.SSLCertVerificationError'.split())
def clean(value,key='',depth=0):
    if depth>10:raise ValueError('COLLECT_DEPTH')
    if value is None or type(value) is bool:return value
    if type(value) in (int,float):
        if not math.isfinite(value) or abs(value)>1024**4:raise ValueError('COLLECT_NUMBER')
        return value
    if type(value) is str:
        if value in ENUMS or value in CLASSES or value in ('Requests.HTTPAdapter','HTTPAdapter.send'):return value
        if key in ('requestID','connectionID') and re.fullmatch('[a-f0-9]{16}',value):return value
        raise ValueError('COLLECT_STRING')
    if type(value) is list:
        if len(value)>128:raise ValueError('COLLECT_ROWS')
        return [clean(v,key,depth+1) for v in value]
    if type(value) is dict:
        return {k:clean(v,k,depth+1) for k,v in value.items() if k in KEYS} # URL never emitted, pathname/query both excluded.
    raise ValueError('COLLECT_TYPE')
def write_once(path,value):
    raw=json.dumps(value,separators=(',',':'),allow_nan=False).encode()
    if len(raw)>CAP:raise ValueError('COLLECT_BYTES')
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'wb') as f:f.write(raw)
def diagnostics(value,phase):
    if type(value) is not dict or type(value.get('requests')) is not list or len(value['requests'])>(2 if phase=='analyze' else 3):raise ValueError('MISSING_DIAGNOSTICS')
    rows=value['requests']
    if not rows:raise ValueError('MISSING_DIAGNOSTICS')
    count=sum(r.get('phase')=='metadata' for r in rows);images=sum(r.get('phase')=='prepare' for r in rows)
    if count>2 or images>(0 if phase=='analyze' else 1):raise ValueError('ATTEMPT_LIMIT')
    safe=clean(value);observed=sum(type(r.get('status')) is int for r in rows)
    complete=all(type(r.get('status')) is int and r.get('sendDiagnostic',{}).get('code')=='HTTP_RESPONSE' and not r.get('boundaries',{}).get('incomplete',True) for r in rows)
    return dict(complete=complete,phase=phase,attempts=len(rows),metadataAttempts=count,imageAttempts=images,
                observedResponses=observed,wireGET='UNKNOWN',attemptIsNotWireGET=True,diagnostics=safe)
def collect_files(folder,request_ids):
    out={}
    for name,limit in [('tiktok-operations.jsonl',32),('tiktok-boundaries.jsonl',128)]:
        p=folder/name
        if not p.exists():continue
        if p.is_symlink() or p.stat().st_size>CAP:raise ValueError('COLLECT_FILE')
        rows=[json.loads(line) for line in p.read_text().splitlines()]
        if len(rows)>limit:raise ValueError('COLLECT_ROWS')
        if name.startswith('tiktok-boundaries'):
            # The file appends across two CLI children. Do not count the analyze rows a second time.
            rows=[r for r in rows if r.get('requestID') in request_ids]
            if {r.get('requestID') for r in rows}!=request_ids:raise ValueError('COLLECT_FILE')
        out['operations' if name.startswith('tiktok-operations') else 'boundaries']=clean(rows)
    return out
