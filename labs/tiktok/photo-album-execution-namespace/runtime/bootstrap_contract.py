"""AGPL-3.0 bootstrap proof glue. No HTTP/parser or source grant issuer."""
import pathlib
from album_contract import require
from album_admission import rows_hash, quota
from evidence_contract import load, equal
from live_admission import exact, expiry, rawsha, inventory_equal, cold_guard_collections

REAL='ALBUM_COLD_BOOTSTRAP_V1'
SELF='OFFLINE_BOOTSTRAP_SELF_TEST_V1'

def binding(control, root=pathlib.Path('/authority')):
    exact(control,'stage sourceGate coldOnly bootstrap')
    require(control['stage']=='bootstrap' and control['sourceGate'] is False and control['coldOnly'] is True,'BOOTSTRAP_CONTROL')
    a=control['bootstrap']
    exact(a,'version scope preparationSHA reviewSHA sourceHash runtimeHash image trustSHA selection quota utc expiresUTC')
    require(type(a['version']) is int and a['version']==1 and a['scope'] in (REAL,SELF),'BOOTSTRAP_SCOPE')
    expiry(a['utc'],a['expiresUTC'])
    p=load(root/'preparation.json',2*1048576)
    exact(p,'version scope sourceGate sources runtime sourceHash runtimeHash image trustSHA selection quota')
    require(type(p['version']) is int and p['version']==4 and p['scope']=='ALBUM_BRIDGE_OFFLINE_PREPARATION_V1' and p['sourceGate'] is False,'BOOTSTRAP_PREPARATION')
    from common import inventory, trust_hash
    require(a['preparationSHA']==rawsha(root/'preparation.json') and p['sourceHash']==rows_hash(p['sources']) and p['runtimeHash']==rows_hash(p['runtime']) and inventory_equal(p['runtime'],inventory()),'BOOTSTRAP_HASH')
    for k in ('sourceHash','runtimeHash','image','trustSHA','selection','quota'):
        require(equal(a[k],p[k]),'BOOTSTRAP_BINDING')
    require(a['image']=='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' and a['trustSHA']==trust_hash()=='9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f' and equal(a['quota'],quota()),'BOOTSTRAP_PINS')
    s=a['selection'];exact(s,'version mode indices expectedCount snapshotSchema snapshotKey')
    import re
    require(type(s['version']) is int and s['version']==1 and s['mode']=='all' and type(s['expectedCount']) is int and s['expectedCount']==5 and s['snapshotSchema']=='tt-photo-album-v1' and type(s['indices']) is list and len(s['indices'])==5 and all(type(v) is int and v==i for i,v in enumerate(s['indices'],1)) and type(s['snapshotKey']) is str and re.fullmatch('[a-f0-9]{64}',s['snapshotKey']) is not None,'BOOTSTRAP_SELECTION')
    r=load(root/'review.json');exact(r,'version scope status sourceGate sourceCalls actualExit preparationSHA sourceHash runtimeHash selection quota utc')
    real=a['scope']==REAL
    require(type(r['version']) is int and r['version']==4 and r['scope']==('ALBUM_BRIDGE_INDEPENDENT_REVIEW_V1' if real else 'OFFLINE_REVIEW_FIXTURE_ONLY') and r['status']==('PASS_INDEPENDENT_ALBUM_BRIDGE_REVIEW' if real else 'FIXTURE_REVIEW_ONLY') and r['sourceGate'] is False and type(r['sourceCalls']) is int and r['sourceCalls']==0 and type(r['actualExit']) is int and r['actualExit']==0 and a['reviewSHA']==rawsha(root/'review.json'),'BOOTSTRAP_REVIEW')
    for k in ('preparationSHA','sourceHash','runtimeHash','selection','quota'):
        require(equal(r[k],a[k]),'BOOTSTRAP_REVIEW_BINDING')
    return a

def proof(root, preparation, review):
    """Extra real-source check; existing cold/human/claims remain mandatory."""
    root=pathlib.Path(root)
    c=load(root/'cold-completion.json');control=load(root/'bootstrap-control.json')
    a=binding(control,root)
    require(a['scope']==REAL and a['preparationSHA']==preparation and a['reviewSHA']==review,'BOOTSTRAP_NOT_SOURCE_PROOF')
    exact(c,'actualExit sourceCalls ownResourcesLeft producerScope controlSHA reportSHA stateSHA mountsSHA nativeSHA utc')
    require(c['producerScope']==REAL and c['controlSHA']==rawsha(root/'bootstrap-control.json') and c['reportSHA']==rawsha(root/'cold-report.json') and c['stateSHA']==rawsha(root/'cold-state.json') and c['mountsSHA']==rawsha(root/'cold-mounts.json') and c['nativeSHA']==rawsha(root/'cold-native.json'),'BOOTSTRAP_PROOF_LINK')
    native=load(root/'cold-native.json');require(type(native['actualExit']) is int and native['actualExit']==0 and native['step']=='start','BOOTSTRAP_NATIVE')
    report=load(root/'cold-report.json',2*1048576);state=load(root/'cold-state.json');g=load(root/'cold-guard.json');mounts=load(root/'cold-mounts.json')
    require(report['scope']==REAL and report['controlSHA']==c['controlSHA'] and report['uid']==65534 and type(report['threadsBefore']) is int and report['threadsBefore']==1 and type(report['threadsAfter']) is int and report['threadsAfter']==1 and type(report['fdDelta']) is int and report['fdDelta']==0 and report['sourceMainInvoked'] is False and report['fixtureModules']==[] and all(type(report[k]) is int and report[k]==0 for k in ('sourceCalls','dnsCalls','httpCalls','networkCalls')),'BOOTSTRAP_REPORT')
    from common import inventory,trust_hash,versions
    require(type(report['uid']) is int and type(report['fixtureModules']) is list and report['python']=='3.11.2' and equal(report['versions'],versions()) and report['trustSHA']==trust_hash() and inventory_equal(report['sources'],inventory()),'BOOTSTRAP_REPORT')
    require(state['Running'] is False and state['OOMKilled'] is False and type(state['ExitCode']) is int and state['ExitCode']==0,'BOOTSTRAP_STATE')
    import datetime
    elapsed=(datetime.datetime.fromisoformat(state['FinishedAt'].replace('Z','+00:00'))-datetime.datetime.fromisoformat(state['StartedAt'].replace('Z','+00:00'))).total_seconds()
    require(0<=elapsed<=30,'BOOTSTRAP_DEADLINE')
    require(equal(mounts,g['Mounts']),'BOOTSTRAP_MOUNTS')
    expected={'/integration','/poc','/vendor','/trace_lab','/stock','/app/apps/media/src/tiktok/source_photo','/authority','/control','/out'}
    require(type(mounts) is list and len(mounts)==len(expected) and {m['Destination'] for m in mounts}==expected and all(m['Type']=='bind' and m['RW'] is (m['Destination']=='/out') for m in mounts),'BOOTSTRAP_MOUNTS')
    require(g['Config']['Cmd']==['/usr/bin/timeout','--signal=KILL','30s','python3','/integration/bootstrap_probe.py'] and not g['HostConfig']['PortBindings'],'BOOTSTRAP_COMMAND')
    cold_guard_collections(g['HostConfig'])
    return True
