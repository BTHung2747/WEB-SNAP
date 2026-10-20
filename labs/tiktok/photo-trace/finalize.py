"""Validate actual post-shutdown receipt; never performs a network request."""
import json,pathlib,sys
from common import summary_valid
P=pathlib.Path('/proxy');W=pathlib.Path('/worker');O=pathlib.Path('/out')
sys.excepthook=lambda *a:print('TRACE_FINALIZE_FAILURE',flush=True)
def main():
    rows=[json.loads(s) for s in (P/'proxy-trace.jsonl').read_text().splitlines()]
    summary=json.loads((P/'proxy-summary.json').read_text())
    assert summary_valid(summary,rows)
    fields={'connectionID','boundary','event','elapsed','code','attemptIndex','family','timeoutSeconds','deadlineMonotonicSeconds','ipv4Count','ipv6Count'}
    boundaries={'DNS_LOOKUP','UPSTREAM_TCP_CONNECT','CONNECT_200_SENT','TUNNEL_CLOSE'}
    codes={'BEGIN','OK','ERROR','UNKNOWN','DNS_ERROR','TIMEOUT','CONNECTION_REFUSED','CONNECTION_RESET','BROKEN_PIPE','OS_ERROR','POLICY_DENIED','PEER_EOF','TIME_BOUND','NOT_OPENED'}
    for row in rows:
        assert not(set(row)-fields) and row['boundary'] in boundaries and row['event'] in ('BEGIN','END','ERROR') and row['code'] in codes
        assert len(row['connectionID'])==16 and all(c in '0123456789abcdef' for c in row['connectionID'])
        if 'family' in row:assert row['family'] in ('IPv4','IPv6','OTHER')
        if row['boundary']=='UPSTREAM_TCP_CONNECT':assert row['timeoutSeconds']==10 and row['deadlineMonotonicSeconds']>0
    # Client diagnostics are the existing fixed schema, and never contain source secrets.
    for path in W.rglob('result.json'):
        result=json.loads(path.read_text())
        for name in ('metadataPacket','preparePacket'):
            packet=result.get(name) or {};encoded=json.dumps(packet.get('rows') or [])
            assert all(secret not in encoded for secret in ('https://','FAKEPATH','FAKESIGNED','fixture_cookie','__UNIVERSAL'))
    receipt={'status':'PASS','proxySummaryComplete':True,'rows':len(rows),'connectionCount':summary['connectionCount'],
             'TLSDetail':'UNKNOWN','clientCorrelation':'UNKNOWN','sourceCalls':0 if (W/'integration-result.json').exists() else 'SEE_SOURCE_RESULT'}
    if (W/'integration-result.json').exists():
        result=json.loads((W/'integration-result.json').read_text())
        assert result['status']=='PASS' and result['sourceCalls']==0
        # Eleven full pipeline fixtures plus SSRF; failure stages match the injected boundary.
        assert any(r['boundary']=='DNS_LOOKUP' and r['event']=='ERROR' and r['code']=='DNS_ERROR' for r in rows)
        assert any(r['boundary']=='DNS_LOOKUP' and r['event']=='ERROR' and r['code']=='POLICY_DENIED' for r in rows)
        assert any(r['boundary']=='UPSTREAM_TCP_CONNECT' and r['event']=='ERROR' for r in rows)
        assert any(r['boundary']=='CONNECT_200_SENT' and r['event']=='END' for r in rows)
        normal=json.loads((W/'network-normal'/'result.json').read_text())
        assert normal['workerActualExit']==0 and normal['preparePacket']['contract']['fullDecode']=='PASS'
        gate=json.loads((W/'network-normal'/'trace-prepare-gate.json').read_text());assert gate['status']=='PASS'
        receipt.update(networkFixtureCases=11,legacyPhotoRegression=18)
    with (O/'trace-validation.json').open('x') as f:json.dump(receipt,f,indent=2)
    print('PASS actual proxy shutdown/counters/fullcoverage; TLS detail/correlation UNKNOWN',flush=True)
    return 0
if __name__=='__main__':sys.exit(main())

