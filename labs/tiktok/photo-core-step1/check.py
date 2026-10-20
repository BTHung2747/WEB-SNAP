"""Offline module/pipeline checks. No source authority, network or app activation."""
import dataclasses
import hashlib
import json
import os
import pathlib
import signal
import subprocess
import sys
import time
import uuid

from fixtures import Factory, URL, EXPECTED, body
from tiktok.photo_contract import PhotoError, summary, validate_summary, format_id, select, public_metadata
from tiktok.photo_core import PhotoLimits, PhotoBudget, analyze_album, prepare_photo
from tiktok.prepare_operations import Operations

OUT = pathlib.Path('/out')
ROOT = pathlib.Path('/media')
JPEG = pathlib.Path('/tmp/input.jpg')


def job():
    folder = ROOT / str(uuid.uuid4())
    folder.mkdir()
    (folder / 'sentinel').write_bytes(b'PRESERVE')
    return folder


def invoke(phase, mode, folder, selected=None, limits=None):
    prior_part = (folder/'image.jpg.part').read_bytes() if (folder/'image.jpg.part').is_file() else None
    cancelled = [False]
    factory = Factory(mode, JPEG, folder, cancelled)
    diagnostics = {}
    error = None
    result = None
    try:
        options = dict(session_factory=factory, diagnostics=diagnostics, limits=limits,
                       cancelled=lambda: cancelled[0])
        result = analyze_album(URL, folder, **options) if phase == 'analyze' else prepare_photo(URL, folder, selected, **options)
    except PhotoError as e:
        error = e.code
    assert (folder / 'sentinel').read_bytes() == b'PRESERVE'
    stats = factory.stats()
    assert all(s['closed'] and s['cookiesRemaining'] == 0 and s['responsesClosed'] for s in stats)
    if prior_part is None:
        assert not (folder / 'image.jpg.part').exists()
    else:
        assert (folder/'image.jpg.part').read_bytes() == prior_part
    public = json.dumps(dict(result=result, error=error, diagnostics=diagnostics))
    assert all(secret not in public for secret in ('FAKE_PATH_TOKEN', 'FAKE_QUERY_TOKEN', 'fixture_cookie', '<script'))
    return result, error, diagnostics, stats


def child():
    spec = json.loads(pathlib.Path(sys.argv[2]).read_text())
    folder = pathlib.Path(spec['folder'])
    phase = spec['phase']
    selected = spec.get('selected')
    if spec['mode'] in ('decode-fail', 'decode-kill'):
        import tiktok.photo_core as core
        class DecodeFailure(Operations):
            def native(self, operation, argv, cap, **kwargs):
                if operation == 'DECODE':
                    action = 'raise SystemExit(20)' if spec['mode']=='decode-fail' else 'import os,signal;os.kill(os.getpid(),signal.SIGKILL)'
                    return super().native(operation, ['python3','-c',action], cap, **kwargs)
                return super().native(operation, argv, cap, **kwargs)
        core.Operations = DecodeFailure
    result, error, diagnostics, sessions = invoke(phase, spec['mode'], folder, selected,
            PhotoLimits(**spec['limits']) if spec.get('limits') else None)
    row = dict(result=result, error=error, diagnostics=diagnostics, sessions=sessions,
               filesAfterCall={name:(folder/name).exists() for name in ('image.jpg','image.jpg.part')})
    print(json.dumps(row), flush=True)
    if error:
        return 20
    if spec['mode'] == 'pass-exit20':
        return 20
    if spec['mode'] == 'pass-hang':
        time.sleep(10)
    return 0


