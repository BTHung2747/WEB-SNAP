"""Bounded observation only; public stdlib + unchanged accepted endpoint validator.

Never returns addresses or changes acceptance. Bulk resolver allocation is external
to this scratch budget; existing process/cgroup/deadline containment stays required.
"""
import ipaddress,json,socket,sys,time
from dns_counts import endpoint_key,counts_valid,number
RAW_BOUND=256;SECONDS=.250;FINISH_RESERVE=.010;KEY_BYTES=96*1024;DESIGN_HEAP_BYTES=128*1024;STATS_BYTES=512
KEYS={'version','policy','evidence','reason','rawCount','rawCountMode','endpointCount','duplicateCount','ipv4Rows','ipv6Rows','publicState'}
def partial(reason='MISSING',raw=None,mode='UNKNOWN'):
    return dict(version=1,policy='RAW64_INSPECT256_ONLY',evidence='PARTIAL',reason=reason,
      rawCount=raw,rawCountMode=mode,endpointCount=None,duplicateCount=None,ipv4Rows=None,ipv6Rows=None,publicState='UNKNOWN')
def inspect(rows,stop,*,clock=time.monotonic,key_limit=KEY_BYTES,measured=None):
    if clock()>=stop:return partial('DEADLINE')
    if type(rows) is not list:return partial('ROW_INVALID')
    raw=len(rows)
    if raw<=64:return None
    if raw>RAW_BOUND:return partial('INSPECTION_BOUND',257,'AT_LEAST_257')
    keys=set();charge=0;v4=0;global_only=True
    try:
        for row in rows:
            if clock()>=stop:return partial('DEADLINE')
            key=endpoint_key(row)
            global_only=bool(ipaddress.ip_address(row[4][0]).is_global) and global_only
            v4+=row[0]==socket.AF_INET
            if key not in keys:
                charge+=sys.getsizeof(key)+sum(sys.getsizeof(x) for x in key);keys.add(key)
                retained=charge+sys.getsizeof(keys)
                if measured is not None:measured['retained']=max(measured.get('retained',0),retained)
                if retained>key_limit:return partial('MEMORY_BOUND')
    except MemoryError:return partial('MEMORY_BOUND')
    except (ValueError,TypeError,IndexError):return partial('ROW_INVALID',raw,'EXACT')
    if clock()>=stop:return partial('DEADLINE')
    return dict(version=1,policy='RAW64_INSPECT256_ONLY',evidence='COMPLETE',reason='OK',rawCount=raw,
      rawCountMode='EXACT',endpointCount=len(keys),duplicateCount=raw-len(keys),ipv4Rows=v4,ipv6Rows=raw-v4,
      publicState='ALL_GLOBAL' if global_only else 'HAS_NON_GLOBAL')
def valid(value):
    if type(value) is not dict or set(value)!=KEYS:return False
    if any(type(value[k]) is not str for k in ('policy','evidence','reason','rawCountMode','publicState')):return False
    if type(value['version']) is not int or value['version']!=1 or value['policy']!='RAW64_INSPECT256_ONLY':return False
    r=value['reason'];raw=value['rawCount'];mode=value['rawCountMode'];values=[value[k] for k in ('endpointCount','duplicateCount','ipv4Rows','ipv6Rows')]
    if r=='OK':
        return (value['evidence']=='COMPLETE' and mode=='EXACT' and number(raw,256) and raw>64
          and all(number(v,256) for v in values) and values[0]+values[1]==raw and values[2]+values[3]==raw
          and max(1,sum(v>0 for v in values[2:]))<=values[0]<=raw and value['publicState'] in ('ALL_GLOBAL','HAS_NON_GLOBAL'))
    if value['evidence']!='PARTIAL' or value['publicState']!='UNKNOWN' or not all(v is None for v in values):return False
    if r=='INSPECTION_BOUND':return type(raw) is int and raw==257 and mode=='AT_LEAST_257'
    if r=='ROW_INVALID':return (mode=='UNKNOWN' and raw is None) or (mode=='EXACT' and number(raw,256) and raw>64)
    return r in ('DEADLINE','MEMORY_BOUND','ENCODE_CAP','IPC_CAP','MISSING') and raw is None and mode=='UNKNOWN'
def stats_bytes(counts,inspection):
    return json.dumps({'counts':counts,'inspection':inspection},separators=(',',':'),allow_nan=False).encode()
def bundle_valid(counts,inspection):
    if not counts_valid(counts):return False
    if counts['reason']=='RAW_CAP':
        if not valid(inspection):return False
    elif inspection is not None:return False
    try:return len(stats_bytes(counts,inspection))<=STATS_BYTES
    except (TypeError,ValueError,OverflowError):return False
