"""Offline counterexamples. Emits only fixed labels, numbers and pinned hashes."""
import asyncio
import copy
import hashlib
import importlib.metadata
import io
import json
import os
import pathlib
import socket
import sys
import threading
import time
from unittest.mock import patch

sys.path[:0] = ['/research', '/integration', '/vendor']
import model
import dns_helper
from candidate import guard
from dns_diagnostic import observe
import test_diagnostics  # Reuse existing narrow child supervision probes, not main().
import aiohappyeyeballs

OUT = pathlib.Path('/out')
CASES = []
SECRET = 'FAKE_PATH_TOKEN?FAKE_QUERY_TOKEN=fixture_cookie'


def check(value, code):
    if not value:
        raise AssertionError(code)


def save(name, row):
    encoded = json.dumps(row, indent=2)
    check(SECRET not in encoded, 'SANITIZED')
    with (OUT/name).open('x') as f:
        f.write(encoded)


def record(name, **data):
    CASES.append(dict(case=name, status='PASS', **data))


def v4(n=1, **changes):
    return (socket.AF_INET, changes.get('kind', socket.SOCK_STREAM), changes.get('proto', 6),
            changes.get('canon', ''), (changes.get('host', '8.8.8.'+str(n)), changes.get('port', 443)))


def v6(**changes):
    return (socket.AF_INET6, socket.SOCK_STREAM, changes.get('proto', 6), '',
            (changes.get('host', '2001:4860:4860::8888'), changes.get('port', 443),
             changes.get('flow', 0), changes.get('scope', 0)))


def current_case(name, rows, expected, b_expected, unique=None):
    inp = io.TextIOWrapper(io.BytesIO(json.dumps(dict(mode='hostname', hostname='FAKE_NOT_RESOLVED',
                          deadline=time.monotonic()+10, addresses=[], blocked=[])).encode()))
    buffer = io.BytesIO()
    out = io.TextIOWrapper(buffer)
    try:
        with patch('dns_helper.socket.getaddrinfo', return_value=rows) as resolver, patch.object(sys, 'stdin', inp), patch.object(sys, 'stdout', out):
            rc = dns_helper.main()
        check(resolver.call_count == 1, 'MOCK_CALLS')
        check(rc == 0, 'HELPER_FUNCTION_RETURN')
        packet = json.loads(buffer.getvalue())
    finally:
        inp.close(); out.close()
    code = packet.get('code', 'OK')
    check(code == expected, 'PINNED_CODE')
    accepted = False
    if code == 'OK':
        try:
            guard(packet['answers']); accepted = True
        except (ValueError, IndexError, TypeError):
            pass
    counts = model.diagnostics_a(rows, time.monotonic()+10)
    check(model.counts_valid(counts), 'COUNTS_SCHEMA')
    check(len(json.dumps(counts).encode()) <= model.COUNT_BYTES, 'COUNTS_BYTE_CAP')
    b_code, selected = model.policy_b(rows, time.monotonic()+10)
    check(b_code == b_expected, 'B_CODE')
    if unique is not None:
        check(len(selected) == unique, 'B_ENDPOINT_COUNT')
    if len(rows) > 64:
        check(counts['rawCountMode'] == 'AT_LEAST_65' and counts['endpointCount'] is None and not accepted, 'NO_OVER_CAP_SCAN_OR_ACCEPT')
    record(name, rawFixtureCount=len(rows), helperFunctionReturn=rc, helperStatus=packet['status'],
           helperCode=code, currentGuardAccepted=accepted, diagnosticObserver=observe(packet)['evidence'],
           countsA=counts, modelBCode=b_code, modelBSelected=len(selected))


