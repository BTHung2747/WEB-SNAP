"""PoC v4 business contract only; public numeric parser and insertion-order dict.
Every raw row is checked before deduplication/admission. No DNS/TCP implementation.
"""
import ipaddress,json,math,re,socket,sys,time
from dns_counts import endpoint_key
RAW_CAP=256;ENDPOINT_CAP=64;STATS_CAP=512;RETAINED_CAP=96*1024;HEAP_CAP=128*1024
SCAN_SECONDS=.250;FINISH_RESERVE=.010;OUTPUT_CAP=32768
POLICY='RAW_VALIDATE256_UNIQUE64_ORDERED'
REASONS={'OK','ENDPOINT_CAP','RAW_PARSE_CAP','ROW_INVALID','POLICY_DENIED','DEADLINE','MEMORY_CAP','ENCODE_CAP','DNS_ERROR'}
KEYS={'version','policy','evidence','decision','reason','rawCount','rawCountMode','validatedCount','endpointCount','duplicateCount','ipv4Rows','ipv6Rows','admittedCount','rawCap','endpointCap','publicState'}
def integer(v,low,high):return type(v) is int and low<=v<=high
def ident(v):return type(v) is str and re.fullmatch('[a-f0-9]{16}',v) is not None
def strict_loads(data):
    def pairs(values):
        out={}
        for k,v in values:
            if k in out:raise ValueError('JSON_DUPLICATE_KEY')
            out[k]=v
        return out
    def constant(v):raise ValueError('JSON_NONFINITE')
    return json.loads(data,object_pairs_hook=pairs,parse_constant=constant)
def compact(value):return json.dumps(value,separators=(',',':'),allow_nan=False).encode()
def partial(reason,raw=None,validated=None,mode='UNKNOWN'):
    return dict(version=1,policy=POLICY,evidence='PARTIAL',decision='DENY',reason=reason,
      rawCount=raw,rawCountMode=mode,validatedCount=validated,endpointCount=None,duplicateCount=None,
      ipv4Rows=None,ipv6Rows=None,admittedCount=0,rawCap=RAW_CAP,endpointCap=ENDPOINT_CAP,publicState='UNKNOWN')
def guard_row(row):
    key=endpoint_key(row)
    ip=ipaddress.ip_address(row[4][0])
    def public(address):
        return address.is_global and not any((address.is_private,address.is_loopback,address.is_link_local,
           address.is_reserved,address.is_unspecified,address.is_multicast))
    if row[1]!=socket.SOCK_STREAM or row[2] not in (0,socket.IPPROTO_TCP) or row[4][1]!=443 or not public(ip):
        raise PermissionError('POLICY_DENIED')
    if isinstance(ip,ipaddress.IPv6Address) and ip.ipv4_mapped is not None and not public(ip.ipv4_mapped):
        raise PermissionError('POLICY_DENIED')
    return key
def deep_charge(value):
    # Conservative referents, not shallow size. Bounded plain objects only;
    # shared scalars are double-charged. No unbounded auxiliary identity set.
    size=sys.getsizeof(value)
    if type(value) in (list,tuple):size+=sum(deep_charge(v) for v in value)
    elif type(value) is dict:size+=sum(deep_charge(k)+deep_charge(v) for k,v in value.items())
    return size
def admit(rows,end,*,clock=time.monotonic,memory_limit=RETAINED_CAP,measured=None):
    stop=min(clock()+SCAN_SECONDS,end-FINISH_RESERVE)
    if clock()>=stop:return [],partial('DEADLINE'),stop,0
    if type(rows) is not list or not rows:return [],partial('ROW_INVALID'),stop,0
    raw=len(rows)
    if raw>RAW_CAP:return [],partial('RAW_PARSE_CAP',257,mode='AT_LEAST_257'),stop,0
    validated=0;v4=0
    # Phase1 is complete raw validation, including duplicate canon/port and suffix.
    for row in rows:
        if clock()>=stop:return [],partial('DEADLINE'),stop,0
        try:guard_row(row)
        except MemoryError:return [],partial('MEMORY_CAP'),stop,0
        except PermissionError:return [],partial('POLICY_DENIED',raw,validated,'EXACT'),stop,0
        except (ValueError,TypeError,IndexError):return [],partial('ROW_INVALID',raw,validated,'EXACT'),stop,0
        validated+=1;v4+=row[0]==socket.AF_INET
        if clock()>=stop:return [],partial('DEADLINE'),stop,0
    kept={};charge=0;peak=0
    try:
        # Phase2 begins only after all raw rows passed. Stable first representative.
        for row in rows:
            if clock()>=stop:return [],partial('DEADLINE'),stop,peak
            key=endpoint_key(row)
            if key not in kept:
                kept[key]=row;charge+=deep_charge(key)+deep_charge(row)
            # includes dict table, output-list slots, stats object allowance and
            # 16KiB transient reserve (recursive frames/encoder chunk/string/etc).
            retained=charge+sys.getsizeof(kept)+sys.getsizeof([])+8*min(len(kept),64)+16384+4096
            peak=max(peak,retained)
            if measured is not None:measured['retainedPeak']=max(measured.get('retainedPeak',0),retained)
            if retained>memory_limit:return [],partial('MEMORY_CAP'),stop,peak
        count=len(kept);allow=count<=ENDPOINT_CAP
        stats=dict(version=1,policy=POLICY,evidence='COMPLETE',decision='ALLOW' if allow else 'DENY',reason='OK' if allow else 'ENDPOINT_CAP',
          rawCount=raw,rawCountMode='EXACT',validatedCount=validated,endpointCount=count,duplicateCount=raw-count,
          ipv4Rows=v4,ipv6Rows=raw-v4,admittedCount=count if allow else 0,rawCap=RAW_CAP,endpointCap=ENDPOINT_CAP,publicState='ALL_ALLOWED')
        if clock()>=stop:return [],partial('DEADLINE'),stop,peak
        return list(kept.values()) if allow else [],stats,stop,peak
    except MemoryError:return [],partial('MEMORY_CAP'),stop,peak
