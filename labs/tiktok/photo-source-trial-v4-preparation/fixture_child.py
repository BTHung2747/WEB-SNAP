"""Network-none fixture only. Existing photo fixture owns body and extractor.
Two deterministic fixture-body substitutions exercise type/dimension rejection.
No runtime parser/transport changes; never imported in source entry.
"""
import importlib.util,io,json,os,pathlib,sys
def failed(kind,error,tb):
    code=kind.__name__ if kind.__name__ in ('AttributeError','ImportError','KeyError','AssertionError','FileNotFoundError','RuntimeError') else 'UNKNOWN'
    print(json.dumps(dict(stage='protocol',status='FAIL',error='FIXTURE_CHILD_FAIL',code=code)),flush=True)
sys.excepthook=failed
mode=sys.argv.pop();sys.argv[0]='/app/apps/media/src/tiktok/photo_lab/worker.py'
spec=importlib.util.spec_from_file_location('wiring_photo_fixture','/app/apps/media/src/tiktok/photo_lab/sitecustomize.py')
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
original=fixture.FakeSession.send_fixture
def send(self,prepared,**opts):
    reply=original(self,prepared,**opts)
    if self.pages==2 and prepared.url==fixture.url and mode in ('wrong-type','dimensions'):
        data=reply.raw.read(decode_content=True);reply.close()
        data=data.replace(b'"imagePost":',b'"otherPost":') if mode=='wrong-type' else data.replace(b'"imageWidth": 64',b'"imageWidth": 8193')
        return fixture.Reply(data)
    return reply
fixture.FakeSession.send_fixture=send
import worker as photo_worker
from worker_entry import source_metadata_valid
original_emit=photo_worker.emit
def emit(row):
    # Same public metadata contract used by the wired runtime, before prepare.
    if row.get('stage')=='metadata' and row.get('status')=='PASS' and not source_metadata_valid(row):
        original_emit(dict(stage='metadata',status='FAIL',error='SOURCE_METADATA_CONTRACT'))
        raise RuntimeError('PHOTO_METADATA_UNAVAILABLE')
    return original_emit(row)
photo_worker.emit=emit
from worker import worker
sys.exit(worker(sys.argv[2],sys.argv[4],sys.argv[3]))
