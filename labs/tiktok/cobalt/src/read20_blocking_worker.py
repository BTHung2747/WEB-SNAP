# Offline only: ignore library timeout deliberately to exercise independent parent clock.
import json,pathlib,sys,time
from fixture_pipeline_worker import FakeSession,URL,ID,PLAY
from yt_candidate import worker
MODE=sys.argv[1]
class StalledSession(FakeSession):
    def send_fixture(self,prepared,**options):
        if MODE=='metadata' or prepared.url==PLAY:
            pathlib.Path('/out/read20-entered-'+MODE+'.json').write_text(json.dumps({'phase':MODE,'adapterEntered':True}),encoding='utf8')
            time.sleep(3)
        return super().send_fixture(prepared,**options)
sys.exit(worker(URL,ID,session_factory=StalledSession))
