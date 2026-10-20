"""AGPL-3.0 owned evidence glue; libraries/Operations remain HTTP/native owners."""
import hashlib,json,math,os,pathlib,re,stat
from album_contract import require,canonical,MIB
from accounting import receipt,read_owned_observer,rid_valid
from dns_admission import strict_loads
from tiktok.send_diagnostics import CLASSES
from tiktok.prepare_operations import OPS
OBSERVER_CAP=128*1024
EVENT_KEYS={'requestID','connectionID','phase','boundary','event','elapsed','timeout','code','classes'}
CLASS_NAMES={v[0] for v in CLASSES.values()};CODES={v[1] for v in CLASSES.values()}|{'UNKNOWN','BEGIN','OK'}
REASON_CODES={'EVIDENCE_PATH','EVIDENCE_CAP','OBSERVER_SCHEMA','OBSERVER_LINK','OBSERVER_INCOMPLETE','OBSERVER_PERMISSIONS','ACCOUNTING_PACKET','ACCOUNTING_PACKET_DUPLICATE','ACCOUNTING_BYTES','ACCOUNTING_REVALIDATION','ACCOUNTING_REPORT_CONFLICT','ACCOUNTING_QUOTA','OPERATIONS_SCHEMA','OPERATIONS_SCOPE','OPERATIONS_DEADLINE','OPERATIONS_TIMING','OPERATIONS_TIMEOUT','OPERATIONS_NATIVE_TYPE','OPERATIONS_BEGIN','OPERATIONS_ORDER','OPERATIONS_TERMINAL','OPERATIONS_NATIVE_EXIT'}
def number(v,lo=0,hi=180):return type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi
def equal(a,b):
    # Canonical JSON preserves int/bool/float distinction, unlike dict equality.
    try:return canonical(a)==canonical(b)
    except (ValueError,TypeError):return False
def bounded(path,cap):
    require(not path.is_symlink(),'EVIDENCE_PATH')
    with path.open('rb') as f:data=f.read(cap+1)
    require(len(data)<=cap,'EVIDENCE_CAP');return data
def load(path,cap=OBSERVER_CAP):return strict_loads(bounded(path,cap))
def observer_events(events):
    require(type(events) is list and 0<len(events)<128,'OBSERVER_SCHEMA')
    for e in events:
        require(type(e) is dict and set(e)==EVENT_KEYS,'OBSERVER_SCHEMA')
        require(rid_valid(e['requestID']) and rid_valid(e['connectionID']),'OBSERVER_SCHEMA')
        require(type(e['phase']) is str and e['phase'] in ('metadata','prepare') and type(e['boundary']) is str and e['boundary'] in ('CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS'),'OBSERVER_SCHEMA')
        require(type(e['event']) is str and e['event'] in ('BEGIN','END','ERROR') and type(e['code']) is str and e['code'] in CODES,'OBSERVER_SCHEMA')
        require(number(e['elapsed']) and (e['timeout']=='UNKNOWN' if type(e['timeout']) is str else number(e['timeout'])),'OBSERVER_SCHEMA')
        require(type(e['classes']) is list and len(e['classes'])<=12 and all(type(c) is str and c in CLASS_NAMES for c in e['classes']),'OBSERVER_SCHEMA')
    return events
def publish_observer(root):
    """Parent after physical reap; only validated numeric/opaque-ID JSONL is copied."""
    root=pathlib.Path(root);source=root/'tiktok-boundaries.jsonl'
    link=dict(version=1,status='FAIL',code='OBSERVER_MISSING',present=False,incomplete=True,rawBytes=0,rawSHA=None,originalUID=None,originalMode=None)
    try:
        events,present,incomplete=read_owned_observer(source)
        link.update(present=present,incomplete=incomplete)
        require(present and not incomplete,'OBSERVER_INCOMPLETE')
        raw=bounded(source,OBSERVER_CAP);parsed=[strict_loads(x) for x in raw.splitlines()]
        observer_events(parsed);require(equal(events,parsed),'OBSERVER_INCOMPLETE')
        st=source.stat();require(st.st_uid==1000 and stat.S_IMODE(st.st_mode)==0o600,'OBSERVER_PERMISSIONS')
        with (root/'observer-public.jsonl').open('xb') as f:f.write(raw)
        os.chmod(root/'observer-public.jsonl',0o644)
        link.update(status='PASS',code='OBSERVER_PROJECTED',rawBytes=len(raw),rawSHA=hashlib.sha256(raw).hexdigest(),originalUID=st.st_uid,originalMode=stat.S_IMODE(st.st_mode),incomplete=False)
    except Exception:
        link['code']='OBSERVER_PROJECTION_REJECTED' if source.exists() else 'OBSERVER_MISSING'
    with (root/'observer-link.json').open('xb') as f:f.write(canonical(link))
    os.chmod(root/'observer-link.json',0o644)
    return link
