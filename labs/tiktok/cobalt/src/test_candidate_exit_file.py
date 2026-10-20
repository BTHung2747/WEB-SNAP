# Offline targeted findings; fake child lifecycle and small real FFmpeg media only.
import hashlib,json,pathlib,subprocess,time
from yt_candidate_driver import pipeline
from candidate_file import inspect_file,duration_tolerance
OUT=pathlib.Path('/out');MEDIA=OUT/'media-fixtures';MEDIA.mkdir(exist_ok=False)
results=[];native=[]
def run(cmd,timeout=10):
    start=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,timeout=timeout)
    native.append({'argv':cmd,'actualExit':p.returncode,'seconds':time.monotonic()-start,'stdout':p.stdout,'stderr':p.stderr})
    if p.returncode:raise AssertionError('Fixture media command failed')
    return p
for mode in ('metadata','prepare'):
    for behavior in ('exit0','exit20','hang'):
        names=[OUT/'video.mp4',OUT/'video.mp4.part',OUT/'video.mp4.ytdl']
        assert not any(p.exists() for p in names)
        frozen=names[2];frozen.write_bytes(b'FIXTURE_PREEXISTING')
        script='import json,pathlib,sys,time\n'
        script+='pathlib.Path("/out/video.mp4.part").write_bytes(b"FIXTURE_OWNED")\n'
        script+='print(json.dumps({"stage":"metadata","status":"PASS","summary":{"file":"NOT_RUN"}}),flush=True)\n'
        script+='command=sys.stdin.readline()\n'
        if mode=='prepare':
            script+='pathlib.Path("/out/video.mp4").write_bytes(b"FIXTURE_OWNED")\n'
            script+='print(json.dumps({"stage":"prepare","status":"PASS","result":{"file":"PASS"}}),flush=True)\n'
        if behavior=='hang':script+='while True: time.sleep(.01)\n'
        else:script+='sys.exit('+('20' if behavior=='exit20' else '0')+')\n'
        start=time.monotonic()
        result,code=pipeline('fixture','fixture',prepare=mode=='prepare',worker_argv=['python3','-c',script],
            metadata_seconds=.6,prepare_seconds=.6)
        assert frozen.read_bytes()==b'FIXTURE_PREEXISTING'
        if behavior=='exit0':
            assert code==0 and result['workerActualExit']==0 and result['metadataAccepted']
        else:
            assert code!=0 and result['status']=='FAIL' and not result['metadataAccepted']
            assert result['workerActualExit']==(20 if behavior=='exit20' else -9)
            assert not names[0].exists() and not names[1].exists()
        results.append({'finding':'F-CANDIDATE-EXIT','mode':mode,'behavior':behavior,
            'packetStatus':'PASS','parentActualExit':code,'workerActualExit':result['workerActualExit'],
            'workerSignal':result['workerSignal'],'status':result['status'],'error':result.get('error'),
            'seconds':time.monotonic()-start,'newOutputsCleaned':behavior!='exit0','preexistingPreserved':True})
        for path in names:
            if path.is_file():path.unlink() # All are generated solely by this fixture, including frozen sentinel.
        print('PASS F-CANDIDATE-EXIT '+mode+' '+behavior)

run(['ffprobe','-version']);run(['ffmpeg','-version'])
def generate(name,duration,container='mp4'):
    file=MEDIA/name
    run(['ffmpeg','-hide_banner','-loglevel','error','-nostdin',
         '-f','lavfi','-i','testsrc=size=64x64:rate=25','-f','lavfi','-i','sine=frequency=440:sample_rate=44100',
         '-t',str(duration),'-c:v','libx264','-preset','ultrafast','-threads','1','-filter_threads','1',
         '-pix_fmt','yuv420p','-c:a','aac','-b:a','32k','-f',container,str(file)])
    return file
for name,seconds,container,expected,should_pass in [
    ('correct.mp4',2,'mp4',2,True),
    ('near-duration.mp4',2.1,'mp4',2,True),
    ('matroska-named.mp4',2,'matroska',2,False),
    ('quicktime-named.mp4',2,'mov',2,False),
    ('truncated.mp4',.5,'mp4',2,False)]:
    file=generate(name,seconds,container)
    inspected=None;error=None
    try:inspected=inspect_file(file,expected)
    except RuntimeError as e:error=str(e)
    if should_pass:
        assert inspected and inspected['container']=='MP4_ISO_BMFF' and inspected['decode']=='PASS'
        assert abs(inspected['containerDuration']-expected)<=duration_tolerance(expected)
    else:
        assert error==('MP4_CONTAINER_REQUIRED' if container!='mp4' else 'FILE_METADATA_DURATION_MISMATCH')
    # Preserve actual ffprobe raw for rejected files too; filename extension is never accepted as proof.
    probe=run(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name,duration:format=format_name,duration,size:format_tags=major_brand,compatible_brands','-of','json',str(file)])
    results.append({'finding':'F-CANDIDATE-FILE','fixture':name,'expectedDuration':expected,'tolerance':duration_tolerance(expected),
        'accepted':bool(inspected),'error':error,'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
        'ffprobe':json.loads(probe.stdout),'inspection':inspected,'source':'FFmpeg lavfi synthetic, not TikTok','watermark':'NOT_ASSESSED'})
    print('PASS F-CANDIDATE-FILE '+name+' '+('accepted' if inspected else 'rejected'))
assert duration_tolerance(600)==.75 and duration_tolerance(2)==.15
(OUT/'finding-fixtures.json').write_text(json.dumps({'sourceRequests':0,'sourceDownloads':0,'results':results},indent=2),encoding='utf8')
(OUT/'media-native.json').write_text(json.dumps(native,indent=2),encoding='utf8')
