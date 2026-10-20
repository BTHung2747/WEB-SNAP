"""Version3 album mock contract; no authority issuer or source capability."""
import datetime,hashlib,pathlib,re
from album_contract import require,validate_summary,selection,canonical
from dns_admission import strict_loads
TARGET='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';ID='7678209751167110421'
OLD_TASKS={'903b9cae739f46829b8973f4d94df389','2713473edcf94a139dd91d1d82939d0a','cf3808fc328743369a848f3bb5a5495e'}
OLD_ALLOCS={'827c77f493ea4c8fa112f031e1b7b2bc','a0c19e584c614c9badfa47bbc46b35b2','b8f3a0d86c51490383c87fc925c876da'}
def rows_hash(rows):return hashlib.sha256(''.join(r['path']+'\0'+r['sha256']+'\n' for r in sorted(rows,key=lambda x:x['path'])).encode()).hexdigest()
def quota(n=5):
    return dict(analyze=1,metadataGET=2,imageGET=n,metadataMaxCount=50,selectedMax=5,metadataSeconds=30,prepareSeconds=180,itemSeconds=60,itemReserveSeconds=10,metadataResponseBytes=8388608,metadataTotalBytes=16777216,imageInputBytes=20971520,imageOutputBytes=16777216,workflowInputBytes=(16+20*n)*1048576,workflowOutputBytes=16*n*1048576,redirect=0,retry=0,HEAD=0,setupSeconds=10,connectSeconds=10,readSeconds=20,runtimeMiB=608,helperLimit=1,answerCap=64,rawCap=256,dnsProtocol=4,groupCap=4,socketCap=2,prefixCap=8,traceCap=256,ownerCap=32,mapCap=64,watchdogSeconds=225)
def bounded(path,cap):
    require(not path.is_symlink(),'ALBUM_AUTHORITY_LINK')
    with path.open('rb') as f:data=f.read(cap+1)
    require(len(data)<=cap,'ALBUM_AUTHORITY_CAP');return data
def validate(a,root=pathlib.Path('/authority')):
    keys={'version','scope','taskID','allocationID','target','expectedID','type','selection','validatedN','sourceHash','runtimeHash','gateSHA','claimSHA','taskClaimSHA','expiresUTC','quota'}
    require(type(a) is dict and set(a)==keys and type(a['version']) is int and a['version']==3 and a['scope']=='OFFLINE_ALBUM_ALLOCATION_FIXTURE_V1','ALBUM_ADMISSION_SCHEMA')
    require(all(type(a[k]) is str for k in ('scope','taskID','allocationID','target','expectedID','type','sourceHash','runtimeHash','gateSHA','claimSHA','taskClaimSHA','expiresUTC')),'ALBUM_ADMISSION_STRING')
    require(a['taskID'] not in OLD_TASKS and a['allocationID'] not in OLD_ALLOCS,'OLD_ONE_PHOTO_CONSUMED')
    for k,size in [('taskID',32),('allocationID',32),('sourceHash',64),('runtimeHash',64),('gateSHA',64),('claimSHA',64),('taskClaimSHA',64)]:require(re.fullmatch('[a-f0-9]{'+str(size)+'}',a[k]) is not None,'ALBUM_ADMISSION_HASH')
    require(a['target']==TARGET and a['expectedID']==ID and a['type']=='photo' and type(a['validatedN']) is int and a['validatedN']==5,'ALBUM_ADMISSION_TARGET')
    s=a['selection'];require(type(s) is dict and set(s)=={'version','mode','indices','expectedCount','snapshotSchema','snapshotKey'},'ALBUM_ADMISSION_SELECTION')
    require(type(s['version']) is int and s['version']==1 and s['mode']=='all' and type(s['expectedCount']) is int and s['expectedCount']==5 and s['snapshotSchema']=='tt-photo-album-v1','ALBUM_ADMISSION_SELECTION')
    require(type(s['indices']) is list and len(s['indices'])==5 and all(type(v) is int and v==i for i,v in enumerate(s['indices'],1)) and type(s['snapshotKey']) is str and re.fullmatch('[a-f0-9]{64}',s['snapshotKey']) is not None,'ALBUM_ADMISSION_SELECTION')
    require(type(a['quota']) is dict and set(a['quota'])==set(quota()) and all(type(a['quota'][k]) is int and a['quota'][k]==v for k,v in quota().items()),'ALBUM_ADMISSION_QUOTA')
    try:
        now=datetime.datetime.now(datetime.timezone.utc);end=datetime.datetime.fromisoformat(a['expiresUTC']);require(a['expiresUTC'].endswith('Z') and now<end<=now+datetime.timedelta(seconds=600),'ALBUM_ADMISSION_EXPIRED')
    except (TypeError,ValueError):raise RuntimeError('ALBUM_ADMISSION_EXPIRED') from None
    from common import inventory
    require(rows_hash(inventory())==a['runtimeHash'],'ALBUM_ADMISSION_RUNTIME')
    raw=bounded(root/'gate.json',2*1048576);require(hashlib.sha256(raw).hexdigest()==a['gateSHA'],'ALBUM_ADMISSION_GATE')
    g=strict_loads(raw);require(g['scope']=='OFFLINE_ALBUM_PREPARATION_FIXTURE_V1' and g['sourceGate'] is False and g['sourceHash']==a['sourceHash'] and g['runtimeHash']==a['runtimeHash'],'ALBUM_ADMISSION_GATE')
    for name,key in [('claim-mock.json','claimSHA'),('task-latch-mock.json','taskClaimSHA')]:
        raw=bounded(root/name,4096);require(hashlib.sha256(raw).hexdigest()==a[key],'ALBUM_ADMISSION_CLAIM')
        row=strict_loads(raw);expected=dict(version=3,scope=a['scope'],status='CONSUMED_BEFORE_NETWORK_CAPABILITY',taskID=a['taskID'],allocationID=a['allocationID'],target=a['target'],selection=s,validatedN=5,gateSHA=a['gateSHA'],sourceHash=a['sourceHash'],runtimeHash=a['runtimeHash'],expiresUTC=a['expiresUTC'],quota=a['quota'])
        require(type(row) is dict and set(row)==set(expected)|{'utc'} and type(row['utc']) is str and canonical({k:v for k,v in row.items() if k!='utc'})==canonical(expected),'ALBUM_ADMISSION_CLAIM')
    return True
def check_metadata(settings,meta):
    a=settings['admission']
    if settings['stage']=='offline':validate(a)
    else:
        from live_admission import validate as validate_live
        validate_live(a,harness=settings['stage']=='cold')
    validate_summary(meta,ID)
    require(meta['imageCount']==a['selection']['expectedCount'] and meta['snapshotKey']==a['selection']['snapshotKey'],'ALBUM_SOURCE_SNAPSHOT_CHANGED')
    return True
