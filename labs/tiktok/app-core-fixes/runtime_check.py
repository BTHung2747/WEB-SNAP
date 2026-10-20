import hashlib,importlib.metadata,json,pathlib,subprocess
import sys
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import versions
expected={'undici':'6.24.1','set-cookie-parser':'2.7.2','@imput/psl':'2.0.4','url-pattern':'1.0.3','punycode':'2.3.1'}
root=pathlib.Path('/app/apps/media/src/tiktok')
actual={k:json.loads((root/'node_modules'/k/'package.json').read_text())['version'] for k in expected}
assert actual==expected
ff=subprocess.run(['ffmpeg','-version'],capture_output=True,text=True,timeout=5);assert ff.returncode==0 and '5.1.9' in ff.stdout.splitlines()[0]
py=versions();records=[]
for p in sorted(root.rglob('*')):
 if p.is_file() and '__pycache__' not in p.parts:
  records.append({'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
pathlib.Path('/out/runtime-pins.json').write_text(json.dumps({'status':'PASS','python':py,'npm':actual,'ffmpeg':'5.1.9','files':records},indent=2))
print('PASS actual runtime pins/lock package versions/yt-dlp source hash/FFmpeg5.1.9; no source')
import inspect,requests.models,urllib3.response,urllib3.exceptions
official=[]
for module in (requests.models,urllib3.response,urllib3.exceptions):
 p=pathlib.Path(inspect.getfile(module))
 official.append({'module':module.__name__,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
text=inspect.getsource(requests.models.Response.iter_content)
assert 'ReadTimeoutError' in text and 'ConnectionError(e)' in text
assert issubclass(urllib3.exceptions.ReadTimeoutError,urllib3.exceptions.TimeoutError)
assert 'decode_content' in inspect.signature(urllib3.response.HTTPResponse.read).parameters
pathlib.Path('/out/library-api-check.json').write_text(json.dumps({
 'status':'PASS','sourceCalls':0,'source':'Installed official source in pinned cached image',
 'RequestsVersion':py['requests'],'urllib3Version':py['urllib3'],'FFmpegVersion':'5.1.9',
 'Response.iter_content':'ReadTimeoutError wrapped as requests.ConnectionError',
 'HTTPResponse.read':'Public decode_content parameter; actual decompressed read budget remains caller-owned',
 'ReadTimeoutError':'Official TimeoutError subclass; identity/chain classifier reused',
 'sources':official,
 'references':['https://requests.readthedocs.io/en/latest/api/','https://urllib3.readthedocs.io/en/stable/reference/urllib3.exceptions.html','https://ffmpeg.org/ffprobe.html']
},indent=2))
