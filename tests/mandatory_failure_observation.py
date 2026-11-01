"""Three focused pure groups; fake sockets, no network/runtime/source."""
import ast,contextlib,errno,importlib.util,io,json,os,pathlib,sys,time,types,unittest
from unittest.mock import patch
sys.dont_write_bytecode=True
ROOT=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'apps/egress/src'))
sys.path.insert(0,str(ROOT/'apps/egress/vendor'))
from tiktok_policy.runtime import Request
from tiktok_policy.control import Broker,VALIDATION_REASON_CODES
spec=importlib.util.spec_from_file_location('observed_egress',ROOT/'apps/egress/src/egress.py')
egress=importlib.util.module_from_spec(spec);spec.loader.exec_module(egress)
OUT=pathlib.Path(sys.argv.pop(1));records=[]
SECRET='https://secret.invalid/PATH_TOKEN?QUERY_TOKEN=1 COOKIE_SECRET'
class Observation(unittest.TestCase):
    def test_handler_boundaries_preserve_failed_verdict_and_close(self):
        for wanted,code in [('SETUP','TIMEOUT'),('HANDOFF','BROKEN_PIPE'),('RELAY_READ','RESET'),('RELAY_WRITE','BROKEN_PIPE')]:
            with self.subTest(stage=wanted):
                class Sock:
                    def __init__(self,client=False):self.client=client;self.closed=False
                    def settimeout(self,_):pass
                    def close(self):self.closed=True
                    def recv(self,_):
                        if wanted=='RELAY_READ':raise ConnectionResetError(errno.ECONNRESET,SECRET)
                        return b'fixture'
                    def sendall(self,data):
                        if self.client and (wanted=='HANDOFF' or wanted=='RELAY_WRITE' and data==b'fixture'):raise BrokenPipeError(errno.EPIPE,SECRET)
                client=Sock(True);upstream=Sock()
                class Policy:
                    observe_failure=Request.observe_failure
                    def __init__(self):self.failed=False;self.tunnel=False;self.finished=False
                    def connect(self,_):
                        if wanted=='SETUP':raise TimeoutError(SECRET)
                        return upstream
                    def before_handoff(self):pass
                    def after_handoff(self):self.tunnel=True
                    def finish(self):self.finished=True
                policy=Policy();h=egress.Handler.__new__(egress.Handler)
                h.connection=h.request=client;h.rfile=io.BytesIO(b'CONNECT www.tiktok.com:443 HTTP/1.1\r\n\r\n')
                h.server=types.SimpleNamespace(register_policy=lambda *_:policy)
                buf=io.StringIO()
                with patch.object(egress,'policy_enabled',return_value=True),patch.object(egress.select,'select',return_value=([upstream],[],[])),contextlib.redirect_stdout(buf):h.handle()
                row=json.loads(buf.getvalue());self.assertEqual(row['stage'],wanted);self.assertEqual(row['exceptionCode'],code)
                self.assertEqual(row['direction'],{'SETUP':'UNKNOWN','HANDOFF':'CLIENT','RELAY_READ':'UPSTREAM','RELAY_WRITE':'CLIENT'}[wanted])
                self.assertEqual(row['tunneled'],wanted.startswith('RELAY'))
                self.assertEqual(set(row),{'event','stage','direction','exceptionCode','tunneled'})
                self.assertTrue(policy.failed);self.assertTrue(policy.finished)
                if wanted!='SETUP':self.assertTrue(upstream.closed)
                self.assertNotIn('TOKEN',buf.getvalue());self.assertNotIn('SECRET',buf.getvalue());records.append(row)
    def test_finish_logging_cannot_change_cleanup_or_exception_identity(self):
        def context(registry_error=None,winner_error=None):
            def close_registry():
                if registry_error:raise registry_error
            def close_winner():
                if winner_error:raise winner_error
            r=Request.__new__(Request);r.failed=False;r.tunnel=True;r.cid='OWNER_SECRET'
            r.registry=types.SimpleNamespace(close=close_registry);r.winner=types.SimpleNamespace(close=close_winner)
            r.trace=types.SimpleNamespace(observe=lambda *a,**k:None,mark_incomplete=lambda:setattr(r,'incomplete',True))
            return r
        r=context(registry_error=OSError(SECRET));buf=io.StringIO()
        with contextlib.redirect_stdout(buf):r.finish()
        self.assertTrue(r.failed);self.assertTrue(r.incomplete);row=json.loads(buf.getvalue())
        self.assertEqual((row['stage'],row['exceptionCode']),('FINISH','OTHER'));records.append(row)
        sentinel=BrokenPipeError(errno.EPIPE,SECRET);r=context(winner_error=sentinel);buf=io.StringIO()
        with contextlib.redirect_stdout(buf),self.assertRaises(BrokenPipeError) as raised:r.finish()
        self.assertIs(raised.exception,sentinel);self.assertNotIn('SECRET',buf.getvalue())
        r=context(registry_error=OSError(SECRET))
        with patch('builtins.print',side_effect=OSError(SECRET)):r.finish()
        self.assertTrue(r.failed);self.assertTrue(r.incomplete)
    def test_reason_whitelist_bounded_and_broker_verdict_unchanged(self):
        tree=ast.parse((ROOT/'apps/egress/src/tiktok_policy/batch_validation.py').read_text())
        defined={n.args[0].value for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='bad' and n.args and isinstance(n.args[0],ast.Constant)}
        self.assertEqual(VALIDATION_REASON_CODES,defined)
        b=Broker();p=dict(op='open',id='a'*64,job='b'*64,phase='analyze',deadline=int(time.time()*1000)+30000)
        opened=b.command(p);p.update(op='seal',epoch=opened['epoch']);p.pop('deadline');e=b.entries[p['id']]
        ctx=types.SimpleNamespace(cid='OWNER_SECRET',_phase_key=p['id'],client=types.SimpleNamespace(fileno=lambda:-1),loop_closed=True,
            failed=True,trace=types.SimpleNamespace(incomplete=False),registry=types.SimpleNamespace(live=lambda:0,pending=set(),reap_failed=False),dns=dict(dnsExit=0,dnsChildReaped=True,dnsGroupLeft=0))
        result=dict(ownerID=ctx.cid,accepted=False,validation=dict(accepted=False,reasonCodes=[SECRET,{},'A'*300]+sorted(defined)),workerThreadClosed=True,clientClosed=True,loopClosed=True,traceIncomplete=False)
        e['members'][ctx.cid]=dict(ctx=ctx,accepted=None);buf=io.StringIO()
        with contextlib.redirect_stdout(buf):b.finish(ctx,result);reply=b.command(p)
        row=json.loads(buf.getvalue().splitlines()[0]);self.assertEqual(len(row['validationReasonCodes']),8)
        self.assertTrue(all(c in defined and len(c)<=32 for c in row['validationReasonCodes']))
        self.assertNotIn('SECRET',buf.getvalue());self.assertEqual(reply['state'],'REJECTED');self.assertIsNone(e['members'][ctx.cid]['ctx']);records.append(row)
        ctx.failed=False;result.update(accepted=True,validation=dict(accepted=True,reasonCodes=[]));e['members'][ctx.cid]=dict(ctx=ctx,accepted=None)
        buf=io.StringIO()
        with contextlib.redirect_stdout(buf):b.finish(ctx,result)
        self.assertEqual(buf.getvalue(),'');self.assertTrue(e['members'][ctx.cid]['accepted'])
if __name__=='__main__':
    result=unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Observation))
    (OUT/'result.json').write_text(json.dumps(dict(status='PASS' if result.wasSuccessful() else 'FAIL',groups=result.testsRun,records=records,sourceRequests=0,sockets=0,nativeChildren=0),indent=2),encoding='utf8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
