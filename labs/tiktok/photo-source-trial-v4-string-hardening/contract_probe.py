"""Narrow fixture pipelines/decoded byte caps/deadline, network-none."""
import hashlib,json,os,pathlib,subprocess,sys,time,types
sys.path[:0]=['/app/apps/media/src/tiktok/photo_lab','/app/apps/media/src']
from parent import pipeline
from tiktok.core import Budget,BoundedBody
OUT=pathlib.Path('/out');checks=[];rows=[];LAST=None;PHASE='START'
def main():
    global LAST,PHASE
    fixture=OUT/'fixture.jpg'
    p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc=size=64x64','-frames:v','1','-threads','1','-c:v','mjpeg',str(fixture)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
    assert p.returncode==0
    for mode in ('normal','wrong-type','dimensions','metadata-timeout','image-timeout'):
        PHASE=mode
        folder=OUT/mode;folder.mkdir();control=OUT/'fixture-control'/folder.name;control.mkdir(parents=True)
        (control/'mode.json').write_text(json.dumps(dict(mode=mode if mode not in ('wrong-type','dimensions') else 'normal')))
        env=dict(os.environ,TIKTOK_APP_FIXTURE='1',FIXTURE_MEDIA_FILE=str(fixture),FIXTURE_CONTROL=str(OUT/'fixture-control'),
                 PYTHONPATH='/integration:/app/apps/media/src/tiktok/photo_lab:/app/apps/media/src')
        # Public Popen environment inherited by parent; test only, never source.
        old=dict(os.environ);os.environ.update(env)
        try:
            result,rc=pipeline('https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421','7678209751167110421',prepare=True,
                worker_argv=['python3','/integration/fixture_child.py','analyze','https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421',str(folder),'7678209751167110421',mode],prepare_seconds=60,output_dir=str(folder))
        finally:os.environ.clear();os.environ.update(old)
        LAST=result;assert rc==(0 if mode=='normal' else 20)
        if mode=='normal':assert result['preparePacket']['contract']['fullDecode']=='PASS' and hashlib.sha256((folder/'image.jpg').read_bytes()).hexdigest()==hashlib.sha256(fixture.read_bytes()).hexdigest()
        else:assert not (folder/'image.jpg').exists() and not (folder/'image.jpg.part').exists()
        assert not any(s in json.dumps(result) for s in ('FAKEPATH','FAKESIGNED','fixture_cookie','FIXTURE_SECRET'))
        rows.append(dict(case=mode,parentReturn=rc,workerActualExit=result['workerActualExit'],result=result))
    for mode in ('response','aggregate'):
        b=Budget(deadline=time.monotonic()+30);b.network_total=b.total=0 if mode=='response' else 16*1024*1024
        class Raw:
            def read(self,n,decode_content=True):return b'X'*n
        body=BoundedBody(types.SimpleNamespace(raw=Raw(),close=lambda:None),b,{'decodedBytes':0})
        try:body.read()
        except Exception:assert b.failure=='BYTE_LIMIT'
        else:raise AssertionError('CAP')
        checks.append('DECODED_'+mode.upper()+'_CAP')
    b=Budget(deadline=time.monotonic()-1)
    try:b.check()
    except Exception:checks.append('ABSOLUTE_DEADLINE')
    else:raise AssertionError('DEADLINE')
    (OUT/'contract-result.json').write_text(json.dumps(dict(status='PASS_NARROW_CONTRACT_OFFLINE',actualExit=0,results=rows,checks=checks,ffmpegActualExit=p.returncode,sourceCalls=0,internetDNS=0,realClaims=0),indent=2))
    print('PASS_NARROW_CONTRACT_OFFLINE',flush=True)
if __name__=='__main__':
    try:main()
    except BaseException:
        (OUT/'contract-failure.json').write_text(json.dumps(dict(code='CONTRACT_PROBE_FAIL',actualExit=20,phase=PHASE,last=LAST,completed=rows)))
        print('CONTRACT_PROBE_FAIL',flush=True);sys.exit(20)
