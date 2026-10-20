import hashlib,json,pathlib,sys,subprocess
out=pathlib.Path('/control')
expected=json.loads((out/'expected-source.json').read_text())
def verify():
    for r in expected:assert hashlib.sha256((pathlib.Path('/repo')/r['path']).read_bytes()).hexdigest()==r['sha256'],r['path']
verify()
if sys.argv[1]=='broker':
    assert sys.version.split()[0]=='3.12.12'
    from broker_test import suite
    suite()
else:
    p=subprocess.run(['bash','/fixture/start.sh',sys.argv[1]],timeout=350)
    verify();sys.exit(p.returncode)
verify();print('PASS source gate',len(expected),'files')
