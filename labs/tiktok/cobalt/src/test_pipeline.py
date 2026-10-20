# End-to-end offline candidate integration, no mocked extractor/downloader/parent/file contract.
import hashlib,json,pathlib,subprocess
from yt_candidate_driver import pipeline
OUT=pathlib.Path('/out');input_file=OUT/'fixture-input.mp4'
cmd=['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-f','lavfi','-i','testsrc=size=64x64:rate=25',
     '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','2','-c:v','libx264','-preset','ultrafast',
     '-threads','1','-filter_threads','1','-pix_fmt','yuv420p','-c:a','aac','-b:a','32k','-f','mp4',str(input_file)]
generated=subprocess.run(cmd,capture_output=True,text=True,timeout=10);assert generated.returncode==0
(OUT/'integration-native.json').write_text(json.dumps({'argv':cmd,'actualExit':generated.returncode,'stderr':generated.stderr}),encoding='utf8')
source_sha=hashlib.sha256(input_file.read_bytes()).hexdigest()
result,code=pipeline('fixture','fixture',prepare=True,worker_argv=['python3','/lab/src/fixture_pipeline_worker.py'])
assert code==0 and result['workerActualExit']==0 and result['metadataAccepted'] and result['status']=='FILE_NEEDS_VISUAL_REVIEW',result
meta=result['metadataPacket']['summary'];prepared=result['preparePacket']['result']
assert meta['metadata']=='PASS' and meta['requestCount']==2 and meta['bodyIdAndTypeVerifiedByCobalt']
assert meta['id']=='7692288554839313682', 'Offline full pipeline must validate the assigned sample3 body ID'
assert prepared['file']=='PASS' and prepared['requestCount']==1 and prepared['container']=='MP4_ISO_BMFF' and prepared['decode']=='PASS'
assert prepared['sha256']==source_sha==hashlib.sha256((OUT/'video.mp4').read_bytes()).hexdigest()
assert prepared['bytes']==input_file.stat().st_size and prepared['inputBytes']==input_file.stat().st_size
assert prepared['visualAudioWatermark']=='NOT_REVIEWED'
assert len([r for r in prepared['requests'] if r['phase']=='metadata'])==2
assert len([r for r in prepared['requests'] if r['phase']=='prepare'])==1
assert 'FAKEPATH' not in json.dumps(result) and 'FAKEQUERY' not in json.dumps(result)
result.update(parentActualExit=code,sourceAttempts=0,environment='network-none fake adapter, actual extractor/native challenge/downloader/parent/file contract',
              syntheticInputSHA=source_sha,visualAudioWatermark='NEEDS_VISUAL_REVIEW')
(OUT/'integration-result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print('PASS integrated candidate metadata2GET -> prepare1GET; extractor/downloader/parent/file contract real; worker exit0; synthetic MP4 SHA unchanged; not TikTok')
