import hashlib,json,pathlib,sys,ssl,socket,subprocess,inspect
out=pathlib.Path('/out');root=pathlib.Path('/code')
rows=json.loads((out/'expected-source.json').read_text())
for r in rows:assert hashlib.sha256((root/r['path']).read_bytes()).hexdigest()==r['sha256']
cap=dict(python=sys.version,ssl=ssl.OPENSSL_VERSION,sourceCalls=0,sourceFiles=len(rows))
try:
 import aiohappyeyeballs
 cap.update(library=aiohappyeyeballs.__version__,startConnection=str(inspect.signature(aiohappyeyeballs.start_connection)))
except ModuleNotFoundError:cap['library']='NOT_MOUNTED_YET'
(out/'capability.json').write_text(json.dumps(cap,indent=2))
assert sys.version.split()[0]=='3.12.12'
if sys.argv[1]=='unit':
 from unit import suite
 suite()
for r in rows:assert hashlib.sha256((root/r['path']).read_bytes()).hexdigest()==r['sha256']
print('PASS',sys.argv[1],sys.version.split()[0])
