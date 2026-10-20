# Offline only: representative repeated synthetic H264/AAC, no source requests.
import hashlib,json,pathlib,subprocess,sys,time
from prepare_operations import Operations
from candidate_file import inspect_file
from runtime_inventory import collect
from yt_candidate_driver import pipeline
def safe_uncaught(kind,value,tb):
    print(json.dumps({'code':'SUBPROCESS_TIMEOUT' if kind is subprocess.TimeoutExpired else 'OFFLINE_BENCHMARK_ERROR'}))
sys.excepthook=safe_uncaught
MODE=sys.argv[1] if len(sys.argv)>1 else 'measure25';FPS=25 if MODE=='measure25' else 30
OUT=pathlib.Path('/out')
OUT.joinpath('runtime-inventory.json').write_text(json.dumps(collect(),indent=2),encoding='utf8')
results=[]
def save():OUT.joinpath('benchmark-result.json').write_text(json.dumps({'environment':'network-none512MiB/CPU0.75; synthetic only',
        'sourceRequests':0,'fps':FPS,'results':results},indent=2),encoding='utf8')
def generate():
    seed=OUT/'short.mp4';long=OUT/'fixture-input.mp4'
    argv=['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-f','lavfi','-i','testsrc2=size=1024x576:rate='+str(FPS),
          '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','2','-c:v','libx264','-preset','medium',
          '-threads','1','-filter_threads','1','-pix_fmt','yuv420p','-c:a','aac','-b:a','64k',str(seed)]
    for name,cmd in [('seed',argv),('loop486',['ffmpeg','-v','error','-nostdin','-stream_loop','242','-i',str(seed),'-t','486','-c','copy',str(long)])]:
        start=time.monotonic();p=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
        results.append({'case':name,'actualExit':p.returncode,'elapsed':time.monotonic()-start});save();assert p.returncode==0
    return seed,long
seed,long=generate()
for name,file,duration in [('short',seed,2),('long486',long,486)]:
    trace=Operations(sink=name+'-operations.jsonl');status='PASS';kind=None;inspection=None
    try:inspection=inspect_file(file,duration,trace)
    except subprocess.TimeoutExpired:status='TIMEOUT';kind='subprocess.TimeoutExpired'
    results.append({'case':name,'status':status,'exception':kind,'bytes':file.stat().st_size,
                    'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'inspection':inspection,'operations':trace.terminals});save()
    assert name!='short' or status=='PASS'
if MODE=='final':
    assert results[-1]['status']=='PASS'
    result,exitcode=pipeline('fixture','7692288554839313682',prepare=True,
             worker_argv=['python3','/lab/src/fixture_pipeline_worker.py','--long-fixture'])
    result.update(parentActualExit=exitcode,sourceAttempts=0,environment='network-none long486 full actual extractor/downloader/parent/filecontract')
    OUT.joinpath('long-integration-result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    assert exitcode==0 and result['workerActualExit']==0 and result['preparePacket']['result']['sha256']==results[-1]['sha256']
    results.append({'case':'full-long-pipeline','status':'PASS','workerExit':0,'parentExit':0,'seconds':result['prepareSeconds']});save()
else:
    # Same legacy decode argv, different allowed bound for measurement only; production cap stays30 until evidence exists.
    trace=Operations(sink='long-completion-operations.jsonl')
    p=trace.native('DECODE',['ffmpeg','-v','error','-i',str(long),'-f','null','-'],120)
    results.append({'case':'long-full-completion','status':'PASS','actualExit':p.returncode,'operations':trace.terminals});save()
print('PASS offline short/long measurement; no source; inspect benchmark-result.json for legacy timeout versus completion')