def projected_observer(root):
    root=pathlib.Path(root);link=load(root/'observer-link.json',4096)
    require(type(link) is dict and set(link)=={'version','status','code','present','incomplete','rawBytes','rawSHA','originalUID','originalMode'},'OBSERVER_LINK')
    require(type(link['version']) is int and link['version']==1 and link['status']=='PASS' and link['code']=='OBSERVER_PROJECTED' and link['present'] is True and link['incomplete'] is False,'OBSERVER_LINK')
    require(type(link['rawBytes']) is int and 0<link['rawBytes']<=OBSERVER_CAP and type(link['rawSHA']) is str and re.fullmatch('[a-f0-9]{64}',link['rawSHA']) is not None,'OBSERVER_LINK')
    require(type(link['originalUID']) is int and link['originalUID']==1000 and type(link['originalMode']) is int and link['originalMode']==0o600,'OBSERVER_LINK')
    st=(root/'tiktok-boundaries.jsonl').stat();require(st.st_uid==1000 and stat.S_IMODE(st.st_mode)==0o600 and not (root/'tiktok-boundaries.jsonl').is_symlink(),'OBSERVER_PERMISSIONS')
    raw=bounded(root/'observer-public.jsonl',OBSERVER_CAP)
    require(len(raw)==link['rawBytes'] and hashlib.sha256(raw).hexdigest()==link['rawSHA'],'OBSERVER_LINK')
    return observer_events([strict_loads(line) for line in raw.splitlines()])
def revalidate_accounting(result,events,reported,n):
    # Duplicate rows inside one packet are different from repeated identical
    # metadata rows across metadata/aggregate packets. Never silently dedup either.
    for name in ('metadataPacket','preparePacket'):
        packet=result.get(name);require(type(packet) is dict and packet.get('status')=='PASS' and type(packet.get('rows')) is list,'ACCOUNTING_PACKET')
        seen=set()
        for row in packet['rows']:
            keys={'TLSverify','actualImpersonation','boundaries','decodedBytes','effectiveTimeout','impersonationRequested','index','method','phase','sendDiagnostic','status','transport','url'}
            require(type(row) is dict and set(row)==keys and type(row.get('phase')) is str and row['phase'] in ('metadata','prepare') and type(row.get('index')) is int,'ACCOUNTING_PACKET')
            require(row['TLSverify'] is True and row['actualImpersonation'] is False and type(row['impersonationRequested']) is bool and row['transport']=='Requests.HTTPAdapter' and row['method']=='GET' and row['url']=='[url-redacted]','ACCOUNTING_PACKET')
            require(type(row['status']) is int and 100<=row['status']<=599,'ACCOUNTING_PACKET')
            k=(row['phase'],row['index']);require(k not in seen,'ACCOUNTING_PACKET_DUPLICATE');seen.add(k)
            require(type(row.get('decodedBytes')) is int and row['decodedBytes']>=0,'ACCOUNTING_BYTES')
            b=row.get('boundaries');require(type(b) is dict and set(b)=={'connectionID','incomplete','requestID','reused','terminal'} and b.get('incomplete') is False and type(b.get('reused')) is bool,'ACCOUNTING_PACKET')
            require(rid_valid(b['requestID']) and rid_valid(b['connectionID']) and type(b['terminal']) is list and len(b['terminal'])<=6,'ACCOUNTING_PACKET')
            actual=[{k:e[k] for k in ('boundary','code','elapsed','event','timeout')} for e in events if e['requestID']==b['requestID'] and e['event'] in ('END','ERROR')]
            require(equal(b['terminal'],actual),'ACCOUNTING_PACKET')
            diag=row.get('sendDiagnostic');require(type(diag) is dict and set(diag)=={'boundary','classes','code','headerWait','originTLS','phase','proxyConnect','seconds','status'} and type(diag.get('status')) is int and diag.get('phase')==row['phase'],'ACCOUNTING_PACKET')
            require(diag['boundary']=='HTTPAdapter.send' and diag['code']=='HTTP_RESPONSE' and number(diag['seconds'],0,60) and all(diag[k]=='UNKNOWN' and type(diag[k]) is str for k in ('headerWait','originTLS','proxyConnect')),'ACCOUNTING_PACKET')
            require(type(diag['classes']) is list and len(diag['classes'])<=12 and all(type(c) is str and c in CLASS_NAMES for c in diag['classes']),'ACCOUNTING_PACKET')
            t=row['effectiveTimeout'];require(type(t) is dict and set(t)=={'connectSeconds','phaseRemainingSeconds','readCeilingSeconds','totalSeconds'} and all(number(v,.000000001,30 if row['phase']=='metadata' else 60) for v in t.values()),'ACCOUNTING_PACKET')
            require(t['connectSeconds']<=10 and t['readCeilingSeconds']<=20 and t['totalSeconds']==t['phaseRemainingSeconds'],'ACCOUNTING_PACKET')
    rebuilt=receipt(result,events,observer_present=True,observer_incomplete=False,selected_count=n)
    require(rebuilt['exact'] is True and rebuilt['withinBudget'] is True,'ACCOUNTING_REVALIDATION')
    require(equal(reported,rebuilt) and equal(result.get('requestAccounting'),rebuilt),'ACCOUNTING_REPORT_CONFLICT')
    require(rebuilt['preparedGETAttempts']['prepare']==n,'ACCOUNTING_QUOTA')
    decoded=rebuilt['decodedBytesFromPackets'];packet=result['preparePacket'];meta=result['metadataPacket']
    for value in (meta.get('metadataBytes'),packet.get('metadataBytes'),packet.get('inputBytes'),packet.get('outputBytes')):require(type(value) is int and value>=0,'ACCOUNTING_BYTES')
    require(meta['metadataBytes']==packet['metadataBytes']==decoded['metadata'] and packet['inputBytes']==sum(decoded.values()),'ACCOUNTING_BYTES')
    require(packet['outputBytes']==decoded['prepare']==sum(f['bytes'] for f in packet['files']),'ACCOUNTING_BYTES')
    prepares=[r for r in packet['rows'] if r['phase']=='prepare']
    require(len(prepares)==n and all(row['decodedBytes']==file['bytes'] for row,file in zip(prepares,packet['files'])),'ACCOUNTING_BYTES')
    return rebuilt