def run_child(phase, mode, selected=None, folder=None, cap=8, limits=None):
    folder = folder or job()
    control = OUT / ('control-' + uuid.uuid4().hex + '.json')
    control.write_text(json.dumps(dict(phase=phase, mode=mode, selected=selected, folder=str(folder),
                                      limits=dataclasses.asdict(limits) if limits else None)))
    args = ['python3', '/fixture/check.py', 'child', str(control)]
    start = time.monotonic()
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    killed = False
    try:
        stdout, stderr = p.communicate(timeout=cap)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        stdout, stderr = p.communicate()
        killed = True
    # New namespace and known names belong to this parent, never to packet paths.
    row = json.loads(stdout.splitlines()[-1]) if stdout.strip() else None
    assert all(s not in stdout + stderr for s in (b'FAKE_PATH_TOKEN', b'FAKE_QUERY_TOKEN', b'fixture_cookie', b'<script'))
    accepted = p.returncode == 0 and not killed and row is not None and row['error'] is None
    cleanup = []
    if not accepted:
        for name in ('image.jpg', 'image.jpg.part'):
            path = folder / name
            if path.is_file() and not path.is_symlink():
                path.unlink()
                cleanup.append(name)
    assert (folder / 'sentinel').read_bytes() == b'PRESERVE'
    try:
        os.killpg(p.pid, 0)
        raise AssertionError('Child process group remains')
    except ProcessLookupError:
        pass
    receipt = dict(case=mode, phase=phase, actualExit=p.returncode, killed=killed, accepted=accepted,
                   elapsed=round(time.monotonic()-start, 6), timeout=cap,
                   cleanup=cleanup, packet=row, stderrBytes=len(stderr),
                   sanitizedStderr=stderr.decode('utf8',errors='replace'))
    (OUT / ('child-' + control.stem[8:] + '.json')).write_text(json.dumps(receipt, indent=2))
    return receipt, folder