def tuple_cases():
    current_case('raw64_unique64', [v4(i+1) for i in range(64)], 'OK', 'MODEL_ACCEPT_ONLY', 64)
    current_case('raw65_unique1', [v4()]*65, 'ANSWER_CAP', 'MODEL_ACCEPT_ONLY', 1)
    current_case('raw65_unique65', [v4(i+1) for i in range(65)], 'ANSWER_CAP', 'UNIQUE_BOUND', 0)
    current_case('ipv4_duplicates', [v4(), v4()], 'OK', 'MODEL_ACCEPT_ONLY', 1)
    current_case('ipv6_text_duplicates', [v6(), v6(host='2001:4860:4860:0:0:0:0:8888')], 'OK', 'MODEL_ACCEPT_ONLY', 1)
    for label, rows, count in [
        ('dual_family', [v4(), v6()], 2),
        ('mapped_ipv6_distinct', [v4(), v6(host='::ffff:8.8.8.1')], 2),
        ('scope_distinct', [v6(scope=1), v6(scope=2)], 2),
        ('flow_distinct', [v6(flow=1), v6(flow=2)], 2),
        ('protocol0_6_distinct', [v4(proto=0), v4(proto=6)], 2),
        ('canon_not_socket_argument', [v4(canon='FIRST_FAKE'), v4(canon='SECOND_FAKE')], 1),
    ]:
        check(len({model.endpoint_key(r) for r in rows}) == count, 'EQUIVALENCE_FIELDS')
        current_case(label, rows, 'OK', 'MODEL_ACCEPT_ONLY', count)
    for name, row, b_code in [('port_distinct', v4(port=444), 'POLICY_DENIED'),
                             ('protocol17_distinct', v4(proto=17), 'POLICY_DENIED'),
                             ('type_distinct', v4(kind=socket.SOCK_DGRAM), 'POLICY_DENIED')]:
        check(model.endpoint_key(v4()) != model.endpoint_key(row), 'NO_UNSAFE_MERGE')
        current_case(name, [v4(), row], 'OK', b_code, 0)
    # Deny a bad row anywhere, including beyond the current raw64 boundary.
    for name, bad, b_code in [('private', v4(host='10.0.0.1'), 'POLICY_DENIED'),
                             ('invalid', v4(host='FAKE_INVALID'), 'ROW_INVALID')]:
        for position in (0, 32, 64):
            rows = [v4()]*64; rows.insert(position, bad)
            current_case(name+'_position_'+str(position), rows, 'ANSWER_CAP', b_code, 0)
        current_case(name+'_within_raw64', [v4(), bad], 'OK', b_code, 0)
    for name, row in [('scope_text', v6(host='2001:4860:4860::8888%1')),
                      ('wrong_family', (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('2001:4860::8888',443))),
                      ('flow_overflow', v6(flow=1048576)), ('scope_overflow', v6(scope=4294967296)),
                      ('bool_port', v4(port=True)), ('missing_scope', (*v6()[:4], v6()[4][:3]))]:
        check(model.policy_b([row], time.monotonic()+10)[0] == 'ROW_INVALID', 'INVALID_ROW_DENY')
        record(name, modelBCode='ROW_INVALID')
    check(model.policy_b([v4()]*66, time.monotonic()+10)[0] == 'RAW_BOUND', 'B_RAW_WITNESS_BOUND')
    record('witness_raw66_denied', modelBCode='RAW_BOUND', modelOnlyRawBound=65)
    check(model.policy_b([], time.monotonic()+10)[0] == 'ROW_INVALID', 'EMPTY_DENIED')
    record('empty_no_resolution_pass')
    # Source row never implies TCP reachability; preserve existing pinned is_global policy.
    record('current_public_policy', classifier='PYTHON3_11_2_IS_GLOBAL', reachability='UNKNOWN')


def schema_cases():
    good = model.diagnostics_a([v4(),v4(),v6()], time.monotonic()+10)
    check(good['endpointCount'] == 2 and good['duplicateCount'] == 1 and good['ipv4Rows'] == 2 and good['ipv6Rows'] == 1, 'COUNTS_MEANING')
    for name, field, value in [('bool_count','rawCount',True), ('negative','endpointCount',-1),
                               ('huge','duplicateCount',65536), ('sum_conflict','endpointCount',3),
                               ('family_conflict','ipv6Rows',2), ('mode_conflict','rawCountMode','AT_LEAST_65'),
                               ('unknown_enum','reason',SECRET), ('unknown_version','version',2)]:
        bad=dict(good);bad[field]=value
        check(not model.counts_valid(bad), 'SCHEMA_CONFLICT')
        record('schema_'+name, accepted=False)
    for name, bad in [('missing',{}),('array',[]),('extra',dict(good, secret=SECRET))]:
        check(not model.counts_valid(bad), 'EXACT_SCHEMA')
        record('schema_'+name, accepted=False)
    for name, count in [('overflow65',65),('overflow_large',10000)]:
        count_rows=[v4()]*count
        with patch('model.endpoint_key', side_effect=AssertionError('OVERFLOW_MUST_NOT_SCAN')):
            result=model.diagnostics_a(count_rows,time.monotonic()+10)
        check(model.counts_valid(result) and result['rawCount']==65 and result['endpointCount'] is None, 'SATURATION_NO_SCAN')
        record(name, counts=result)
    end=time.monotonic()-1
    check(model.policy_b([v4()],end)[0]=='DEADLINE' and model.diagnostics_a([v4()],end)['reason']=='DEADLINE','EXPIRED')
    record('deadline_before_scan')
    # Deterministic clock expires while validation is in progress, then while dedup runs.
    for name, times in [('deadline_during_validation',[0,0,11]),('deadline_during_dedup',[0,0,0,0,0,11])]:
        iterator=iter(times)
        check(model.policy_b([v4(),v4()],10,clock=lambda:next(iterator))[0]=='DEADLINE','ABSOLUTE_MODEL_END')
        record(name, modelBCode='DEADLINE')
    counts=model.diagnostics_a([v4(host='FAKE_INVALID')],time.monotonic()+10)
    check(model.counts_valid(counts) and counts['evidence']=='PARTIAL' and counts['endpointCount'] is None,'INCOMPLETE_NOT_SUCCESS')
    record('counts_invalid_unknown',counts=counts)


