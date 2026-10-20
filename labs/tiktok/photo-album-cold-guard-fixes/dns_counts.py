"""Diagnostics A only. Public ipaddress numeric parsing; never dedup connect input."""
import ipaddress,json,socket,time
RAW_CAP=64;COUNT_BYTES=512
def number(v,top):return type(v) is int and 0<=v<=top
def endpoint_key(row):
    if type(row) not in (tuple,list) or len(row)!=5:raise ValueError('ROW_INVALID')
    family,kind,proto,canon,addr=row
    if isinstance(family,bool) or not isinstance(family,int) or family not in (socket.AF_INET,socket.AF_INET6):raise ValueError('ROW_INVALID')
    if isinstance(kind,bool) or not isinstance(kind,int) or kind not in (socket.SOCK_STREAM,socket.SOCK_DGRAM):raise ValueError('ROW_INVALID')
    if not number(proto,2147483647) or type(canon) is not str or len(canon)>255 or '\x00' in canon:raise ValueError('ROW_INVALID')
    if type(addr) not in (tuple,list) or len(addr)!=(2 if family==socket.AF_INET else 4):raise ValueError('ROW_INVALID')
    host,port=addr[:2]
    if type(host) is not str or not 1<=len(host)<=45 or '%' in host or not number(port,65535):raise ValueError('ROW_INVALID')
    ip=ipaddress.ip_address(host)
    if ip.version!=(4 if family==socket.AF_INET else 6):raise ValueError('ROW_INVALID')
    extras=()
    if family==socket.AF_INET6:
        flow,scope=addr[2:]
        if not number(flow,1048575) or not number(scope,4294967295):raise ValueError('ROW_INVALID')
        extras=(flow,scope)
    return (int(family),int(kind),proto,int(ip),port,*extras)
def unknown_counts(reason='MISSING',raw=None,raw_mode='UNKNOWN'):
    return dict(version=1,policy='RAW64_OBSERVATION_ONLY',evidence='PARTIAL',reason=reason,
                rawCount=raw,rawCountMode=raw_mode,endpointCount=None,duplicateCount=None,ipv4Rows=None,ipv6Rows=None)
def diagnostics_a(rows,end,clock=time.monotonic):
    if clock()>=end:return unknown_counts('DEADLINE')
    if type(rows) is not list:return unknown_counts('ROW_INVALID')
    count=len(rows)
    if count>RAW_CAP:return unknown_counts('RAW_CAP',65,'AT_LEAST_65')
    keys=set();ipv4=0
    try:
        for row in rows:
            if clock()>=end:return unknown_counts('DEADLINE',count,'EXACT')
            keys.add(endpoint_key(row));ipv4+=row[0]==socket.AF_INET
    except (ValueError,TypeError,IndexError):return unknown_counts('ROW_INVALID',count,'EXACT')
    if clock()>=end:return unknown_counts('DEADLINE',count,'EXACT')
    return dict(version=1,policy='RAW64_OBSERVATION_ONLY',evidence='COMPLETE',reason='OK',
                rawCount=count,rawCountMode='EXACT',endpointCount=len(keys),duplicateCount=count-len(keys),ipv4Rows=ipv4,ipv6Rows=count-ipv4)
def counts_valid(row):
    keys={'version','policy','evidence','reason','rawCount','rawCountMode','endpointCount','duplicateCount','ipv4Rows','ipv6Rows'}
    if type(row) is not dict or set(row)!=keys or type(row['version']) is not int or row['version']!=1:return False
    if row['policy']!='RAW64_OBSERVATION_ONLY' or row['reason'] not in ('OK','RAW_CAP','ROW_INVALID','DEADLINE','IPC_CAP','MISSING'):return False
    raw,mode,reason=row['rawCount'],row['rawCountMode'],row['reason']
    values=[row[k] for k in ('endpointCount','duplicateCount','ipv4Rows','ipv6Rows')]
    if reason=='RAW_CAP':
        accepted=(row['evidence']=='PARTIAL' and mode=='AT_LEAST_65' and number(raw,65) and raw==65 and all(v is None for v in values))
    elif reason=='OK':
        families=sum(v>0 for v in values[2:] if number(v,64))
        accepted=(row['evidence']=='COMPLETE' and mode=='EXACT' and number(raw,64) and all(number(v,64) for v in values)
          and values[0]+values[1]==raw and values[2]+values[3]==raw and families<=values[0]<=raw
          and (raw==0 and values[0]==0 or raw>0 and values[0]>=1))
    else:
        allowed=('UNKNOWN','EXACT') if reason in ('DEADLINE','ROW_INVALID') else ('UNKNOWN',)
        accepted=(row['evidence']=='PARTIAL' and mode in allowed and all(v is None for v in values)
          and (mode=='UNKNOWN' and raw is None or mode=='EXACT' and number(raw,64)))
    return bool(accepted and len(json.dumps(row,separators=(',',':')).encode())<=COUNT_BYTES)
