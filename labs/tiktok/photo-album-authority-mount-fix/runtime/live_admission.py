"""Source-only version4 album binding; strict readers, no issuer/HTTP implementation."""
import datetime,hashlib,pathlib
from album_admission import quota,rows_hash,TARGET,ID,OLD_TASKS,OLD_ALLOCS
from album_contract import require,canonical
from evidence_contract import load,equal
def exact(row,keys):require(type(row) is dict and set(row)==set(keys.split()),'LIVE_SCHEMA')
def expiry(issued,end):
    require(type(issued) is str and type(end) is str and issued.endswith('Z') and end.endswith('Z'),'LIVE_EXPIRY')
    try:
        a=datetime.datetime.fromisoformat(issued);b=datetime.datetime.fromisoformat(end);now=datetime.datetime.now(datetime.timezone.utc)
        require(a<=now<b and b-a<=datetime.timedelta(seconds=600),'LIVE_EXPIRY')
    except (TypeError,ValueError):raise RuntimeError('LIVE_EXPIRY') from None
def rawsha(p):
    require(not p.is_symlink(),'LIVE_LINK')
    with p.open('rb') as f:data=f.read(2*1048576+1)
    require(len(data)<=2*1048576,'LIVE_CAP')
    return hashlib.sha256(data).hexdigest()

def inventory_equal(rows,observed):
    # Inventory is a set of exact path/hash rows. PowerShell culture sorting and
    # Python ordinal sorting differ; normalize only ordering, never row values.
    require(type(rows) is list and all(type(r) is dict and set(r)=={'path','sha256'} and type(r['path']) is str and type(r['sha256']) is str for r in rows),'LIVE_PREPARATION')
    return equal(sorted(rows,key=lambda r:r['path']),observed)

def cold_guard_collections(h):
    require(type(h) is dict and {'CapDrop','SecurityOpt','CapAdd','ExtraHosts'}<=set(h),'LIVE_COLD_GUARD_COLLECTION_SCHEMA')
    # Same measured profile as the host reader, with no coercion/substrings.
    for key,expected in (('CapDrop',['ALL']),('SecurityOpt',['no-new-privileges:true'])):
        value=h[key]
        require(type(value) is list and len(value)==len(expected) and all(type(v) is str and v==e for v,e in zip(value,expected)),'LIVE_COLD_GUARD_COLLECTION_SCHEMA')
    for key in ('CapAdd','ExtraHosts'):
        value=h[key]
        require(value is None or type(value) is list and len(value)==0,'LIVE_COLD_GUARD_COLLECTION_SCHEMA')