class FakeSocket:
    def __init__(self, info):
        self.info=info;self.closed=False
    def setblocking(self, value):
        pass
    def close(self):
        self.closed=True


class FakeConnectLoop(asyncio.SelectorEventLoop):
    async def sock_connect(self, sock, address):
        self.received.append((sock.info[0],sock.info[1],sock.info[2],address))
        if self.failure is not None:
            raise self.failure
        if self.waiting or self.loser and sock.info is self.first:
            await asyncio.sleep(10)


def public_connection_cases():
    # Public start_connection/socket_factory only; no private library helpers or TCP.
    for name, rows, mode in [('library_fields',[v6(flow=1,scope=2)],'ok'),
                            ('library_primary_exception',[v4()],'error'),
                            ('library_cancel_closes',[v4()],'cancel'),
                            ('library_stagger_loser_closed',[v4(),v6()],'loser')]:
        loop=FakeConnectLoop();loop.received=[];loop.failure=OSError(SECRET) if mode=='error' else None;loop.waiting=mode=='cancel';loop.loser=mode=='loser';loop.first=rows[0];sockets=[]
        def factory(info):
            sock=FakeSocket(info);sockets.append(sock);return sock
        async def invoke():
            task=asyncio.create_task(aiohappyeyeballs.start_connection(rows,loop=loop,socket_factory=factory,interleave=0,happy_eyeballs_delay=.25))
            if mode=='cancel':loop.call_later(.01,task.cancel)
            try:
                winner=await task
                check(mode in ('ok','loser'),'UNEXPECTED_WINNER');winner.close()
            except OSError as exc:
                check(mode=='error' and exc is loop.failure,'PRIMARY_IDENTITY')
            except asyncio.CancelledError:
                check(mode=='cancel','CANCEL_IDENTITY')
            check(loop.received==[(r[0],r[1],r[2],r[4]) for r in rows],'PUBLIC_LIBRARY_FIELDS')
            check(all(s.closed for s in sockets) and not [t for t in asyncio.all_tasks() if t is not asyncio.current_task() and not t.done()],'LIBRARY_REAP')
        try:loop.run_until_complete(invoke())
        finally:loop.close()
        record(name, publicLibraryCalled=True, fakeSocketsCreated=len(sockets), fakeSocketsClosed=len(sockets),realSocketConnects=0,primaryIdentity=mode=='error')


async def ipc_cases():
    # Exact predecessor function; real Popen/numeric AI_NUMERICHOST, no Internet DNS.
    for name, kwargs in [
        ('research_ipc_numeric',{}),
        ('research_ipc_deadline',dict(delay=2,budget=.25,expected='TimeoutError')),
        ('research_ipc_cancel',dict(delay=2,cancel=True,expected='CancelledError')),
        ('research_ipc_oversize',dict(mode='oversize',expected='ValueError')),
        ('research_ipc_answers65',dict(mode='answer-oversize',expected='ValueError')),
        ('research_ipc_child20',dict(mode='crash',expected='OSError')),
        ('research_ipc_primary_trace',dict(fault='raise',primary=True,expected='OSError')),
        ('research_ipc_incomplete_trace',dict(fault='missing',expected='DiagnosticIncomplete')),
    ]:
        await test_diagnostics.dns_case(name,**kwargs)
        row=test_diagnostics.RESULTS[-1]
        record(name,helperNativeExit=row['receipt']['dnsExit'],exception=row['exception'],
               helperReaped=row['receipt']['dnsChildReaped'],pipesClosed=row['receipt']['dnsPipesClosed'],
               groupsLeft=row['receipt']['dnsGroupLeft'],evidence=row['receipt']['dnsDiagnostic']['evidence'],
               resolution=row['receipt']['dnsDiagnostic']['resolution'],primaryIdentity=row['primaryIdentity'])


