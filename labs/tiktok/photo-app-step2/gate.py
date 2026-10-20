import hashlib,json,pathlib,subprocess,sys,importlib.metadata as md
out=pathlib.Path('/control');root=pathlib.Path('/app')
expected=json.loads((out/'expected-source.json').read_text())
def check():
    for row in expected:assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
check()
if sys.argv[1]!='cli':
    capability=subprocess.run(['node','/fixture/capability.cjs'],timeout=10)
    assert capability.returncode==0
from tiktok.core import versions
(out/'runtime.json').write_text(json.dumps(dict(python=sys.version,packages={n:md.version(n) for n in ['yt-dlp','requests','urllib3','brotli']},
  verified=versions(),ffmpeg=subprocess.check_output(['ffmpeg','-version']).decode().splitlines()[0],
  node=subprocess.check_output(['node','--version']).decode().strip(),sourceFiles=len(expected),sourceCalls=0),indent=2))
if sys.argv[1]=='cli':
    r=subprocess.run(['python3','/fixture/test_cli.py'],timeout=100)
elif sys.argv[1]=='typecheck':
    r=subprocess.run(['bash','-c','node_modules/.bin/prisma generate --schema prisma/schema.prisma > /control/prisma.log 2>&1 && node --max-old-space-size=256 node_modules/typescript/bin/tsc -p tsconfig.json --noEmit'],timeout=90)
else:
    r=subprocess.run(['bash','/fixture/start.sh'],timeout=420)
check()
sys.exit(r.returncode)