def bundle(root,harness=False):
    root=pathlib.Path(root);r=load(root/'release.json',2*1048576)
    exact(r,'version scope status sourceGate preparationSHA reviewSHA freshColdSHA sourceHash runtimeHash target expectedID type selection validatedN quota image trustSHA taskID allocationID utc expiresUTC')
    require(type(r['version']) is int and r['version']==4 and type(r['validatedN']) is int and r['validatedN']==5,'LIVE_SCHEMA')
    require(r['scope']==('OFFLINE_LIVE_CONTRACT_HARNESS_V1' if harness else 'ALBUM_SOURCE_RELEASE_V1') and r['status']==('FIXTURE_RELEASE_ONLY' if harness else 'REVIEWED_BOUND_RELEASE') and r['sourceGate'] is (False if harness else True),'LIVE_SCOPE')
    # Reuse base target/selection/quota logic via equivalent strict checks only;
    # mock claim/gate validation remains exclusive to its own version3 scope.
    import re
    for k,size in [('taskID',32),('allocationID',32),('sourceHash',64),('runtimeHash',64),('preparationSHA',64),('reviewSHA',64),('freshColdSHA',64),('trustSHA',64)]:require(type(r[k]) is str and re.fullmatch('[a-f0-9]{'+str(size)+'}',r[k]) is not None,'LIVE_HASH')
    require(r['taskID'] not in OLD_TASKS and r['allocationID'] not in OLD_ALLOCS,'OLD_ONE_PHOTO_CONSUMED')
    s=r['selection'];exact(s,'version mode indices expectedCount snapshotSchema snapshotKey')
    require(type(s['version']) is int and s['version']==1 and type(s['expectedCount']) is int and s['expectedCount']==5 and s['mode']=='all' and s['snapshotSchema']=='tt-photo-album-v1' and type(s['indices']) is list and len(s['indices'])==5 and all(type(v) is int and v==i for i,v in enumerate(s['indices'],1)) and type(s['snapshotKey']) is str and re.fullmatch('[a-f0-9]{64}',s['snapshotKey']) is not None,'LIVE_SELECTION')
    require(equal(r['quota'],quota()) and r['target']==TARGET and r['expectedID']==ID and r['type']=='photo','LIVE_QUOTA')
    from common import inventory,trust_hash
    require(r['image']=='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' and r['trustSHA']==trust_hash()=='9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f' and r['runtimeHash']==rows_hash(inventory()),'LIVE_RUNTIME_TRUST')
    expiry(r['utc'],r['expiresUTC'])
    prep=load(root/'preparation.json',2*1048576);exact(prep,'version scope sourceGate sources runtime sourceHash runtimeHash image trustSHA selection quota')
    require(type(prep['version']) is int and prep['version']==4 and prep['scope']=='ALBUM_BRIDGE_OFFLINE_PREPARATION_V1' and prep['sourceGate'] is False and r['preparationSHA']==rawsha(root/'preparation.json') and r['sourceHash']==rows_hash(prep['sources']) and r['runtimeHash']==rows_hash(prep['runtime']) and inventory_equal(prep['runtime'],inventory()),'LIVE_PREPARATION')
    for k in ('sourceHash','runtimeHash','image','trustSHA','selection','quota'):require(equal(prep[k],r[k]),'LIVE_PREPARATION')
    review=load(root/'review.json');exact(review,'version scope status sourceGate sourceCalls actualExit preparationSHA sourceHash runtimeHash selection quota utc')
    require(type(review['version']) is int and review['version']==4 and review['scope']==('OFFLINE_REVIEW_FIXTURE_ONLY' if harness else 'ALBUM_BRIDGE_INDEPENDENT_REVIEW_V1') and review['status']==('FIXTURE_REVIEW_ONLY' if harness else 'PASS_INDEPENDENT_ALBUM_BRIDGE_REVIEW') and review['sourceGate'] is False and type(review['sourceCalls']) is int and review['sourceCalls']==0 and type(review['actualExit']) is int and review['actualExit']==0 and r['reviewSHA']==rawsha(root/'review.json'),'LIVE_REVIEW')
    for k in ('preparationSHA','sourceHash','runtimeHash','selection','quota'):require(equal(review[k],r[k]),'LIVE_REVIEW')
    cold=load(root/'cold.json',2*1048576);exact(cold,'version scope status sourceCalls actualExit sources versions python trustSHA fixtureModules network sourceMainInvoked utc guardSHA completionSHA')
    require(type(cold['guardSHA']) is str and cold['guardSHA']==rawsha(root/'cold-guard.json') and type(cold['completionSHA']) is str and cold['completionSHA']==rawsha(root/'cold-completion.json'),'LIVE_COLD_PROOF_LINK')
    require(type(cold['version']) is int and cold['version']==4 and cold['scope']==('OFFLINE_COLD_FIXTURE_ONLY' if harness else 'ALBUM_SOURCE_COLD_ATTESTATION_V1') and cold['status']==('FIXTURE_COLD_ONLY' if harness else 'PASS_SOURCE_ONLY_COLD_NETWORK_NONE') and type(cold['sourceCalls']) is int and cold['sourceCalls']==0 and type(cold['actualExit']) is int and cold['actualExit']==0 and cold['network']=='none' and cold['sourceMainInvoked'] is False and type(cold['fixtureModules']) is list and not cold['fixtureModules'] and inventory_equal(cold['sources'],inventory()) and cold['trustSHA']==r['trustSHA'] and r['freshColdSHA']==rawsha(root/'cold.json'),'LIVE_COLD')
    from common import versions
    require(cold['python']=='3.11.2' and equal(cold['versions'],versions()),'LIVE_COLD');expiry(cold['utc'],r['expiresUTC'])
    guard=load(root/'cold-guard.json');completion=load(root/'cold-completion.json');h=guard['HostConfig']
    cold_guard_collections(h)
    require(guard['Image']==r['image'] and guard['Config']['User']=='65534:65534' and h['NetworkMode']=='none' and not h.get('ExtraHosts') and type(h['Memory']) is int and h['Memory']==96*1048576 and type(h['MemorySwap']) is int and h['MemorySwap']==96*1048576 and type(h['NanoCpus']) is int and h['NanoCpus']==250000000 and h['ReadonlyRootfs'] is True and h['Privileged'] is False and not h.get('CapAdd') and 'ALL' in h['CapDrop'] and 'no-new-privileges:true' in h['SecurityOpt'] and h['IpcMode']=='private' and type(h['PidsLimit']) is int and h['PidsLimit']==64,'LIVE_COLD_GUARD')
    require(all(type(completion.get(k)) is int and completion[k]==0 for k in ('actualExit','sourceCalls','ownResourcesLeft')),'LIVE_COLD_NATIVE')
    if not harness:
        from bootstrap_contract import proof
        proof(root,r['preparationSHA'],r['reviewSHA'])
    auth=load(root/'authorization.json');exact(auth,'version scope status releaseSHA reviewSHA taskID allocationID target selection quota utc expiresUTC')
    require(type(auth['version']) is int and auth['version']==4 and auth['scope']==('OFFLINE_HUMAN_TASK_FIXTURE_ONLY' if harness else 'ALBUM_SOURCE_HUMAN_TASK_V1') and auth['status']==('FIXTURE_TASK_ONLY' if harness else 'HUMAN_AUTHORIZED') and auth['releaseSHA']==rawsha(root/'release.json'),'LIVE_HUMAN_TASK')
    for k in ('reviewSHA','taskID','allocationID','target','selection','quota','expiresUTC'):require(equal(auth[k],r[k]),'LIVE_HUMAN_TASK')
    expiry(auth['utc'],auth['expiresUTC'])
    allocation=load(root/'allocation.json');exact(allocation,'version scope releaseSHA authorizationSHA taskID allocationID target expectedID type selection validatedN quota utc expiresUTC')
    require(type(allocation['version']) is int and allocation['version']==4 and allocation['scope']==('OFFLINE_ALLOCATION_BRIDGE_FIXTURE_ONLY' if harness else 'ALBUM_SOURCE_ALLOCATION_V1') and allocation['releaseSHA']==rawsha(root/'release.json') and allocation['authorizationSHA']==rawsha(root/'authorization.json'),'LIVE_ALLOCATION')
    for k in ('taskID','allocationID','target','expectedID','type','selection','validatedN','quota','expiresUTC'):require(equal(allocation[k],r[k]),'LIVE_ALLOCATION')
    expiry(allocation['utc'],allocation['expiresUTC']);return r