def helper_limits():
    for name, body, answer, expected_rc, expected_code in [
        ('helper_input_cap',b'X'*16385,[],20,None),
        ('helper_output_cap',None,[v4(canon='X'*32768)],20,None),
        ('helper_deadline',None,[],0,'DEADLINE'),
    ]:
        if body is None:
            body=json.dumps(dict(mode='hostname',hostname='FAKE_NOT_RESOLVED',addresses=[],blocked=[],
                deadline=time.monotonic()+(-1 if expected_code else 10))).encode()
        inp=io.TextIOWrapper(io.BytesIO(body));buffer=io.BytesIO();out=io.TextIOWrapper(buffer)
        try:
            with patch('dns_helper.socket.getaddrinfo',return_value=answer),patch.object(sys,'stdin',inp),patch.object(sys,'stdout',out):
                rc=dns_helper.main()
            check(rc==expected_rc,'HELPER_LIMIT_RETURN')
            if expected_code:check(json.loads(buffer.getvalue())['code']==expected_code,'DEADLINE_CODE')
            else:check(not buffer.getvalue(),'NO_OVERSIZE_PACKET')
        finally:inp.close();out.close()
        record(name,helperFunctionReturn=rc,expectedCode=expected_code,rawPayloadLogged=False)


def main():
    check(sys.version.split()[0]=='3.11.2' and os.getuid()==65534,'RUNTIME_PIN')
    check(importlib.metadata.version('aiohappyeyeballs')=='2.7.1','LIBRARY_PIN')
    before_fd=len(os.listdir('/proc/self/fd'));before_threads=threading.active_count()
    tuple_cases();schema_cases();helper_limits();public_connection_cases();asyncio.run(ipc_cases())
    check(before_fd==len(os.listdir('/proc/self/fd')) and before_threads==threading.active_count(),'BASELINE_CLEANUP')
    for p in OUT.glob('research_ipc*.json*'):
        data=p.read_text()
        check(all(s not in data for s in (SECRET,'FAKE_PATH_TOKEN','fixture_cookie','1.1.1.1','https://')),'IPC_REDACTION')
    hashes={name:hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() for name,path in {
        'helper':'/integration/dns_helper.py','ipc':'/integration/dns_ipc.py','guard':'/integration/candidate.py',
        'childProbe':'/integration/test_diagnostics.py','model':'/research/model.py','probe':'/research/probe.py',
        'stdlibSocket':socket.__file__,'publicLibrary':aiohappyeyeballs.impl.__file__}.items()}
    save('result.json',dict(status='PASS_OFFLINE_RESEARCH_NOT_RUNTIME_OR_SOURCE_GATE',actualExit=0,cases=CASES,
        caseCount=len(CASES),python=sys.version.split()[0],library='aiohappyeyeballs2.7.1',hashes=hashes,
        fdBefore=before_fd,fdAfter=len(os.listdir('/proc/self/fd')),threadsBefore=before_threads,threadsAfter=threading.active_count(),
        runtimeChanged=False,currentRawCap=64,modelOnlyWitnessRawBound=65,uniqueBound=64,
        realHelperProcessCalls=8,helperFunctionCalls=25,realSocketConnects=0,sourceCalls=0,internetDNS=0,
        workerInvocations=0,claimActions=0,sourceRawCount='UNKNOWN_NOT_RETAINED',sourceUniqueCount='UNKNOWN_NOT_RETAINED'))
    print('PASS_OFFLINE_RESEARCH cases='+str(len(CASES)),flush=True)


if __name__=='__main__':
    try:main()
    except BaseException as exc:
        if isinstance(exc,SystemExit):raise
        save('failure.json',dict(code='RESEARCH_PROBE_FAIL',actualExit=20,completedCases=len(CASES),
            exception=type(exc).__name__ if type(exc).__name__ in ('AssertionError','ValueError','TypeError','RuntimeError','OSError','StopIteration') else 'UNKNOWN'))
        print('RESEARCH_PROBE_FAIL',flush=True);sys.exit(20)