def stats_valid(s):
    if type(s) is not dict or set(s)!=KEYS:return False
    if type(s['version']) is not int or s['version']!=1 or type(s['rawCap']) is not int or s['rawCap']!=256 or type(s['endpointCap']) is not int or s['endpointCap']!=64:return False
    if any(type(s[k]) is not str for k in ('policy','evidence','decision','reason','rawCountMode','publicState')) or s['policy']!=POLICY or s['reason'] not in REASONS:return False
    if not integer(s['admittedCount'],0,64):return False
    raw=s['rawCount'];n=s['endpointCount'];vals=[s[k] for k in ('endpointCount','duplicateCount','ipv4Rows','ipv6Rows')]
    if s['reason'] in ('OK','ENDPOINT_CAP'):
        if not (s['evidence']=='COMPLETE' and s['rawCountMode']=='EXACT' and integer(raw,1,256) and integer(s['validatedCount'],1,256) and s['validatedCount']==raw and
          all(integer(v,0,256) for v in vals) and n+s['duplicateCount']==raw and s['ipv4Rows']+s['ipv6Rows']==raw and
          max(1,int(s['ipv4Rows']>0)+int(s['ipv6Rows']>0))<=n<=raw and s['publicState']=='ALL_ALLOWED'):return False
        if s['reason']=='OK':ok=s['decision']=='ALLOW' and 1<=n<=64 and s['admittedCount']==n
        else:ok=s['decision']=='DENY' and n>64 and s['admittedCount']==0
    else:
        if s['evidence']!='PARTIAL' or s['decision']!='DENY' or s['publicState']!='UNKNOWN' or s['admittedCount']!=0 or any(v is not None for v in vals):return False
        if s['reason']=='RAW_PARSE_CAP':ok=type(raw) is int and raw==257 and s['rawCountMode']=='AT_LEAST_257' and s['validatedCount'] is None
        elif s['reason'] in ('ROW_INVALID','POLICY_DENIED'):
            ok=(s['rawCountMode']=='UNKNOWN' and raw is None and s['validatedCount'] is None) or (s['rawCountMode']=='EXACT' and integer(raw,1,256) and integer(s['validatedCount'],0,raw-1))
        else:ok=s['rawCountMode']=='UNKNOWN' and raw is None and s['validatedCount'] is None
    try:return bool(ok and len(compact(s))<=STATS_CAP)
    except (ValueError,TypeError):return False
def packet_valid(p):
    keys={'version','status','code','answers','helperID','unexpectedInherited','threads','admission'}
    if type(p) is not dict or set(p)!=keys or type(p['version']) is not int or p['version']!=4 or not ident(p['helperID']) or type(p['unexpectedInherited']) is not int or p['unexpectedInherited']!=0 or type(p['threads']) is not int or p['threads']!=1:return False
    s=p['admission'];answers=p['answers']
    if not stats_valid(s) or type(answers) is not list or p['code']!=s['reason'] or type(p['status']) is not str:return False
    if s['decision']=='DENY':return p['status']=='ERROR' and answers==[]
    if p['status']!='OK' or p['code']!='OK' or len(answers)!=s['admittedCount']:return False
    try:
        keys=[guard_row(r) for r in answers]
        v4=sum(r[0]==socket.AF_INET for r in answers);v6=len(answers)-v4
        return len(set(keys))==len(keys) and v4<=s['ipv4Rows'] and v6<=s['ipv6Rows'] and (v4>0)==(s['ipv4Rows']>0) and (v6>0)==(s['ipv6Rows']>0)
    except (ValueError,TypeError,IndexError,PermissionError):return False
