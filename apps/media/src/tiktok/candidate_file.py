# AGPL-3.0 lab file contract; FFprobe/FFmpeg5.1.9 perform actual media inspection.
import json,math,pathlib,subprocess
from video_policy import full_hd
from .prepare_operations import Operations
DECODE_RESERVE_SECONDS=10
MP4_BRANDS={'isom','iso2','iso3','iso4','iso5','iso6','iso7','iso8','iso9','mp41','mp42','avc1','dash'}
def video_codec(value):
    # yt-dlp names HEVC h265; FFprobe names the same bitstream hevc.
    return {'h264':'h264','avc1':'h264','h265':'hevc','hevc':'hevc','hvc1':'hevc','hev1':'hevc'}.get(value)
def audio_codec(value):
    return 'aac' if value in ('mp4a','mp4a.40.2') else value
def duration_tolerance(expected):
    # 5% bounded0.15..0.75s: frame/AAC/mux granularity, not multi-second truncation.
    # Short clips get a narrow bound; uncertain metadata can safely fail rather than enlarge tolerance.
    return min(.75,max(.15,.05*expected))
def inspect_file(file,expected_duration,operations=None,max_duration=600,*,expected_vcodec='h264',expected_acodec=None):
    operations=operations or Operations(sink='file-operations.jsonl')
    file=pathlib.Path(file)
    if not isinstance(max_duration,(int,float)) or not math.isfinite(max_duration) or not 0<max_duration<=600:
        raise RuntimeError('DURATION_POLICY')
    if not isinstance(expected_duration,(int,float)) or not math.isfinite(expected_duration) or not 0<expected_duration<=max_duration:
        raise RuntimeError('METADATA_DURATION_POLICY')
    probe=operations.native('FFPROBE',['ffprobe','-v','error','-show_entries',
        'stream=codec_type,codec_name,codec_tag_string,width,height,duration:format=format_name,duration,size:format_tags=major_brand,compatible_brands',
        '-of','json',str(file)],10,capture=True)
    if probe.returncode:raise RuntimeError('FFPROBE_FAIL')
    with operations.step('CONTRACT',operations.timeout(10)):
        data=json.loads(probe.stdout);validate_contract(data,expected_duration,max_duration,
            expected_vcodec=expected_vcodec,expected_acodec=expected_acodec)
    fmt=data.get('format',{});streams=data.get('streams',[])
    duration=float(fmt['duration']);tolerance=duration_tolerance(expected_duration)
    video_durations=[float(s['duration']) for s in streams if s.get('codec_type')=='video' and s.get('codec_name')==video_codec(expected_vcodec)]
    operations.native('DECODE',['ffmpeg','-v','error','-i',str(file),'-f','null','-'],180,reserve=DECODE_RESERVE_SECONDS)
    return {'ffprobe':data,'container':'MP4_ISO_BMFF','decode':'PASS','expectedDuration':expected_duration,
            'containerDuration':duration,'videoDurations':video_durations,'maxDurationSeconds':max_duration,'durationToleranceSeconds':tolerance,
            'durationPolicy':'min(0.75,max(0.15,0.05*expected)); seconds, absolute cap, no rounded delta'}

def validate_contract(data,expected_duration,max_duration=600,*,expected_vcodec='h264',expected_acodec=None):
    fmt=data.get('format',{});streams=data.get('streams',[])
    names=set(fmt.get('format_name','').split(','));brand=fmt.get('tags',{}).get('major_brand','').strip().lower()
    # MOV/MP4 share demuxer names. A QuickTime qt brand is not accepted as an MP4 video.
    if 'mp4' not in names or brand not in MP4_BRANDS:raise RuntimeError('MP4_CONTAINER_REQUIRED')
    codec=video_codec(expected_vcodec)
    if codec is None:raise RuntimeError('VIDEO_CODEC_POLICY')
    video=[s for s in streams if s.get('codec_type')=='video' and s.get('codec_name')==codec]
    audio=[s for s in streams if s.get('codec_type')=='audio' and s.get('codec_name')]
    if not video or not audio:raise RuntimeError('H264_AUDIO_REQUIRED' if codec=='h264' else 'HEVC_AUDIO_REQUIRED')
    if any(not full_hd(s.get('width'),s.get('height')) for s in video):raise RuntimeError('VIDEO_DIMENSION_POLICY')
    # Application prepare binds the real audio to the selected fresh descriptor.
    # Legacy callers without an expected audio codec retain their H264 contract.
    if expected_acodec is not None:
        audio=[s for s in audio if s.get('codec_name')==audio_codec(expected_acodec)]
        if not audio:raise RuntimeError('AUDIO_CODEC_MISMATCH')
    duration=float(fmt.get('duration','nan'))
    if not isinstance(max_duration,(int,float)) or not math.isfinite(max_duration) or not 0<max_duration<=600:
        raise RuntimeError('DURATION_POLICY')
    if not math.isfinite(duration) or not 0<duration<=max_duration:raise RuntimeError('DURATION_POLICY')
    tolerance=duration_tolerance(expected_duration)
    video_durations=[float(s.get('duration','nan')) for s in video]
    # The admin ceiling is independent of metadata/mux tolerance and may never be enlarged by it.
    if any(not math.isfinite(d) or not 0<d<=max_duration for d in video_durations):raise RuntimeError('DURATION_POLICY')
    if abs(duration-expected_duration)>tolerance or any(abs(d-expected_duration)>tolerance for d in video_durations):
        raise RuntimeError('FILE_METADATA_DURATION_MISMATCH')
    if expected_acodec is not None:
        audio_durations=[float(s.get('duration','nan')) for s in audio]
        if any(not math.isfinite(d) or not 0<d<=max_duration for d in audio_durations):raise RuntimeError('DURATION_POLICY')
        if any(abs(d-expected_duration)>tolerance for d in audio_durations):raise RuntimeError('FILE_METADATA_DURATION_MISMATCH')

