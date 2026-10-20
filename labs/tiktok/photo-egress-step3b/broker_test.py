import copy,hashlib,json,os,pathlib,secrets,socket,threading,time
from types import SimpleNamespace as NS
os.environ.update(TIKTOK_EGRESS_POLICY_ENABLED='1',TIKTOK_EGRESS_CONTROL_SECRET='a'*64,TIKTOK_EGRESS_CONTROL_NETWORKS='127.0.0.0/8')
from tiktok_policy.control import Broker
def suite():
    result=[]
    def fresh(phase='analyze',seconds=10):return dict(op='open',id=secrets.token_hex(32),job=secrets.token_hex(32),phase=phase,deadline=int(time.time()*1000+seconds*1000))
    def command(p,r,op,**kw):return {**dict(op=op,id=p['id'],job=p['job'],phase=p['phase'],epoch=r['epoch']),**kw}
    def ctx():
        c=NS(cid=secrets.token_hex(8),client=NS(fileno=lambda:-1,shutdown=lambda *_:None),loop_closed=True,failed=False,trace=NS(incomplete=False),
            registry=NS(live=lambda:0,pending=set(),reap_failed=False),dns=dict(dnsExit=0,dnsChildReaped=True,dnsGroupLeft=0),cancel=threading.Event())
        return c,dict(ownerID=c.cid,accepted=True,workerThreadClosed=True,clientClosed=True,loopClosed=True,traceIncomplete=False,validation=dict(accepted=True))
    b=Broker();p=fresh();r=b.command(p);c,out=ctx();b.attach((p['id'],r['connectKey']),c)
    assert b.command(command(p,r,'seal'))['state']=='PENDING';b.finish(c,out)
    assert b.command(command(p,r,'poll'))['state']=='ACCEPTED';assert b.command(command(p,r,'take'))['state']=='ACCEPTED'
    assert b.command(command(p,r,'take'))['state']=='REJECTED';result.append('happy-consume-once-replay-denied')
    for mutation in ['accepted','workerThreadClosed','clientClosed','loopClosed','traceIncomplete','ownerID']:
        p=fresh();r=b.command(p);c,out=ctx();b.attach((p['id'],r['connectKey']),c)
        out[mutation]='bad' if mutation=='ownerID' else mutation=='traceIncomplete';b.finish(c,out)
        assert b.command(command(p,r,'seal'))['state']=='REJECTED';result.append('closure-'+mutation+'-reject')
    p=fresh();r=b.command(p);assert b.command(command(p,r,'seal'))['state']=='REJECTED';result.append('no-connections-no-vacuous-success')
    p=fresh();r=b.command(p);c,out=ctx();b.attach((p['id'],r['connectKey']),c)
    b.command(command(p,r,'seal'))
    try:b.attach((p['id'],r['connectKey']),ctx()[0]);raise AssertionError('late attach')
    except ValueError:pass
    assert b.command(command(p,r,'poll',job=secrets.token_hex(32)))['state']=='REJECTED'
    assert b.command(command(p,r,'poll',phase='prepare'))['state']=='REJECTED'
    assert b.command(command(p,r,'poll',epoch=secrets.token_hex(32)))['state']=='REJECTED';result.append('cross-job-phase-epoch-late-connect-denied')
    p=fresh();r=b.command(p)
    for _ in range(2):b.attach((p['id'],r['connectKey']),ctx()[0])
    try:b.attach((p['id'],r['connectKey']),ctx()[0]);raise AssertionError('overflow')
    except ValueError:pass
    assert b.command(command(p,r,'seal'))['state']=='REJECTED';result.append('connection-overflow')
    p=fresh(seconds=.1);r=b.command(p);time.sleep(.12);assert b.command(command(p,r,'seal'))['state']=='EXPIRED';result.append('absolute-expiry-no-renew')
    p=fresh();r=b.command(p);c,out=ctx();b.attach((p['id'],r['connectKey']),c);b.command(command(p,r,'abort'));assert c.cancel.is_set();assert b.command(command(p,r,'take'))['state']=='REJECTED';result.append('abort-only-owned-scope')
    limited=Broker();limited.limit=2;p=fresh();r=limited.command(p);q=fresh();rq=limited.command(q)
    assert limited.command(fresh())['state']=='REJECTED';assert limited.command(command(p,r,'seal'))['state']=='REJECTED'
    limited.entries[p['id']]['end']=time.monotonic()-6;limited.tick();assert limited.command(command(p,r,'poll'))['state']=='UNKNOWN';assert limited.command(fresh())['state']=='OPEN';result.append('retention-pressure-expired-unknown-no-lifetime-quota')
    for p in [dict(op='open'),dict(fresh(),extra='x'),dict(fresh(),deadline=float('nan'))]:
        try:v=b.command(p);assert v['state']!='OPEN'
        except ValueError:pass
    result.append('strict-schema')
    for network in ['0.0.0.0/0','0.0.0.0/1','::/0','169.254.0.0/16']:
        os.environ['TIKTOK_EGRESS_CONTROL_NETWORKS']=network;assert not Broker().enabled
    os.environ['TIKTOK_EGRESS_CONTROL_NETWORKS']='127.0.0.0/8';assert Broker().enabled
    result.append('internal-CIDR-no-catchall-or-linklocal')
    pathlib.Path('/control/broker-result.json').write_text(json.dumps(dict(status='PASS_BROKER_OFFLINE',cases=result,sourceCalls=0),indent=2));print('PASS broker',len(result))
if __name__=='__main__':suite()