def operation_proof(proof,index,prepare_end):
    require(type(proof) is dict and set(proof)=={'version','index','scope','events'} and type(proof['version']) is int and proof['version']==2 and type(proof['index']) is int and proof['index']==index,'OPERATIONS_SCHEMA')
    scope=proof['scope'];require(type(scope) is dict and set(scope)=={'begin','end','itemDeadline','prepareDeadline','reserveSeconds'},'OPERATIONS_SCOPE')
    require(all(number(scope[k],0,1e12) for k in ('begin','end','itemDeadline','prepareDeadline')) and type(scope['reserveSeconds']) is int and scope['reserveSeconds']==10 and number(prepare_end,0,1e12),'OPERATIONS_SCOPE')
    start,end,deadline=scope['begin'],scope['end'],scope['itemDeadline']
    require(scope['prepareDeadline']==prepare_end and prepare_end-180<=start<=end<=deadline and deadline<=min(start+60,prepare_end-10),'OPERATIONS_DEADLINE')
    events=proof['events'];require(type(events) is list and 0<len(events)<=32,'OPERATIONS_SCHEMA')
    expected=[('DOWNLOADER','BEGIN'),('DOWNLOADER','END'),('CONTRACT','BEGIN'),('FFPROBE','BEGIN'),('FFPROBE','END'),('FFPROBE','BEGIN'),('FFPROBE','END'),('DECODE','BEGIN'),('DECODE','END'),('CONTRACT','END'),('HASH','BEGIN'),('HASH','END')]
    stack=[];actual=[];terminals=[]
    for e in events:
        require(type(e) is dict and set(e)=={'operation','event','code','elapsed','timeout','returncode'},'OPERATIONS_SCHEMA')
        op,event=e['operation'],e['event'];require(type(op) is str and op in OPS and type(event) is str and event in ('BEGIN','END','ERROR'),'OPERATIONS_SCHEMA')
        require(number(e['elapsed'],0,60) and e['elapsed']<=end-start+.001,'OPERATIONS_TIMING')
        native=op in ('FFPROBE','DECODE')
        if native:require(number(e['timeout'],.000000001,10 if op=='FFPROBE' else 30) and e['timeout']<=deadline-start+.001,'OPERATIONS_TIMEOUT')
        else:require(e['timeout'] is None and e['returncode'] is None,'OPERATIONS_NATIVE_TYPE')
        actual.append((op,event))
        if event=='BEGIN':
            require(e['code']=='BEGIN' and type(e['code']) is str and e['elapsed']==0 and e['returncode'] is None,'OPERATIONS_BEGIN');stack.append(e)
        else:
            require(stack and stack[-1]['operation']==op,'OPERATIONS_ORDER');begin=stack.pop()
            require(event=='END' and e['code']=='OK' and type(e['code']) is str,'OPERATIONS_TERMINAL')
            require(equal(e['timeout'],begin['timeout']),'OPERATIONS_TIMEOUT')
            if native:require(type(e['returncode']) is int and e['returncode']==0,'OPERATIONS_NATIVE_EXIT')
            terminals.append(e)
    require(not stack and actual==expected,'OPERATIONS_ORDER')
    contract=next(e['elapsed'] for e in terminals if e['operation']=='CONTRACT')
    require(sum(e['elapsed'] for e in terminals if e['operation'] in ('FFPROBE','DECODE'))<=contract+.001,'OPERATIONS_TIMING')
    require(sum(e['elapsed'] for e in terminals if e['operation'] in ('DOWNLOADER','CONTRACT','HASH'))<=end-start+.001,'OPERATIONS_TIMING')
    return dict(status='PASS',index=index,events=len(events),nativeExits=[e['returncode'] for e in terminals if e['operation'] in ('FFPROBE','DECODE')])