def copy_pair(video_file,audio_file,output,expected_duration,video_format,audio_format,operations,max_output,max_duration):
    probes=[]
    for file in (video_file,audio_file):
        probe=operations.native('FFPROBE',['ffprobe','-v','error','-show_entries',
            'stream=codec_type,codec_name,width,height,start_time,duration:format=format_name,duration:format_tags=major_brand',
            '-of','json',str(file)],10,capture=True)
        probes.append(json.loads(probe.stdout))
    with operations.step('CONTRACT',operations.timeout(10)):
        target=[s for s in probes[0].get('streams',[]) if s.get('codec_type')=='video']
        donor=probes[1].get('streams',[])
        validate_contract(probes[1],expected_duration,max_duration,expected_vcodec=audio_format['vcodec'],expected_acodec=audio_format['acodec'])
        donor_video=[s for s in donor if s.get('codec_type')=='video']
        donor_audio=[s for s in donor if s.get('codec_type')=='audio']
        if len(donor_video)!=1 or len(donor_audio)!=1:raise RuntimeError('VIDEO_CODEC_POLICY')
        if any(donor_video[0].get(k)!=audio_format[k] for k in ('width','height')):raise RuntimeError('VIDEO_DIMENSION_POLICY')
        if len(target)!=1 or target[0].get('codec_name')!='hevc':raise RuntimeError('VIDEO_CODEC_POLICY')
        if any(target[0].get(k)!=video_format[k] for k in ('width','height')):raise RuntimeError('VIDEO_DIMENSION_POLICY')
        fmt=probes[0].get('format',{})
        if 'mp4' not in fmt.get('format_name','').split(',') or fmt.get('tags',{}).get('major_brand','').strip().lower() not in MP4_BRANDS:raise RuntimeError('MP4_CONTAINER_REQUIRED')
        for stream in target+[s for s in donor if s.get('codec_type') in ('audio','video')]:
            start=float(stream.get('start_time','nan'));duration=float(stream.get('duration','nan'))
            # Refuse offset/edited timelines; copy does not silently retime or trim.
            if not math.isfinite(start) or abs(start)>.1:raise RuntimeError('TIMELINE_MISMATCH')
            if not math.isfinite(duration) or not 0<duration<=max_duration or abs(duration-expected_duration)>duration_tolerance(expected_duration):raise RuntimeError('TIMELINE_MISMATCH')
    operations.native('MUX',['ffmpeg','-v','error','-nostdin','-n','-protocol_whitelist','file',
        '-i',str(video_file),'-protocol_whitelist','file','-i',str(audio_file),
        '-map','0:v:0','-map','1:a:0','-c','copy','-fs',str(max_output),str(output)],180,reserve=DECODE_RESERVE_SECONDS)
    # -fs may stop without error; equal encoded packet hashes refuse truncation
    # even when lost tail duration would fit the normal mux/frame tolerance.
    for source,stream in ((video_file,'0:v:0'),(audio_file,'0:a:0')):
        hashes=[]
        for file in (source,output):
            p=operations.native('STREAM_HASH',['ffmpeg','-v','error','-nostdin','-protocol_whitelist','file',
                '-i',str(file),'-map',stream,'-c','copy','-f','hash','-hash','sha256','-'],180,capture=True,reserve=DECODE_RESERVE_SECONDS)
            if len(p.stdout)>128 or not p.stdout.startswith(b'SHA256='):raise RuntimeError('STREAM_COPY_MISMATCH')
            hashes.append(p.stdout)
        if hashes[0]!=hashes[1]:raise RuntimeError('STREAM_COPY_MISMATCH')
