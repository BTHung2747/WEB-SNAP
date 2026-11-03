"""Narrow offline adapter execution with public yt-dlp method double; no HTTP."""
import contextlib,io,json,os,pathlib,runpy,socket,sys,uuid
from unittest.mock import patch
import yt_dlp
from yt_dlp.utils import DownloadError,ExtractorError,GeoRestrictedError
from yt_dlp.version import __version__
assert __version__=='2026.08.19'
SECRET='https://cdn.invalid/secret-path-token?signature=secret-query-cookie'
root=pathlib.Path('/media');out=pathlib.Path('/out');rows=[]
base={'id':'fixture0001','title':'fixture','duration':1,'formats':[{'format_id':'18','ext':'mp4','protocol':'https','vcodec':'h264','acodec':'aac','width':320,'height':240}]}
geo=GeoRestrictedError(SECRET)
cases=[('private',{**base,'availability':'private'},None,'METADATA_AUTH','PRIVATE','AUTH_REQUIRED'),
       ('age',{**base,'age_limit':18},None,'METADATA_AGE','AGE_RESTRICTED','AUTH_REQUIRED'),
       ('extractor',None,DownloadError('Sign in '+SECRET,(ExtractorError,ExtractorError(SECRET,expected=True),None)),'EXTRACTOR','UNKNOWN','AUTH_REQUIRED'),
       ('geo',None,DownloadError('Sign in '+SECRET,(GeoRestrictedError,geo,None)),'EXTRACTOR','GEO_RESTRICTED','AUTH_REQUIRED'),
       ('success',base,None,None,None,None)]
opened=os.open
def invoke(info,error,folder,blocked=False):
    capture=io.StringIO();exitcode=0
    def safeopen(name,*args,**kwargs):
        if blocked and name=='youtube-diagnostic.json':raise PermissionError(SECRET)
        return opened(name,*args,**kwargs)
    with patch.object(sys,'argv',['media_adapter.py','analyze','https://www.youtube.com/watch?v=fixture0001',str(folder)]),patch.dict(os.environ,{'MEDIA_ROOT':'/media'}),patch.object(yt_dlp.YoutubeDL,'extract_info',side_effect=error,return_value=info),patch.object(socket.socket,'connect',side_effect=AssertionError('NETWORK_FORBIDDEN')),patch('os.open',side_effect=safeopen),contextlib.redirect_stdout(capture),contextlib.redirect_stderr(io.StringIO()):
        try:runpy.run_path('/app/infra/media_adapter.py',run_name='__main__')
        except SystemExit as e:exitcode=e.code
    return exitcode,json.loads(capture.getvalue().strip().splitlines()[-1])
for label,info,error,gate,reason,public in cases:
    folder=root/str(uuid.uuid4());folder.mkdir()
    code,packet=invoke(info,error,folder)
    if public:
        assert code==1 and packet=={'error':public}
        receipt=json.loads((folder/'youtube-diagnostic.json').read_text())
        assert receipt['gate']==gate and receipt['reason']==reason
        assert SECRET not in json.dumps(receipt) and len((folder/'youtube-diagnostic.json').read_bytes())<=1024
        # Actual adapter code, identical failure packet/exit even when diagnostic cannot write.
        blocked=root/str(uuid.uuid4());blocked.mkdir();failed=invoke(info,error,blocked,True)
        assert failed==(code,packet) and not (blocked/'youtube-diagnostic.json').exists()
    else:assert code==0 and packet['duration']==1 and not (folder/'youtube-diagnostic.json').exists()
    rows.append(dict(case=label,id=folder.name,actualExit=code,publicError=public))
# Existing preview producer, no grant/no fetch. Parent must mirror this before cleanup.
sys.path.insert(0,'/app/apps/media/src')
from tiktok.preview_cache import generate
preview=root/str(uuid.uuid4());preview.mkdir()
with patch.dict(os.environ,{'WED_PREVIEW_REQUEST':'1'}):
    import time
    assert generate(preview,[('video',SECRET)],time.monotonic()+30,grant=lambda *_:None) is None
receipt=json.loads((preview/'preview-diagnostic.json').read_text());assert receipt['code']=='NO_GRANT' and SECRET not in json.dumps(receipt)
with patch('tiktok.preview_cache.write_diagnostic',side_effect=OSError(SECRET)),patch.dict(os.environ,{'WED_PREVIEW_REQUEST':'1'}):
    assert generate(root/str(uuid.uuid4()),[('video',SECRET)],time.monotonic()+30,grant=lambda *_:None) is None
out.joinpath('python-results.json').write_text(json.dumps(dict(result='PASS_OFFLINE_PUBLIC_METHOD_DOUBLE',cases=rows,previewId=preview.name,networkCalls=0,loggingFailurePreservesPacket=True)))
print('PY_DIAGNOSTICS_PASS adapter-error-exits/privacy/write-failure/success + existing-preview-producer')
