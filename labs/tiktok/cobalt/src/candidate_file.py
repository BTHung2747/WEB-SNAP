# AGPL-3.0 lab file contract; FFprobe/FFmpeg5.1.9 perform actual media inspection.
import json,math,pathlib,subprocess
from prepare_operations import Operations
DECODE_RESERVE_SECONDS=10
MP4_BRANDS={'isom','iso2','iso3','iso4','iso5','iso6','iso7','iso8','iso9','mp41','mp42','avc1','dash'}
def duration_tolerance(expected):
    # 5% bounded0.15..0.75s: frame/AAC/mux granularity, not multi-second truncation.
    # Short clips get a narrow bound; uncertain metadata can safely fail rather than enlarge tolerance.
    return min(.75,max(.15,.05*expected))
def inspect_file(file,expected_duration,operations=None):
    operations=operations or Operations(sink='file-operations.jsonl')
    file=pathlib.Path(file)
    if not isinstance(expected_duration,(int,float)) or not math.isfinite(expected_duration) or not 0<expected_duration<=600:
        raise RuntimeError('METADATA_DURATION_POLICY')
    probe=operations.native('FFPROBE',['ffprobe','-v','error','-show_entries',
        'stream=codec_type,codec_name,width,height,duration:format=format_name,duration,size:format_tags=major_brand,compatible_brands',
        '-of','json',str(file)],10,capture=True)
    if probe.returncode:raise RuntimeError('FFPROBE_FAIL')
    with operations.step('CONTRACT',operations.timeout(10)):
        data=json.loads(probe.stdout);validate_contract(data,expected_duration)
    fmt=data.get('format',{});streams=data.get('streams',[])
    duration=float(fmt['duration']);tolerance=duration_tolerance(expected_duration)
    video_durations=[float(s['duration']) for s in streams if s.get('codec_type')=='video' and s.get('codec_name')=='h264']
    operations.native('DECODE',['ffmpeg','-v','error','-i',str(file),'-f','null','-'],180,reserve=DECODE_RESERVE_SECONDS)
    return {'ffprobe':data,'container':'MP4_ISO_BMFF','decode':'PASS','expectedDuration':expected_duration,
            'containerDuration':duration,'videoDurations':video_durations,'durationToleranceSeconds':tolerance,
            'durationPolicy':'min(0.75,max(0.15,0.05*expected)); seconds, absolute cap, no rounded delta'}

def validate_contract(data,expected_duration):
    fmt=data.get('format',{});streams=data.get('streams',[])
    names=set(fmt.get('format_name','').split(','));brand=fmt.get('tags',{}).get('major_brand','').strip().lower()
    # MOV/MP4 share demuxer names. A QuickTime qt brand is not accepted as an MP4 video.
    if 'mp4' not in names or brand not in MP4_BRANDS:raise RuntimeError('MP4_CONTAINER_REQUIRED')
    video=[s for s in streams if s.get('codec_type')=='video' and s.get('codec_name')=='h264']
    audio=[s for s in streams if s.get('codec_type')=='audio' and s.get('codec_name')]
    if not video or not audio:raise RuntimeError('H264_AUDIO_REQUIRED')
    duration=float(fmt.get('duration','nan'))
    if not math.isfinite(duration) or not 0<duration<=600:raise RuntimeError('DURATION_POLICY')
    tolerance=duration_tolerance(expected_duration)
    video_durations=[float(s.get('duration','nan')) for s in video]
    if abs(duration-expected_duration)>tolerance or any(not math.isfinite(d) or not 0<d<=600 or abs(d-expected_duration)>tolerance for d in video_durations):
        raise RuntimeError('FILE_METADATA_DURATION_MISMATCH')
