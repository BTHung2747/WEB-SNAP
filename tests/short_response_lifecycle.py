"""Pinned-library offline seams; three groups, no sockets or source."""
import contextlib,gzip,hashlib,importlib.util,io,json,os,pathlib,sys,time,unittest
from unittest.mock import patch
import requests,urllib3
from tiktok.core import Budget,BoundedBody,META_RESPONSE,META_TOTAL
from tiktok import shortlink,adapter,photo_core
OUT=pathlib.Path('/out');SHORT='https://vt.tiktok.com/FIXTURE';VIDEO='https://www.tiktok.com/@fixture/video/7702474511697956103'
binding='ts1_'+hashlib.sha256(SHORT.encode()).hexdigest();records=[]
class Raw(urllib3.response.HTTPResponse):
    def __init__(self,data,location,callback=None):
        encoded=gzip.compress(data);self.eof=False;self.callback=callback
        super().__init__(body=io.BytesIO(encoded),headers={'Location':location,'Content-Encoding':'gzip','Content-Length':str(len(encoded))},preload_content=False,status=302)
    def read(self,*a,**kw):
        if self.callback:self.callback()
        data=super().read(*a,**kw)
        if not data:self.eof=True
        return data
class Response(requests.Response):
    def __init__(self,raw):super().__init__();self.raw=raw;self.status_code=302;self.close_eof=[]
    def close(self):self.close_eof.append(self.raw.eof);super().close()
class Session(requests.Session):
    def __init__(self,responses):super().__init__();self.responses=iter(responses);self.closed=False;self.sent=0;self.cookies.set('anonymous','SECRET')
    def get_adapter(self,_):
        owner=self
        class Adapter:
            def send(self,*a,**kw):owner.sent+=1;return next(owner.responses)
        return Adapter()
    def close(self):self.closed=True;super().close()
def run(responses,budget=None,module=shortlink):
    session=Session(responses)
    with patch.dict(os.environ,{'WED_MEDIA_PROFILE':'tiktok-short-analyze','WED_MEDIA_SELECTION':binding}):
        result=module.resolve_short(SHORT,time.monotonic()+10,lambda:session,**({'budget':budget} if budget is not None else {}))
    return result,session
class Lifecycle(unittest.TestCase):
    def test_eof_before_close_and_both_carry_paths(self):
        oldspec=importlib.util.spec_from_file_location('tiktok.before_shortlink','/before/shortlink.py');old=importlib.util.module_from_spec(oldspec);oldspec.loader.exec_module(old)
        old_response=Response(Raw(b'fixture body',VIDEO));run([old_response],module=old)
        self.assertFalse(old_response.close_eof[0])
        response=Response(Raw(b'fixture body',VIDEO));budget=Budget(deadline=time.monotonic()+10)
        result,session=run([response],budget);self.assertTrue(all(response.close_eof));self.assertEqual(budget.total,12);self.assertEqual(budget.network_total,12);self.assertTrue(session.closed);self.assertEqual(len(session.cookies),0)
        for kind in ('video','photo'):
            url=VIDEO.replace('/video/','/'+kind+'/');response=Response(Raw(b'fixture body',url));session=Session([response]);seen={}
            def extract(*a,**kw):seen.update(kw);return {'fixture':True}
            env={'WED_MEDIA_PROFILE':'tiktok-short-analyze','WED_MEDIA_SELECTION':binding,'TIKTOK_ADAPTER_ENABLED':'1','VERIFIED_PLATFORMS':'tiktok','TIKTOK_VIDEO_ENABLED':'1','TIKTOK_PHOTO_ENABLED':'1'}
            with patch.dict(os.environ,env),patch.object(adapter,'execute',side_effect=extract),patch.object(photo_core,'analyze_album',side_effect=extract):shortlink.analyze_short(SHORT,'unused',lambda:session)
            self.assertEqual(seen['analyze_input_used'],12);self.assertLessEqual(seen['analyze_deadline'],time.monotonic()+30)
        canonical=Budget();canonical.carry_metadata_bytes(0);self.assertEqual((canonical.total,canonical.network_total),(0,0))
        records.append({'oldCloseBeforeEOF':True,'newEOFBeforeClose':True,'videoAndPhotoCarry':12,'canonicalDefaultBytes':0})
    def test_response_aggregate_and_carry_validation(self):
        response=Response(Raw(b'x'*(META_RESPONSE+1),VIDEO));session=Session([response]);budget=Budget(deadline=time.monotonic()+10)
        with patch.dict(os.environ,{'WED_MEDIA_PROFILE':'tiktok-short-analyze','WED_MEDIA_SELECTION':binding}),self.assertRaises(shortlink.ShortError) as raised:shortlink.resolve_short(SHORT,budget.deadline,lambda:session,budget=budget)
        self.assertEqual(raised.exception.args,('LIMIT_EXCEEDED',));self.assertTrue(session.closed);self.assertEqual(len(session.cookies),0)
        responses=[Response(Raw(b'x'*META_RESPONSE,'https://vt.tiktok.com/SECOND')),Response(Raw(b'x'*META_RESPONSE,VIDEO))];budget=Budget(deadline=time.monotonic()+10);run(responses,budget)
        self.assertEqual(budget.network_total,META_TOTAL);next_budget=Budget();next_budget.carry_metadata_bytes(budget.network_total)
        body=BoundedBody(Response(Raw(b'x',VIDEO)),next_budget,next_budget.sent())
        with self.assertRaises(Exception):body.read(1)
        self.assertEqual(next_budget.failure,'BYTE_LIMIT');body.close()
        for invalid in (True,-1,1.5,META_TOTAL+1):
            with self.assertRaises(ValueError):Budget().carry_metadata_bytes(invalid)
        used=Budget();used.carry_metadata_bytes(1)
        with self.assertRaises(ValueError):used.carry_metadata_bytes(0)
        records.append({'perResponseCap':META_RESPONSE,'aggregateCap':META_TOTAL,'nextByteRejected':True,'invalidCarryRejected':True})
    def test_deadline_read_error_cleanup_and_cookie_clear(self):
        for mode in ('deadline','read_timeout'):
            now=[100.0]
            def callback():
                if mode=='deadline':now[0]=102
                else:raise requests.exceptions.ReadTimeout('SECRET_URL_TOKEN')
            response=Response(Raw(b'fixture',VIDEO,callback));session=Session([response])
            with patch('time.monotonic',side_effect=lambda:now[0]),patch.dict(os.environ,{'WED_MEDIA_PROFILE':'tiktok-short-analyze','WED_MEDIA_SELECTION':binding}):
                budget=Budget(deadline=101)
                with self.assertRaises(shortlink.ShortError) as raised:shortlink.resolve_short(SHORT,101,lambda:session,budget=budget)
            self.assertEqual(raised.exception.args,('SOURCE_TIMEOUT',));self.assertTrue(session.closed);self.assertEqual(len(session.cookies),0);self.assertTrue(response.close_eof)
        records.append({'deadlineRejected':True,'readTimeoutRejected':True,'sessionClosed':True,'cookiesCleared':True})
if __name__=='__main__':
    result=unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Lifecycle))
    (OUT/'result.json').write_text(json.dumps(dict(status='PASS' if result.wasSuccessful() else 'FAIL',groups=result.testsRun,requests=requests.__version__,urllib3=urllib3.__version__,records=records,sourceRequests=0,sockets=0),indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
