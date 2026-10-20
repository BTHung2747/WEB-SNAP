"""Source policy glue only; no network or resolver implementation."""
import hashlib,math,os,pathlib,sys
TRUST='9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'
def validate(settings):
    raise RuntimeError('SOURCE_DISABLED_NO_AUTHORITY')
    if type(settings) is not dict or set(settings)!={'stage','phaseDeadline'} or settings['stage']!='source':
        raise RuntimeError('SOURCE_CONTROL_POLICY')
    deadline=settings['phaseDeadline']
    if type(deadline) not in (int,float) or not math.isfinite(deadline) or deadline<0:
        raise RuntimeError('SOURCE_CONTROL_POLICY')
    forbidden={'TIKTOK_APP_FIXTURE','SSL_CERT_FILE','SSL_CERT_DIR','REQUESTS_CA_BUNDLE','CURL_CA_BUNDLE',
               'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY','NETRC','COOKIEFILE','COOKIESFROMBROWSER',
               'TIKTOK_COOKIE','TIKTOK_COOKIES','TIKTOK_HEADERS','YTDLP_COOKIES','YTDLP_HEADERS'}
    if any(k.upper() in forbidden or k.upper().startswith(('FIXTURE_','COOKIE_','SOURCE_COOKIE','SOURCE_HEADER','BROWSER_')) for k in os.environ):
        raise RuntimeError('SOURCE_ENV_POLICY')
    fixtures={'owned_fixture','offline_glue','test_photo','fixture','photo_fixture_provider','wiring_photo_fixture','fixture_child'}
    if fixtures.intersection(sys.modules):raise RuntimeError('SOURCE_IMPORT_POLICY')
    site=sys.modules.get('sitecustomize')
    if site is not None:
        origin=getattr(site,'__file__',None)
        # Measured seven-line distro startup module; arbitrary/fixture hooks still fail.
        if origin!='/usr/lib/python3.11/sitecustomize.py' or hashlib.sha256(pathlib.Path(origin).read_bytes()).hexdigest()!='43d81125d92376b1a69d53a71126a041cc9a18d8080e92dea0a2ae23be138b1e' or 'apport_python_hook' in sys.modules:
            raise RuntimeError('SOURCE_IMPORT_POLICY')
    from common import trust_hash
    if trust_hash()!=TRUST:raise RuntimeError('SOURCE_TRUST_POLICY')
    return True