def validate(a,harness=False,root=pathlib.Path('/authority')):
    exact(a,'version scope taskID allocationID target expectedID type selection validatedN sourceHash runtimeHash gateSHA claimSHA taskClaimSHA expiresUTC quota authorizationSHA')
    require(type(a['version']) is int and a['version']==4 and a['scope']==('OFFLINE_LIVE_CLAIM_FIXTURE_ONLY' if harness else 'ALBUM_SOURCE_ALLOCATION_V1'),'LIVE_ADMISSION_SCOPE')
    r=bundle(root,harness)
    for k in ('taskID','allocationID','target','expectedID','type','selection','validatedN','sourceHash','runtimeHash','expiresUTC','quota'):require(equal(a[k],r[k]),'LIVE_ADMISSION_BINDING')
    require(type(a['gateSHA']) is str and a['gateSHA']==rawsha(root/'release.json') and type(a['authorizationSHA']) is str and a['authorizationSHA']==rawsha(root/'authorization.json'),'LIVE_ADMISSION_BINDING')
    for name,key in [('source-claim.json','claimSHA'),('task-latch.json','taskClaimSHA')]:
        claim=load(root/name,4096);require(type(a[key]) is str and a[key]==rawsha(root/name),'LIVE_CLAIM_HASH')
        expected=dict(version=4,scope=a['scope'],status='CONSUMED_BEFORE_NETWORK_CAPABILITY',releaseSHA=a['gateSHA'],authorizationSHA=a['authorizationSHA'],taskID=a['taskID'],allocationID=a['allocationID'],target=a['target'],selection=a['selection'],validatedN=5,quota=a['quota'],sourceHash=a['sourceHash'],runtimeHash=a['runtimeHash'],expiresUTC=a['expiresUTC'],gateSHA=a['gateSHA'])
        require(type(claim) is dict and set(claim)==set(expected)|{'utc'} and type(claim['utc']) is str and equal({k:v for k,v in claim.items() if k!='utc'},expected),'LIVE_CLAIM_FIELDS')
    return True
