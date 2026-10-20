"""ONLY mounted by compose.test.yaml. Synthetic test media is never platform evidence."""
import sys,json,time,subprocess,pathlib
phase,url,folder=sys.argv[1:4];folder=pathlib.Path(folder);folder.mkdir(parents=True,exist_ok=True)
if 'delay000001' in url:
    (folder/'media.mp4.part').write_bytes(b'partial')
    time.sleep(40)
if phase=='analyze':print(json.dumps({'title':'Fixture nội bộ, không phải tải nền tảng','duration':30,'formats':[{'id':'18','label':'Fixture MP4 có tiếng','size':None,'kind':'video'}]}))
else:
    # Real playable video + audio, larger than socket buffers to exercise disconnect/leases.
    p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc2=size=640x360:rate=24','-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','30','-c:v','mpeg4','-q:v','2','-c:a','aac','-threads','1','-y',str(folder/'media.mp4')])
    if p.returncode:sys.exit(1)
    print(json.dumps({'file':'media.mp4','size':(folder/'media.mp4').stat().st_size,'inputBytes':0}))
