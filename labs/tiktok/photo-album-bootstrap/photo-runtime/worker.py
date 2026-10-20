"""AGPL-3.0 lab-only image glue; existing yt-dlp/Requests/Budget/Cobalt/FFmpeg own parsing and transport."""
import hashlib,imghdr,json,os,pathlib,subprocess,sys,time,urllib.parse
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import Budget,GuardedYDL,versions
from tiktok.adapter import error_code
from tiktok.prepare_operations import Operations
from yt_dlp.networking import Request

HERE=pathlib.Path(__file__).resolve().parent
def emit(row):print(json.dumps(row),flush=True)
def contract(path,mime,ops):
    if mime.split(';',1)[0].strip().lower()!='image/jpeg' or imghdr.what(path)!='jpeg':raise RuntimeError('JPEG_REQUIRED')
    p=ops.native('FFPROBE',['ffprobe','-v','error','-max_alloc','67108864','-show_entries',
      'stream=codec_name,codec_type,width,height','-of','json',str(path)],10,capture=True)
    streams=json.loads(p.stdout)['streams']
    if len(streams)!=1 or streams[0]['codec_name']!='mjpeg':raise RuntimeError('JPEG_REQUIRED')
    w,h=streams[0]['width'],streams[0]['height']
    if not 0<w<=8192 or not 0<h<=8192 or w*h>16000000:raise RuntimeError('PIXEL_LIMIT')
    count=ops.native('FFPROBE',['ffprobe','-v','error','-max_alloc','67108864','-count_frames',
      '-show_entries','stream=nb_read_frames','-of','json',str(path)],10,capture=True)
    if json.loads(count.stdout)['streams'][0]['nb_read_frames']!='1':raise RuntimeError('STATIC_IMAGE_REQUIRED')
    ops.native('DECODE',['ffmpeg','-v','error','-xerror','-max_alloc','67108864','-threads','1',
      '-err_detect','explode','-i',str(path),'-f','null','-'],30,reserve=5)
    return {'magic':'jpeg','mime':'image/jpeg','width':w,'height':h,'pixels':w*h,'frames':1,'fullDecode':'PASS'}

def worker(url,expected,folder):
    folder=pathlib.Path(folder).resolve();folder.mkdir(exist_ok=True)
    names=[folder/name for name in ('image.jpg','image.jpg.part')]
    if any(p.is_symlink() for p in names):raise RuntimeError('OUTPUT_OWNERSHIP')
    existing={p for p in names if p.exists()}
    b=Budget(input_cap=36*1024*1024,output_cap=16*1024*1024,deadline=time.monotonic()+30)
    ydl=GuardedYDL(b,folder);stage='metadata';status=20;metadata=None
    try:
        versions()
        u=urllib.parse.urlsplit(url)
        if u.scheme!='https' or u.hostname!='www.tiktok.com' or u.query or u.fragment or u.port or u.username or not u.path.endswith('/'+expected):
            raise RuntimeError('INPUT_POLICY')
        target=url.replace('/photo/','/video/')
        ydl.allowed_url=target
        # High-level extractor obtains the webpage and its existing challenge flow.
        # Photo parsing stays with Cobalt, even if yt-dlp reports no video formats.
        try:ydl.extract_info(target,download=False,ie_key='TikTok',process=False)
        except Exception:
            if b.failure or b.latest_body is None:raise
        b.check()
        if b.latest_body is None:raise RuntimeError('PHOTO_METADATA_UNAVAILABLE')
        p=subprocess.run(['node',str(HERE/'picker.mjs'),expected],input=b.latest_body,
              stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=min(2,b.deadline-time.monotonic()))
        b.latest_body=None;b.check()
        if p.returncode or len(p.stdout)>128*1024:raise RuntimeError('PHOTO_METADATA_UNAVAILABLE')
        data=json.loads(p.stdout);images=data['images']
        metadata={'stage':'metadata','status':'PASS','summary':{'id':data['id'],'type':data['type'],
                  'imageCount':len(images),'images':[{k:v for k,v in image.items() if k!='url'} for image in images]},
                  'rows':b.rows.copy(),'metadataBytes':b.total,'target':target}
        emit(metadata)
        command=sys.stdin.readline().strip()
        if command=='stop':return 0
        if command!='prepare':raise RuntimeError('COMMAND_POLICY')
        stage='prepare'
        if existing:raise RuntimeError('PREEXISTING_OUTPUT')
        # One selected image, same fresh anonymous RAM session; never audio/album requests.
        selected=images[0];b.phase_deadline=time.monotonic()+60;b.prepare()
        b.response_cap=20*1024*1024;b.total_cap=20*1024*1024
        ydl.allowed_url=selected['url'];ops=Operations(b.deadline,root=folder)
        with ydl.urlopen(Request(selected['url'])) as response:
            mime=response.headers.get('Content-Type','')
            with names[1].open('xb') as out:
                while True:
                    chunk=response.read(min(16384,16*1024*1024-out.tell()+1))
                    if not chunk:break
                    if out.tell()+len(chunk)>16*1024*1024:b.fail('OUTPUT_LIMIT')
                    out.write(chunk);b.check()
        checked=contract(names[1],mime,ops);b.check()
        for key in ('width','height'):
            if type(selected.get(key)) is int and selected[key]>0 and selected[key]!=checked[key]:raise RuntimeError('DIMENSION_MISMATCH')
        h=hashlib.sha256()
        with names[1].open('rb') as f:
            for chunk in iter(lambda:f.read(65536),b''):h.update(chunk);b.check()
        names[1].rename(names[0])
        emit({'stage':'prepare','status':'PASS','file':'image.jpg','selectedIndex':1,'bytes':names[0].stat().st_size,
              'sha256':h.hexdigest(),'contract':checked,'rows':b.rows,'inputBytes':b.network_total,
              'imageBytes':b.total,'visual':'NEEDS_VISUAL_REVIEW'})
        status=0;return status
    except Exception as e:
        fixed=e.args[0] if type(e) is RuntimeError and e.args and e.args[0] in (
          'JPEG_REQUIRED','PIXEL_LIMIT','STATIC_IMAGE_REQUIRED','DIMENSION_MISMATCH','PREEXISTING_OUTPUT',
          'PHOTO_METADATA_UNAVAILABLE','INPUT_POLICY','COMMAND_POLICY') else error_code(e,b)
        emit({'stage':stage,'status':'FAIL','error':fixed,'rows':b.rows,'decodedBytes':b.network_total})
        return 20
    finally:
        ydl.close()
        if status!=0:
            for p in names:
                if p not in existing and p.is_file() and not p.is_symlink():p.unlink()

if __name__=='__main__':sys.exit(worker(sys.argv[2],sys.argv[4],sys.argv[3]))