def suite():
    results = []
    for name, size in (('input.jpg', '64x64'), ('wrong.jpg', '32x32')):
        p = subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-f', 'lavfi', '-i', f'color=c=blue:s={size}',
                            '-frames:v', '1', '-threads', '1', '-filter_threads', '1', '/tmp/' + name],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        assert p.returncode == 0
        results.append(dict(case='generate-' + name, actualExit=p.returncode))
    a, folder = run_child('analyze', 'normal')
    assert a['accepted'] and a['packet']['sessions'] == [dict(metadataGET=2, imageGET=0, closed=True, cookiesRemaining=0, responsesClosed=True)]
    public = a['packet']['result']
    assert len(public['formats']) == 2 and all(len(f['id']) == 72 for f in public['formats'])
    selected = public['formats'][0]['id']
    b, _ = run_child('prepare', 'normal', selected, folder)
    assert b['accepted'] and b['packet']['sessions'] == [dict(metadataGET=2, imageGET=1, closed=True, cookiesRemaining=0, responsesClosed=True)]
    assert b['packet']['result']['sha256'] == hashlib.sha256(JPEG.read_bytes()).hexdigest()
    assert b['packet']['result']['contract']['fullDecode'] == 'PASS'
    assert b['packet']['result']['inputBytes'] > (folder / 'image.jpg').stat().st_size
    (OUT / 'fixture-output.jpg').write_bytes((folder / 'image.jpg').read_bytes())
    results.append(dict(case='two-independent-children', actualExits=[a['actualExit'], b['actualExit']],
                        requestBudget='2+2+1', fixtureOnly=True, sha256=b['packet']['result']['sha256'],
                        ffprobeAndDecode=[json.loads(x) for x in (folder/'tiktok-operations.jsonl').read_text().splitlines()]))
    # Same factory in one interpreter also proves core closes/clears sessions between calls.
    same_folder = job()
    factory = Factory('normal', JPEG, same_folder)
    m = analyze_album(URL, same_folder, session_factory=factory)
    prepare_photo(URL, same_folder, m['formats'][1]['id'], session_factory=factory)
    assert len(factory.sessions) == 2 and all(s['closed'] and not s['cookiesRemaining'] for s in factory.stats())
    results.append(dict(case='two-separate-RAM-sessions', sessions=factory.stats()))
    # Existing app validator must retain its video result and reject photos.
    for mode, expected_rc in (('nonphoto',0), ('normal',20)):
        p=subprocess.run(['node','/app/apps/media/src/tiktok/validate_cobalt_body.mjs',EXPECTED],
                         input=body(mode),capture_output=True,timeout=3)
        data=json.loads(p.stdout)
        assert p.returncode==expected_rc
        if expected_rc==0:
            assert data==dict(status='PASS',id=EXPECTED,duration=2,photo=False,private=False)
        else:
            assert data['error']=='UNSUPPORTED_CONTENT'
        results.append(dict(case='existing-video-validator-'+mode,actualExit=p.returncode,publicPacket=data))
    record, f = run_child('analyze', 'metadata-exact16')
    assert record['accepted'] and record['packet']['diagnostics']['inputBytes']==16*1024*1024
    results.append(record)
    for mode in ('wrong-body', 'private', 'nonphoto', 'count51', 'unsafe-url', 'bad-dimensions',
                 'tls-after-challenge', 'body-timeout', 'metadata-over8'):
        record, f = run_child('analyze', mode)
        assert not record['accepted'] and record['actualExit'] == 20
        assert record['packet']['sessions'][0]['imageGET'] == 0
        results.append(record)
    for mode in ('dimension-change', 'count-change'):
        record, f = run_child('prepare', mode, selected)
        assert not record['accepted'] and record['packet']['error'] == 'PHOTO_SNAPSHOT'
        assert record['packet']['sessions'][0]['imageGET'] == 0
        results.append(record)
    for bad in ('ttp1_00_' + public['summary']['snapshotKey'], 'ttp1_03_' + public['summary']['snapshotKey'],
                'ttp1_01_' + '0'*64, selected + 'x'):
        record, f = run_child('prepare', 'normal', bad)
        assert not record['accepted'] and record['packet']['sessions'][0]['imageGET'] == 0
        results.append(dict(case='invalid-selection', **{k:v for k,v in record.items() if k!='case'}))
    for mode in ('false-jpeg', 'truncated', 'wrong-media-dimensions', 'wrong-mime', 'redirect', 'http403',
                 'cancel', 'cancel-after-part', 'decode-fail', 'decode-kill', 'close-error'):
        record, f = run_child('prepare', mode, selected)
        assert not record['accepted'] and not (f/'image.jpg').exists()
        assert not any(record['packet']['filesAfterCall'].values())
        if mode in ('decode-fail', 'decode-kill'):
            events=[json.loads(x) for x in (f/'tiktok-operations.jsonl').read_text().splitlines()]
            assert any(e['operation']=='DECODE' and e['event']=='ERROR' and
                       e['returncode']==(20 if mode=='decode-fail' else -9) for e in events)
            record['decodeEvents']=events
        results.append(record)
    large, f = run_child('prepare', 'large-jpeg', selected)
    assert large['accepted'] and large['packet']['result']['size'] > 8*1024*1024
    assert large['packet']['diagnostics']['finalResponseCap'] == 20*1024*1024
    results.append(large)
    for limits, mode in ((PhotoLimits(output_bytes=100), 'normal'),
                         (PhotoLimits(input_bytes=1024), 'normal'),
                         (PhotoLimits(input_bytes=1024*1024), 'aggregate'),
                         (PhotoLimits(prepare_seconds=10), 'normal')):
        record, f = run_child('prepare', mode, selected, limits=limits)
        assert not record['accepted'] and not (f/'image.jpg').exists()
        results.append(dict(case='strict-cap-or-deadline', limits=dataclasses.asdict(limits), record=record))
    for name in ('image.jpg', 'image.jpg.part'):
        f = job(); (f/name).write_bytes(b'PREEXISTING')
        # Call directly: failed worker parent must not delete a preexisting output.
        _, error, _, stats = invoke('prepare', 'normal', f, selected)
        assert error == 'PREEXISTING_OUTPUT' and (f/name).read_bytes() == b'PREEXISTING' and not stats
        results.append(dict(case='preexisting-preserved', name=name))
    f = job(); (f/'image.jpg').symlink_to(f/'sentinel')
    _, error, _, _ = invoke('prepare', 'normal', f, selected)
    assert error == 'INVALID_ASSET_PATH' and (f/'sentinel').read_bytes() == b'PRESERVE'
    results.append(dict(case='output-symlink-preserved'))
    f = job()
    _, error, _, _ = invoke('prepare', 'collision', f, selected)
    assert error == 'OUTPUT_COLLISION' and (f/'image.jpg').read_bytes() == b'OTHER_OWNER'
    assert not (f/'image.jpg.part').exists()
    results.append(dict(case='atomic-publish-no-overwrite'))
    for phase in ('analyze', 'prepare'):
        for mode in ('pass-exit20', 'pass-hang'):
            record, f = run_child(phase, mode, selected, cap=3)
            assert not record['accepted'] and record['packet']['error'] is None
            assert record['actualExit'] == (20 if mode == 'pass-exit20' else -9)
            assert not (f/'image.jpg').exists()
            results.append(record)
    record, f = run_child('analyze', 'blocked', cap=0.8, limits=PhotoLimits(metadata_seconds=0.8))
    assert record['actualExit'] == -9 and record['killed'] and not record['accepted']
    assert (f/'blocked-entered.json').exists()
    results.append(dict(case='independent-OS-parent-deadline', record=record))
    # Pure contracts: strict types, keys, ordered rows, 50th choice, structural limitation.
    meta = public['summary']
    for mutate in (lambda m: m.update(extra=True), lambda m: m.update(imageCount=True),
                   lambda m: m['images'][0].update(index=True),
                   lambda m: m['images'][0].update(itemKey='0'*64)):
        broken = json.loads(json.dumps(meta)); mutate(broken)
        try:
            validate_summary(broken, EXPECTED); raise AssertionError('Bad summary accepted')
        except PhotoError:
            pass
    b = PhotoBudget(PhotoLimits(), 'prepare')
    b.total = b.network_total = 16*1024*1024
    b.begin_image()
    assert b.network_total == 16*1024*1024 and b.response_cap == 20*1024*1024
    b.requests = 1
    try:
        b.sent(); raise AssertionError('Second image allowed')
    except Exception:
        assert b.failure == 'REQUEST_LIMIT'
    results.append(dict(case='strict-summary-and-aggregate-counter-and-request-limit'))
    # Fixed native failure/kill at the decoder boundary, after real JPEG probes.
    from tiktok.photo_file import inspect_jpeg
    class FailingDecode(Operations):
        def native(self, operation, argv, cap, **kw):
            if operation == 'DECODE':
                return super().native(operation, ['python3', '-c', 'raise SystemExit(20)'], cap, **kw)
            return super().native(operation, argv, cap, **kw)
    f = job(); ops = FailingDecode(time.monotonic()+30, root=f)
    try:
        inspect_jpeg(JPEG, 'image/jpeg', ops, dict(width=64,height=64), lambda:None)
        raise AssertionError('Decode exit accepted')
    except RuntimeError as e:
        assert e.args == ('DECODE_FAIL',)
    assert any(row['operation']=='DECODE' and row['returncode']==20 for row in ops.terminals)
    results.append(dict(case='native-decode-failure-injection', actualReturncode=20, realFfmpegFailure=False))
    output = dict(status='PASS_OFFLINE_PHOTO_CORE_NOT_WIRED', sourceCalls=0, fixtureOnly=True,
                  results=results, tests=len(results))
    (OUT/'results.json').write_text(json.dumps(output, indent=2))
    print('PASS offline photo core:', len(results), 'checks; no source calls')
    return 0


if __name__ == '__main__':
    try:
        code=child() if len(sys.argv)>1 and sys.argv[1]=='child' else suite()
    except Exception as error:
        import traceback
        frames=traceback.extract_tb(error.__traceback__)
        frame=frames[-1]
        name=pathlib.Path(frame.filename).name
        safeFiles={'check.py','fixtures.py','photo_core.py','photo_contract.py','photo_file.py','gate.py'}
        safeClasses={'AssertionError','TypeError','KeyError','ValueError','OSError','FileNotFoundError'}
        print(json.dumps(dict(errorClass=type(error).__name__ if type(error).__name__ in safeClasses else 'UNKNOWN',
                              file=name if name in safeFiles else 'UNKNOWN',line=frame.lineno)),file=sys.stderr)
        code=21
    sys.exit(code)
