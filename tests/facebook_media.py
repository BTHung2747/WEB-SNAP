"""Focused adapter integration, real selection code and stubbed source/file I/O."""
import contextlib, copy, io, json, os, pathlib, runpy, subprocess, sys, tempfile, unittest
from types import SimpleNamespace
from unittest.mock import patch
import yt_dlp

SOURCE=pathlib.Path('/app/infra/media_adapter.py')
BASE=dict(extractor_key='Facebook',id='1441001750812471',duration=8.966,title='Facebook fixture',formats=[
    dict(format_id='2305162356971507a',ext='m4a',protocol='https',url='https://video-syd2-1.xx.fbcdn.net/audio.m4a',vcodec='none',acodec='mp4a.40.5',abr=72.27),
    dict(format_id='2306141996873543v',ext='mp4',protocol='https',vcodec='av01.0.08M',acodec='none',width=1080,height=1920)])

def invoke(metadata, url, selected=None, *, probe=None, real_durations=None):
    with tempfile.TemporaryDirectory() as folder:
        captured=io.StringIO()
        used=[]
        def download(ydl, info, **kwargs):
            used.append(ydl.params['format'])
            if real_durations is None:pathlib.Path(folder,'media.mp4').write_bytes(b'fixture')
            else:
                video_seconds,audio_seconds=real_durations
                subprocess.run(['ffmpeg','-v','error','-nostdin','-f','lavfi','-i',f'color=s=90x160:r=10:d={video_seconds}',
                    '-f','lavfi','-i',f'sine=frequency=440:duration={audio_seconds}','-c:v','libx264','-preset','ultrafast',
                    '-c:a','aac',str(pathlib.Path(folder,'media.mp4'))],check=True,capture_output=True,timeout=10)
        if probe is None:probe=dict(streams=[dict(codec_type='video',width=1080,height=1920,duration='8.966'),dict(codec_type='audio',duration='8.966')],format=dict(duration='8.966'))
        with patch.object(sys,'argv',[str(SOURCE),'prepare' if selected else 'analyze',url,folder]+([selected] if selected else [])), \
             patch.object(yt_dlp.YoutubeDL,'extract_info',return_value=copy.deepcopy(metadata)), \
             patch.object(yt_dlp.YoutubeDL,'process_ie_result',download), \
             (patch('subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=json.dumps(probe))) if real_durations is None else contextlib.nullcontext()), \
             contextlib.redirect_stdout(captured):
            try:runpy.run_path(str(SOURCE),run_name='__main__')
            except SystemExit:pass
        return json.loads(captured.getvalue().splitlines()[-1]),used

def analyze(metadata, url='https://www.facebook.com/share/r/1FXFLYpvcv/'):
    return invoke(metadata,url)[0]

class FacebookMedia(unittest.TestCase):
    def test_av1_aac_native_merge_and_bound_mp3(self):
        data=analyze(BASE)
        self.assertEqual(data['resolved']['url'],'https://www.facebook.com/watch?v=1441001750812471')
        video,audio=data['formats']
        self.assertEqual(video['id'],'fb_mp4_1080x1920_av1')
        self.assertIn('AV1',video['label']);self.assertEqual(video['height'],1920)
        self.assertEqual(audio['selection']['platform'],'facebook')
        self.assertEqual(audio['selection']['contentId'],BASE['id'])
    def test_unknown_sd_hd_do_not_get_invented_resolution(self):
        data=copy.deepcopy(BASE);data['formats']=[dict(format_id='hd',ext='mp4',protocol='https')]
        self.assertEqual(analyze(data)['error'],'FORMAT_UNAVAILABLE')
    def test_direct_facebook_aac_manifest_provenance_is_not_a_fragment_download(self):
        data=copy.deepcopy(BASE);data['formats'][0]['manifest_url']='https://facebook.com/manifest.mpd'
        self.assertTrue(any(f['kind']=='audio' for f in analyze(data)['formats']))
        data['formats'][0]['fragments']=[{'url':'https://video-syd2-1.xx.fbcdn.net/fragment'}]
        self.assertFalse(any(f['kind']=='audio' for f in analyze(data)['formats']))
        data['formats'][0].pop('fragments');data.update(extractor_key='Youtube',id='hXVnFzAd4uc')
        data['formats'][1]['vcodec']='avc1.640028'
        self.assertFalse(any(f['kind']=='audio' for f in analyze(data,'https://youtube.com/watch?v=hXVnFzAd4uc')['formats']))
    def test_same_dimensions_choose_highest_bitrate_native_stream(self):
        data=copy.deepcopy(BASE);data['formats'][1]['tbr']=100
        data['formats'].append(dict(data['formats'][1],format_id='better1080v',tbr=200))
        video=[f for f in analyze(data)['formats'] if f['kind']=='video']
        self.assertEqual(len(video),1)
        result,used=invoke(data,'https://www.facebook.com/watch?v='+BASE['id'],video[0]['id'])
        self.assertEqual(result['file'],'media.mp4');self.assertEqual(used,['better1080v+2305162356971507a'])
    def test_share_choice_resolves_fresh_watch_stream_without_quality_downgrade(self):
        selected=analyze(BASE)['formats'][0]['id'];fresh=copy.deepcopy(BASE)
        fresh['formats'][0]['format_id']='freshAudio';fresh['formats'][1]['format_id']='freshVideo'
        result,used=invoke(fresh,'https://www.facebook.com/watch?v='+BASE['id'],selected)
        self.assertEqual(result['file'],'media.mp4');self.assertEqual(used,['freshVideo+freshAudio'])
        fresh['formats'][1].update(width=720,height=1280)
        result,used=invoke(fresh,'https://www.facebook.com/watch?v='+BASE['id'],selected)
        self.assertEqual(result['error'],'FORMAT_UNAVAILABLE');self.assertEqual(used,[])
    def test_prepare_uses_unprocessed_metadata_and_official_protocol_detection(self):
        fresh=copy.deepcopy(BASE)
        for f in fresh['formats']:
            f.pop('protocol');f.setdefault('url','https://video-syd2-1.xx.fbcdn.net/video.mp4')
        result,used=invoke(fresh,'https://www.facebook.com/watch?v='+BASE['id'],'fb_mp4_1080x1920_av1')
        self.assertEqual(result['file'],'media.mp4');self.assertEqual(used,['2306141996873543v+2305162356971507a'])
    def test_facebook_audio_binding_survives_native_id_rotation(self):
        fresh=copy.deepcopy(BASE);fresh['formats'][0]['format_id']='freshAudio'
        old=next(f for f in analyze(BASE)['formats'] if f['kind']=='audio')
        new=next(f for f in analyze(fresh)['formats'] if f['kind']=='audio')
        self.assertEqual(old,new)
    def test_same_codec_choice_survives_progressive_to_split_streams(self):
        for codec,label in [('av01.0.08M','AV1'),('avc1.640028','H.264'),('hvc1.1.6.L120','H.265')]:
            with self.subTest(codec=codec):
                fresh=copy.deepcopy(BASE);fresh['formats'][1]['vcodec']=codec
                initial=copy.deepcopy(fresh);initial['formats'][1]['acodec']='mp4a.40.2'
                selected=next(f for f in analyze(initial)['formats'] if f['kind']=='video')
                result,used=invoke(fresh,'https://www.facebook.com/watch?v='+BASE['id'],selected['id'])
                self.assertEqual(result.get('file'),'media.mp4');self.assertTrue(used)
                self.assertIn(label,selected['label'])
    def test_rejects_truncated_real_mp4_or_audio_tail(self):
        data=copy.deepcopy(BASE);data['duration']=9.0
        data['formats'][1].update(width=90,height=160,vcodec='avc1.42C00A')
        for durations in [(2,2),(9,2)]:
            with self.subTest(durations=durations):
                result,_=invoke(data,'https://www.facebook.com/watch?v='+BASE['id'],'fb_mp4_90x160_h264',real_durations=durations)
                self.assertEqual(result.get('error'),'FORMAT_UNAVAILABLE')
        result,_=invoke(data,'https://www.facebook.com/watch?v='+BASE['id'],'fb_mp4_90x160_h264',real_durations=(9,9))
        self.assertEqual(result.get('file'),'media.mp4')
    def test_rejects_nonpositive_metadata_duration(self):
        for duration in (0,-1,True):
            with self.subTest(duration=duration):
                self.assertEqual(analyze(dict(BASE,duration=duration)).get('error'),'LIMIT_EXCEEDED')
    def test_4k_and_drm_are_excluded(self):
        for extra in (dict(width=2160,height=3840),dict(has_drm=True)):
            data=copy.deepcopy(BASE);data['formats'][1].update(extra)
            self.assertTrue(all(f['kind']=='audio' for f in analyze(data)['formats']))
    def test_extractor_and_canonical_id_must_match(self):
        data=copy.deepcopy(BASE);data['extractor_key']='Generic'
        self.assertEqual(analyze(data)['error'],'FORMAT_UNAVAILABLE')
        self.assertEqual(analyze(BASE,'https://www.facebook.com/watch?v=222222')['error'],'FORMAT_UNAVAILABLE')
    def test_multivideo_live_private_and_overlength(self):
        for extra,code in ((dict(_type='multi_video'),'UNSUPPORTED_CONTENT'),(dict(is_live=True),'UNSUPPORTED_CONTENT'),
            (dict(availability='private'),'AUTH_REQUIRED'),(dict(duration=601),'LIMIT_EXCEEDED')):
            self.assertEqual(analyze(dict(BASE,**extra))['error'],code)
    def test_youtube_h264_selection_is_unchanged(self):
        data=copy.deepcopy(BASE);data.update(extractor_key='Youtube',id='hXVnFzAd4uc')
        data['formats'][1]['vcodec']='avc1.640028'
        out=analyze(data,'https://www.youtube.com/watch?v=hXVnFzAd4uc')
        self.assertNotIn('resolved',out)
        self.assertIn('H.264',out['formats'][0]['label'])
        self.assertEqual(out['formats'][1]['selection']['platform'],'youtube')

if __name__=='__main__':unittest.main()
