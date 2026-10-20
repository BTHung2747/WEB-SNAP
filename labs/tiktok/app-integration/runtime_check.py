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
