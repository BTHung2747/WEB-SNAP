"""Pure Broker command/finish, no sockets, DNS, child or runtime server."""
import contextlib,io,json,pathlib,sys,time,types,unittest
from unittest.mock import patch
sys.dont_write_bytecode=True
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'apps/egress/src'))
from tiktok_policy.control import Broker
OUT=pathlib.Path(sys.argv.pop(1));records=[]
class Observation(unittest.TestCase):
    def fresh(self):
        b=Broker();p=dict(op='open',id='a'*64,job='b'*64,phase='analyze',deadline=int(time.time()*1000)+30000)
        opened=b.command(p);p.update(op='seal',epoch=opened['epoch']);p.pop('deadline')
        return b,p,b.entries[p['id']]
    def test_empty_refusal_reply_and_safe_flags(self):
        b,p,e=self.fresh();buf=io.StringIO()
        with contextlib.redirect_stdout(buf):reply=b.command(p)
        self.assertEqual(reply['state'],'REJECTED');self.assertEqual(reply['connections'],0)
        self.assertEqual(set(reply),{'v','id','job','phase','epoch','state','connections'})
        record=json.loads(buf.getvalue());self.assertEqual(record['memberCount'],0);self.assertTrue(record['sealed'])
        self.assertFalse(record['expired']);self.assertFalse(record['failed']);self.assertFalse(record['consumed'])
        records.append(record)
    def test_member_predicates_and_logging_failure_keep_decision(self):
        b,p,e=self.fresh()
        ctx=types.SimpleNamespace(cid='SECRET_OWNER',_phase_key=p['id'],client=types.SimpleNamespace(fileno=lambda:-1),
          loop_closed=True,failed=False,trace=types.SimpleNamespace(incomplete=False),
          registry=types.SimpleNamespace(live=lambda:0,pending=set(),reap_failed=False),
          dns=dict(dnsExit=0,dnsChildReaped=True,dnsGroupLeft=0))
        result=dict(ownerID=ctx.cid,accepted=True,validation=dict(accepted=False),workerThreadClosed=True,
          clientClosed=True,loopClosed=True,traceIncomplete=False,url='PATH_SECRET',trace=['QUERY_SECRET'],receipt={'token':'CAP_SECRET'})
        e['members'][ctx.cid]=dict(ctx=ctx,accepted=None);buf=io.StringIO()
        with contextlib.redirect_stdout(buf):b.finish(ctx,result);reply=b.command(p)
        rows=[json.loads(line) for line in buf.getvalue().splitlines()]
        member=rows[0];self.assertEqual(member['event'],'proxy_member_refused');self.assertFalse(member['validationAccepted'])
        self.assertTrue(member['ownerMatch']);self.assertTrue(member['resultAccepted']);self.assertTrue(member['registryClean'])
        self.assertEqual(member['dnsExit'],0);self.assertTrue(member['dnsChildReaped']);self.assertEqual(member['dnsGroupLeft'],0)
        self.assertEqual(reply['state'],'REJECTED');self.assertIsNone(e['members'][ctx.cid]['ctx'])
        self.assertIs(e['members'][ctx.cid]['accepted'],False)
        self.assertFalse(any(x in buf.getvalue() for x in ['SECRET_OWNER','PATH_SECRET','QUERY_SECRET','CAP_SECRET',p['id'],p['job'],p['epoch']]))
        records.extend(rows)
        # Best-effort logger cannot block member closure or the original refusal.
        e['members'][ctx.cid]=dict(ctx=ctx,accepted=None)
        with patch('builtins.print',side_effect=OSError('fixture-only')):b.finish(ctx,result);again=b.command(dict(p,op='poll'))
        self.assertEqual(again['state'],'REJECTED');self.assertIsNone(e['members'][ctx.cid]['ctx'])
        self.assertIs(e['members'][ctx.cid]['accepted'],False)
if __name__=='__main__':
    result=unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Observation))
    (OUT/'broker-result.json').write_text(json.dumps(dict(status='PASS' if result.wasSuccessful() else 'FAIL',tests=result.testsRun,
        records=records,sourceRequests=0,sockets=0,nativeChildren=0),indent=2),encoding='utf8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
