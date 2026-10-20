"""OFFLINE injection at Requests adapter only; not shipped in runtime."""
import os
import sys
if os.environ.get('PHOTO_STEP2_FIXTURE') == '1' and sys.argv[0].endswith('media_adapter.py') and '/photo/' not in sys.argv[2]:
    import importlib.util
    os.environ.update(TIKTOK_APP_FIXTURE='1',FIXTURE_MEDIA_FILE='/control/input.mp4',FIXTURE_CONTROL='/control')
    spec=importlib.util.spec_from_file_location('legacy_fixture','/legacyfixture/sitecustomize.py')
    legacy=importlib.util.module_from_spec(spec);spec.loader.exec_module(legacy)
if os.environ.get('PHOTO_STEP2_FIXTURE') == '1' and sys.argv[0].endswith('media_adapter.py') and '/photo/' in sys.argv[2]:
    import atexit,json,pathlib,signal,subprocess,time
    import requests
    import fixtures
    phase=sys.argv[1];folder=pathlib.Path(sys.argv[3]);control=pathlib.Path('/control')/folder.name
    control.mkdir(parents=True,exist_ok=True)
    def event(name,**data):
        with (control/'events.jsonl').open('a') as f:f.write(json.dumps(dict(event=name,phase=phase,pid=os.getpid(),pgid=os.getpgrp(),**data))+'\n')
    try:mode=json.loads((control/'mode.json').read_text())['mode']
    except FileNotFoundError:mode='normal'
    event('child_begin',photoFlag=os.environ.get('TIKTOK_PHOTO_ENABLED'),maxInput=os.environ.get('ADAPTER_MAX_INPUT'),maxOutput=os.environ.get('ADAPTER_MAX_OUTPUT'))
    class FixtureAdapter(fixtures.Adapter):
        def send(self,prepared,**options):
            image=prepared.url != fixtures.TARGET
            event('JPEG_GET' if image else 'metadata_GET')
            if image and mode=='hang':
                signal.signal(signal.SIGTERM,signal.SIG_IGN)
                helper=subprocess.Popen(['python3','-c','import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);time.sleep(180)'])
                event('helper_started',helperPid=helper.pid)
                time.sleep(180)
            return super().send(prepared,**options)
    Base=requests.Session
    sessions=[]
    class Session(Base):
        def __init__(self):
            super().__init__();self.mode=mode if phase=='prepare' else ('wrong-body' if mode=='analyze-wrong-body' else 'normal')
            self.jpeg=pathlib.Path('/control/input.jpg');self.folder=folder;self.cancelled=[False]
            self.metadata=self.images=0;self.responses=[];sessions.append(self)
        def get_adapter(self,url):return FixtureAdapter(self)
        def close(self):
            super().close();event('session_close',metadataGET=self.metadata,JPEGGET=self.images,cookies=len(self.cookies))
    requests.Session=Session
    atexit.register(lambda:event('session_final',sessions=len(sessions),cookiesRemaining=sum(len(s.cookies) for s in sessions),responsesClosed=all(r.closed_by_core for s in sessions for r in s.responses)))
    from tiktok import photo_adapter,photo_core
    real_main=photo_adapter.main
    def main(args):
        code=real_main(args);sys.stdout.flush();event('child_result',actualCoreExit=code)
        if code==0 and mode==phase+'-pass-exit20':event('injected_exit20');return 20
        if code==0 and mode==phase+'-pass-hang':
            signal.signal(signal.SIGTERM,signal.SIG_IGN);event('packet_pass_hang');time.sleep(180)
        return code
    photo_adapter.main=main
    if mode in ('packet-path','packet-size','packet-contract','packet-secret','packet-kind'):
        real_prepare=photo_core.prepare_photo
        def prepare(*args,**kwargs):
            p=real_prepare(*args,**kwargs)
            if mode=='packet-path':p['file']='media.mp4'
            if mode=='packet-size':p['size']+=1
            if mode=='packet-contract':p['contract']['fullDecode']='NO'
            if mode=='packet-secret':p['url']='https://FAKE_PATH_TOKEN/?FAKE_QUERY_TOKEN'
            if mode=='packet-kind':p['kind']='video'
            return p
        photo_core.prepare_photo=prepare
