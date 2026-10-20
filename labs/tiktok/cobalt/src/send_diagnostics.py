# AGPL-3.0 lab glue: whitelist only; libraries retain ownership of HTTP/errors.
import ssl,time
import requests.exceptions as re
import urllib3.exceptions as ue

# Exact class identities: unknown/custom subclass names and payloads never leave RAM.
CLASSES={
 re.ConnectTimeout:('requests.ConnectTimeout','CONNECT_TIMEOUT'),
 re.ReadTimeout:('requests.ReadTimeout','READ_TIMEOUT'),
 re.ProxyError:('requests.ProxyError','PROXY_ERROR'),
 re.SSLError:('requests.SSLError','TLS_ERROR'),
 re.ConnectionError:('requests.ConnectionError','CONNECTION_ERROR'),
 re.Timeout:('requests.Timeout','TIMEOUT_UNKNOWN'),
 re.HTTPError:('requests.HTTPError','HTTP_ERROR'),
 re.RequestException:('requests.RequestException','REQUEST_ERROR'),
 ue.ConnectTimeoutError:('urllib3.ConnectTimeoutError','CONNECT_TIMEOUT'),
 ue.ReadTimeoutError:('urllib3.ReadTimeoutError','READ_TIMEOUT'),
 ue.ProxyError:('urllib3.ProxyError','PROXY_ERROR'),
 ue.SSLError:('urllib3.SSLError','TLS_ERROR'),
 ue.NewConnectionError:('urllib3.NewConnectionError','NEW_CONNECTION_ERROR'),
 ue.NameResolutionError:('urllib3.NameResolutionError','DNS_ERROR'),
 ue.MaxRetryError:('urllib3.MaxRetryError','RETRY_WRAPPER'),
 ue.ProtocolError:('urllib3.ProtocolError','PROTOCOL_ERROR'),
 ue.TimeoutError:('urllib3.TimeoutError','TIMEOUT_UNKNOWN'),
 TimeoutError:('builtins.TimeoutError','TIMEOUT_UNKNOWN'),
 OSError:('builtins.OSError','OS_ERROR'),
 ssl.SSLError:('ssl.SSLError','TLS_ERROR'),
 ssl.SSLCertVerificationError:('ssl.SSLCertVerificationError','TLS_ERROR'),
}
PRIORITY=('PROXY_ERROR','TLS_ERROR','DNS_ERROR','NEW_CONNECTION_ERROR','CONNECT_TIMEOUT',
          'READ_TIMEOUT','PROTOCOL_ERROR','CONNECTION_ERROR','TIMEOUT_UNKNOWN','HTTP_ERROR',
          'REQUEST_ERROR','OS_ERROR','RETRY_WRAPPER')

def classify(error):
    pending=[error];seen=set();classes=[];codes=[]
    # Exception graph is bounded; inspect only exception-valued links, never strings.
    while pending and len(seen)<12:
        item=pending.pop(0)
        if not isinstance(item,BaseException) or id(item) in seen:continue
        seen.add(id(item));entry=CLASSES.get(type(item))
        if entry and entry[0] not in classes:classes.append(entry[0]);codes.append(entry[1])
        pending.extend(link for link in (item.__cause__,item.__context__) if isinstance(link,BaseException))
        pending.extend(link for link in item.args[:4] if isinstance(link,BaseException))
        if type(item) is ue.MaxRetryError and isinstance(item.reason,BaseException):pending.append(item.reason)
        if type(item) is ue.ProxyError and isinstance(item.original_error,BaseException):pending.append(item.original_error)
    return next((code for code in PRIORITY if code in codes),'UNKNOWN'),classes

def observed_send(adapter,prepared,row,phase,**kwargs):
    start=time.monotonic()
    diagnostic={'boundary':'HTTPAdapter.send','phase':phase if phase in ('metadata','prepare') else 'UNKNOWN',
                'code':'UNKNOWN','classes':[],'status':'UNKNOWN',
                'proxyConnect':'UNKNOWN','originTLS':'UNKNOWN','headerWait':'UNKNOWN'}
    row['sendDiagnostic']=diagnostic
    try:
        response=adapter.send(prepared,**kwargs)
    except Exception as error:
        diagnostic['code'],diagnostic['classes']=classify(error)
        raise # Preserve original exception; do not turn diagnostics into a retry/handler.
    else:
        status=response.status_code
        if type(status) is int and 100<=status<=599:diagnostic['status']=status
        diagnostic['code']='HTTP_RESPONSE' # HTTP errors are actual statuses, not transport guesses.
        return response
    finally:
        diagnostic['seconds']=round(max(0,time.monotonic()-start),6)

def worker_class(error):
    import subprocess
    from yt_dlp.utils import DownloadError,ExtractorError,UnavailableVideoError
    from yt_dlp.networking.exceptions import RequestError
    extra={DownloadError:'DownloadError',ExtractorError:'ExtractorError',UnavailableVideoError:'UnavailableVideoError',
           RequestError:'RequestError',RuntimeError:'RuntimeError',ValueError:'ValueError',AttributeError:'AttributeError',
           subprocess.TimeoutExpired:'subprocess.TimeoutExpired'}
    return extra.get(type(error),CLASSES.get(type(error),('UNKNOWN',))[0])
