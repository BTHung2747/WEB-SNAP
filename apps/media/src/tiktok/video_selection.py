"""AGPL-3.0: public, secret-free rendition identities; yt-dlp owns extraction."""
import hashlib,json
from video_policy import full_hd
from .candidate_file import video_codec
from .core import allowed_formats

def descriptor(f):
    return dict(id=f['format_id'],vcodec=f['vcodec'],acodec=f['acodec'],width=f['width'],height=f['height'])
def identity(plan):
    return 'tt2_'+hashlib.sha256(json.dumps(plan,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
def selections(info,expected,cap,default_url_sha=None):
    formats=allowed_formats(info,expected,cap,include_video_only=True)
    is_default=lambda f:bool(default_url_sha and hashlib.sha256(f['url'].encode()).hexdigest()==default_url_sha)
    default=next((descriptor(f) for f in formats if is_default(f)),None)
    donors=[f for f in formats if video_codec(f.get('vcodec'))=='h264' and f.get('acodec')=='aac']
    donors.sort(key=lambda f:not is_default(f))
    mapping={};rows=[]
    for f in formats:
        pair=f.get('acodec')=='none'
        donor=donors[0] if pair and donors else None
        if pair and (not donor or donor['url']==f['url']):continue
        size=(f.get('filesize')+donor.get('filesize')) if donor and f.get('filesize') and donor.get('filesize') else f.get('filesize') if not pair else None
        if size and size>cap:continue
        duration=info['duration'];duration=int(duration) if duration==int(duration) else duration
        plan=dict(version='tt-video-v2',contentId=expected,duration=duration,video=descriptor(f),
                  audioSource=descriptor(donor) if donor else None,defaultVideo=default)
        fid=identity(plan)
        if fid in mapping:continue # Preserve first qualified CDN mirror, no fallback.
        mapping[fid]=(f,donor)
        codec='HEVC/H.265' if video_codec(f['vcodec'])=='hevc' else 'H.264'
        rows.append(dict(id=fid,label=f"{f['width']} × {f['height']} px · {codec} · có tiếng",
                         size=size,height=f['height'],width=f['width'],kind='video',selection=plan,
                         sourceDefault=descriptor(f)==default,highest=False))
    if not rows:raise RuntimeError('NO_ALLOWED_PLAY_FORMAT')
    rank=lambda r:(r['width']*r['height'],min(r['width'],r['height']),max(r['width'],r['height']))
    rows.sort(key=lambda r:(not r['sourceDefault'],tuple(-n for n in rank(r))))
    rows=rows[:30];best=max(rank(r) for r in rows)
    for row in rows:row['highest']=rank(row)==best
    return rows,mapping
