"""Offline preparation only; no source CLI, allocation, DNS name or network."""
import asyncio,hashlib,json,os,pathlib,sys,threading
from unittest.mock import patch
OUT=pathlib.Path('/out')
def main():
    from common import inventory,versions,stage_policy,trust_hash,isolation
    before=len(os.listdir('/proc/self/fd'));threads=threading.active_count()
    assert sys.version.split()[0]=='3.11.2' and os.getuid()==65534
    assert stage_policy()=='offline'
    import proxy_entry,worker_entry,finalize
    isolation(OUT/'cold-import-isolation.json','source')
    assert trust_hash()=='9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'
    checks=['COLD_IMPORT_NO_FIXTURE_NO_SOURCE_MAIN','ORIGINAL_TRUST']
    with patch.dict(os.environ,{'WHOLEPHOTO_STAGE':'source'}):
        try:stage_policy()
        except RuntimeError:checks.append('CURRENT_PYTHON_SOURCE_BLOCKED')
        else:raise AssertionError('SOURCE_BLOCK')
    # Reuse earlier public-adapter fixture, with its source-policy entry excluded.
    # This is not the future source environment gate or a metadata/file pipeline.
    from adapter_probe import run as adapter_checks
    adapter=adapter_checks();checks.extend(adapter['checks'])
    from test_diagnostics import dns_case,RESULTS
    from dns_diagnostic import validate_receipt
    async def selected_dns():
        await dns_case('prep_dns_numeric_ok')
        await dns_case('prep_dns_getaddrinfo_error',mode='error',expected='OSError')
        await dns_case('prep_dns_trace_primary',fault='raise',primary=True,expected='OSError')
    asyncio.run(selected_dns())
    for row in RESULTS:
        verdict=validate_receipt(row['receipt'])
        assert verdict['accepted']==(row['exception'] is None)
        if row['exception'] is not None:assert verdict['status']=='PARTIAL'
    good=RESULTS[0]['receipt'];nested=good['dnsDiagnostic']
    for outer in ('dnsExit','dnsChildReaped','dnsPipesClosed','dnsGroupLeft'):
        bad=dict(good);bad[outer]='UNKNOWN'
        assert validate_receipt(bad)['status']=='PARTIAL'
    checks+=['NUMERIC_DNS_COMPLETE_SAME_HELPER','DNS_ERROR_NATIVE0_NOT_RESOLUTION_PASS',
             'TRACE_FAILURE_PRIMARY_IDENTITY_CLEANUP','OUTER_UNKNOWN_PARTIAL']
    from receipt_labels import labels,valid
    for stage in ('source','offline'):
        assert valid(labels(stage,False),stage)
        row=labels(stage,False);row['metadataPacket']={}
        assert not valid(row,stage)
        row.update(labels(stage,True));assert valid(row,stage)
    checks.append('SYNTHETIC_INVOCATION_EVIDENCE_NO_SOURCE')
    assert before==len(os.listdir('/proc/self/fd')) and threads==threading.active_count()
    assert not any(m in sys.modules for m in ('owned_fixture','offline_glue','test_photo','fixture'))
    row=dict(status='PASS_PREPARATION_ONLY_SOURCE_BLOCKED',actualExit=0,checks=checks,
        dnsCases=RESULTS,adapter=adapter,fdBefore=before,fdAfter=len(os.listdir('/proc/self/fd')),
        threadsBefore=threads,threadsAfter=threading.active_count(),sourceCalls=0,internetDNS=0,
        allocations=0,claimActions=0,sourceExecutableReady=False,futureWiringGate='NOT_RUN',
        trustSHA=trust_hash(),versions=versions(),python=sys.version.split()[0],sources=inventory(),
        preparationSources=[dict(path=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(pathlib.Path('/preflight').glob('*.py'))])
    (OUT/'preflight-result.json').write_text(json.dumps(row,indent=2))
    print('PASS_PREPARATION_ONLY_SOURCE_BLOCKED checks='+str(len(checks)),flush=True)
if __name__=='__main__':
    try:main()
    except BaseException:
        (OUT/'preflight-failure.json').write_text(json.dumps(dict(code='PREPARATION_PROBE_FAIL',actualExit=20)))
        print('PREPARATION_PROBE_FAIL',flush=True);sys.exit(20)
