"""AGPL-3.0 child-side admission binding; no HTTP/TLS/resolver implementation."""
import datetime,hashlib,json,pathlib,re
from dns_admission import integer,strict_loads
TARGET='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421'
OLD_TASKS={'903b9cae739f46829b8973f4d94df389','2713473edcf94a139dd91d1d82939d0a'}
OLD_ALLOCS={'827c77f493ea4c8fa112f031e1b7b2bc','a0c19e584c614c9badfa47bbc46b35b2'}
QUOTA=dict(analyze=1,metadataGET=2,imageGET=1,selectedIndex=1,metadataSeconds=30,prepareSeconds=60,metadataResponseBytes=8388608,metadataTotalBytes=16777216,imageInputBytes=20971520,imageOutputBytes=16777216,workflowBytes=37748736,redirect=0,retry=0,HEAD=0,setupSeconds=10,reserveSeconds=1,connectSeconds=10,readSeconds=20,runtimeMiB=608,helperLimit=1,answerCap=64,rawCap=256,dnsProtocol=4,groupCap=4,socketCap=2,prefixCap=8,traceCap=256,ownerCap=32,mapCap=64)
def rows_hash(rows):
    return hashlib.sha256(''.join(r['path']+'\0'+r['sha256']+'\n' for r in sorted(rows,key=lambda x:x['path'])).encode()).hexdigest()
def validate_admission(a):
    keys={'version','scope','taskID','allocationID','target','selectedIndex','dnsProtocol','sourceHash','runtimeHash','gateSHA','claimSHA','taskClaimSHA','expiresUTC','quota'}
    if type(a) is not dict or set(a)!=keys or not integer(a['version'],2,2) or not integer(a['dnsProtocol'],4,4) or not integer(a['selectedIndex'],1,1) or a['scope']!='ONE_PHOTO_SOURCE_ALLOCATION_V4' or a['target']!=TARGET:raise RuntimeError('SOURCE_ADMISSION_SCHEMA')
    for key,size in [('taskID',32),('allocationID',32),('sourceHash',64),('runtimeHash',64),('gateSHA',64),('claimSHA',64),('taskClaimSHA',64)]:
        if type(a[key]) is not str or not re.fullmatch('[a-f0-9]{'+str(size)+'}',a[key]):raise RuntimeError('SOURCE_ADMISSION_ID_HASH')
    if a['taskID'] in OLD_TASKS or a['allocationID'] in OLD_ALLOCS:raise RuntimeError('SOURCE_OLD_CONSUMED_ID')
    if type(a['quota']) is not dict or set(a['quota'])!=set(QUOTA) or any(type(a['quota'][k]) is not int or a['quota'][k]!=v for k,v in QUOTA.items()):raise RuntimeError('SOURCE_ADMISSION_QUOTA')
    try:
        if type(a['expiresUTC']) is not str or not a['expiresUTC'].endswith('Z'):raise ValueError()
        expiry=datetime.datetime.fromisoformat(a['expiresUTC']);now=datetime.datetime.now(datetime.timezone.utc)
        if not now<expiry<=now+datetime.timedelta(seconds=600):raise ValueError()
    except (ValueError,TypeError):raise RuntimeError('SOURCE_ADMISSION_EXPIRED') from None
    from common import inventory
    if rows_hash(inventory())!=a['runtimeHash']:raise RuntimeError('SOURCE_ADMISSION_RUNTIME_HASH')
    for filename,key in [('source-claim.json','claimSHA'),('task-latch.json','taskClaimSHA')]:
        p=pathlib.Path('/authority')/filename
        if p.is_symlink():raise RuntimeError('SOURCE_ADMISSION_CLAIM_LINK')
        with p.open('rb') as f:data=f.read(4097)
        if len(data)>4096 or hashlib.sha256(data).hexdigest()!=a[key]:raise RuntimeError('SOURCE_ADMISSION_CLAIM_HASH')
        row=strict_loads(data)
        expected={'version':2,'scope':a['scope'],'status':'CONSUMED_BEFORE_NETWORK_CAPABILITY','taskID':a['taskID'],'allocationID':a['allocationID'],'target':a['target'],'selectedIndex':1,'dnsProtocol':4,'gateSHA':a['gateSHA'],'sourceHash':a['sourceHash'],'runtimeHash':a['runtimeHash'],'expiresUTC':a['expiresUTC']}
        if type(row) is not dict or set(row)!=set(expected)|{'utc'} or any(type(row.get(k)) is not type(v) or row[k]!=v for k,v in expected.items()):raise RuntimeError('SOURCE_ADMISSION_CLAIM_FIELDS')
    return True
