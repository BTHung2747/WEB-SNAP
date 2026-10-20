"""Offline-only owned Request negative path and projection/fault fixtures."""
import copy,json,pathlib,socket,types
from tiktok_policy.runtime import Request
from tiktok_policy.control import Broker
from proxy_collect import project,install
def run(root,mode):
    client,peer=socket.socketpair();ctx=Request(client);code='UNKNOWN'
    try:ctx.connect('') # Empty hostname is rejected before getaddrinfo.
    except OSError:code='OS_ERROR'
    finally:ctx.finish();client.close();peer.close()
    result=ctx.complete(True)
    assert code=='OS_ERROR' and ctx.loop_closed and ctx.registry.live()==0
    actual=project(ctx,result,'analyze');expected=20 if mode=='corrected' else 1
    assert actual['dns']['nativeExit']==expected and actual['dns']['reaped'] and actual['dns']['groupsLeft']==0
    assert actual['dns']['responseBytes']==0 and actual['dns']['admissionReason']=='UNKNOWN' and not actual['accepted']
    assert any(r['phase']=='DNS_HELPER' and r['event']=='ERROR' for r in actual['boundaries'])
    (root/'owned-failure.json').write_text(json.dumps(actual,separators=(',',':')))
    broker=Broker();server=types.SimpleNamespace(phase_broker=broker);install(server,root)
    assert server.phase_broker.finish(ctx,result) is None
    missing=project(ctx,dict(ownerID=ctx.cid,accepted=False),'analyze')
    assert not missing['diagnosticComplete'] and missing['dns']['nativeExit']=='UNKNOWN'
    dirty=copy.deepcopy(result);dirty.update(url='https://fake.invalid/PATH_TOKEN?QUERY_TOKEN',cookie='COOKIE_TOKEN')
    dirty['trace'][0].update(host='HOST_TOKEN',ip='IP_TOKEN',message='MESSAGE_TOKEN')
    safe=json.dumps(project(ctx,dirty,'analyze'))
    assert all(v not in safe for v in ('PATH_TOKEN','QUERY_TOKEN','COOKIE_TOKEN','HOST_TOKEN','IP_TOKEN','MESSAGE_TOKEN','https://'))
    unsupported=copy.deepcopy(result);unsupported['trace'][0]['code']='TOKEN_SECRET'
    assert not project(ctx,unsupported,'analyze')['diagnosticComplete']
    calls=[]
    class Delegate:
        entries={}
        def finish(self,c,r):calls.append((c,r));return 83
    fault=root/'not-a-directory';fault.write_text('fixture')
    server=types.SimpleNamespace(phase_broker=Delegate());install(server,fault)
    assert server.phase_broker.finish(ctx,result)==83 and len(calls)==1 and calls[0][1] is result and ctx.trace.incomplete
    assert ctx.client.fileno()==-1 and not ctx.registry.pending and ctx.registry.live()==0
    cap=copy.deepcopy(result);cap['trace']=[result['trace'][0]]*129
    assert not project(ctx,cap,'analyze')['diagnosticComplete']
    summary=dict(status='PASS_NARROW_COLLECTOR_OFFLINE',cases=7,actualOwnedNegative=True,constructedProjectionFixtures=True,collectorSinkFailureDelegateCalls=1,childNativeExit=expected,pipesClosed=ctx.dns.get('dnsPipesClosed'),groupsLeft=ctx.dns.get('dnsGroupLeft'),socketPairClosed=True,sourceRequests=0,publicDNS=0)
    (root/'collector-result.json').write_text(json.dumps(summary))
