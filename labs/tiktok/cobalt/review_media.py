# Offline review derivatives only; never alter the original source MP4.
import hashlib,json,pathlib,subprocess,time
SOURCE=pathlib.Path('/input/video.mp4');OUT=pathlib.Path('/out')
EXPECTED='14a8ed07de9bdfa201f819cd88d1d2468ee98f011d938f22504512f7616af434'
def sha():return hashlib.sha256(SOURCE.read_bytes()).hexdigest()
assert sha()==EXPECTED
native=[]
def run(args):
    start=time.monotonic();r=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-threads','1','-filter_threads','1',*args],capture_output=True,text=True,timeout=30)
    native.append({'argv':args,'actualExit':r.returncode,'seconds':time.monotonic()-start,'stderr':r.stderr})
    assert r.returncode==0
run(['-i',str(SOURCE),'-vf','fps=1,scale=288:512,tile=4x7','-frames:v','1','-threads','1',str(OUT/'contact.png')])
for seconds in (0,10,20,26.8):
    run(['-ss',str(seconds),'-i',str(SOURCE),'-frames:v','1','-threads','1',str(OUT/('frame-'+str(seconds)+'.png'))])
run(['-i',str(SOURCE),'-vn','-ac','1','-ar','16000','-c:a','pcm_s16le',str(OUT/'audio-review.wav')])
assert sha()==EXPECTED
(OUT/'review-native.json').write_text(json.dumps({'environment':'offline network-none review','originalSHA':EXPECTED,'originalUnchanged':True,'frames':'one-second contact sheet plus full frames at0/10/20/26.8s','native':native},indent=2),encoding='utf8')
