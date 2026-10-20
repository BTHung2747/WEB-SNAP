"""Actual production CLI and Requests transport; private CA only in lab."""
import hashlib,json,os,pathlib,subprocess,sys,uuid
OUT=pathlib.Path('/control')
if sys.argv[1]=='generate':
    commands=[['openssl','req','-x509','-newkey','rsa:2048','-sha256','-days','1','-nodes','-keyout',str(OUT/'fixture-key.pem'),'-out',str(OUT/'fixture-cert.pem'),'-subj','/CN=www.tiktok.com','-addext','subjectAltName=DNS:www.tiktok.com,DNS:media.tiktokcdn.com,DNS:fixture.tiktok.com'],
      ['ffmpeg','-v','error','-nostdin','-f','lavfi','-i','color=c=blue:s=64x64','-frames:v','1','-threads','1','-filter_threads','1',str(OUT/'input.jpg')]]
    native=[]
    for argv in commands:
        r=subprocess.run(argv,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10);native.append(r.returncode);assert r.returncode==0
    os.chmod(OUT/'fixture-key.pem',0o644)  # Disposable public lab fixture, readable by proxy uid65534 only in this namespace.
    (OUT/'generate.json').write_text(json.dumps(dict(actualExits=native,sourceCalls=0)));sys.exit(0)
