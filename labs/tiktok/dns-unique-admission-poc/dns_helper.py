"""Owned public stdlib resolver + v4 admission; no custom transport/parser."""
import json,math,os,socket,sys,threading,time
from dns_admission import admit,partial,packet_valid,strict_loads,ident,HEAP_CAP,OUTPUT_CAP
INPUT_CAP=16384;ANSWER_CAP=64
def packet_rows(rows,end,*,clock=time.monotonic,memory_limit=96*1024,measured=None):
    answers,stats,stop,charge=admit(rows,end,clock=clock,memory_limit=memory_limit,measured=measured)
    return dict(status='OK' if stats['decision']=='ALLOW' else 'ERROR',code=stats['reason'],answers=answers,admission=stats),stop,charge
def encode_once(value,end,stop,charge,*,clock=time.monotonic):
    data=bytearray();encoder=json.JSONEncoder(separators=(',',':'),allow_nan=False)
    for chunk in encoder.iterencode(value):
        if clock()>=end or clock()>=stop:raise TimeoutError('DEADLINE')
        b=chunk.encode()
        if len(data)+len(b)>OUTPUT_CAP:raise OverflowError('ENCODE_CAP')
        if charge+len(data)+len(b)>HEAP_CAP:raise MemoryError('MEMORY_CAP')
        data.extend(b)
    if clock()>=end or clock()>=stop:raise TimeoutError('DEADLINE')
    return data
def deliver(value,end,stop,charge=0,*,clock=time.monotonic,writer=None,measured=None):
    if clock()>=end:return 20
    if not packet_valid(value):return 20
    try:data=encode_once(value,end,stop,charge,clock=clock)
    except (MemoryError,OverflowError,TimeoutError) as exc:
        code='MEMORY_CAP' if isinstance(exc,MemoryError) else 'ENCODE_CAP' if isinstance(exc,OverflowError) else 'DEADLINE'
        value.update(status='ERROR',code=code,answers=[],admission=partial(code))
        if clock()>=end:return 20
        # Denial may be encoded after scan slice expiry, but never absolute end.
        try:data=encode_once(value,end,end,0,clock=clock)
        except (MemoryError,OverflowError,TimeoutError):return 20
    if measured is not None:measured.update(encodedBytes=len(data),designCharge=charge+len(data))
    if clock()>=end:return 20
    if value['status']=='OK' and clock()>=stop:return 20
    (writer or sys.stdout.buffer.write)(data)
    if writer is None:sys.stdout.buffer.flush()
    return 0
def main():
    data=sys.stdin.buffer.read(INPUT_CAP+1)
    if len(data)>INPUT_CAP:return 20
    obj=strict_loads(data)
    keys={'version','expectedProtocol','helperID','deadline','addresses','delay','mode','blocked','hostname'}
    if type(obj) is not dict or set(obj)!=keys or type(obj['version']) is not int or obj['version']!=2 or type(obj['expectedProtocol']) is not int or obj['expectedProtocol']!=4 or not ident(obj['helperID']):return 20
    end=obj['deadline'];delay=obj['delay'];mode=obj['mode']
    if type(end) not in (int,float) or not math.isfinite(end) or end<0 or type(delay) not in (int,float) or not math.isfinite(delay) or not 0<=delay<=30 or type(obj['addresses']) is not list or len(obj['addresses'])>64 or type(obj['blocked']) is not list or len(obj['blocked'])>64:return 20
    if mode not in ('numeric','hostname','error','crash','oversize','late-reply'):return 20
    if mode=='hostname' and (type(obj['hostname']) is not str or not 1<=len(obj['hostname'])<=253):return 20
    blocked={(x['dev'],x['ino'],x['mode']) for x in obj['blocked']};inherited=0
    for fd in os.listdir('/proc/self/fd'):
        try:st=os.fstat(int(fd));inherited+=int((st.st_dev,st.st_ino,st.st_mode) in blocked)
        except OSError:pass
    if mode=='crash':os._exit(20)
    time.sleep(delay)
    if mode=='oversize':sys.stdout.buffer.write(b'X'*(OUTPUT_CAP+1));sys.stdout.buffer.flush();return 0
    if time.monotonic()>=end:value=dict(status='ERROR',code='DEADLINE',answers=[],admission=partial('DEADLINE'));stop=end;charge=0
    else:
        try:
            if mode=='error':raise socket.gaierror()
            if mode=='hostname':rows=socket.getaddrinfo(obj['hostname'],443,type=socket.SOCK_STREAM)
            else:
                rows=[]
                for r in obj['addresses']:
                    rows.extend(socket.getaddrinfo(r[4][0],443,family=r[0],type=socket.SOCK_STREAM,flags=socket.AI_NUMERICHOST))
            value,stop,charge=packet_rows(rows,end)
        except (socket.gaierror,MemoryError):value=dict(status='ERROR',code='DNS_ERROR',answers=[],admission=partial('DNS_ERROR'));stop=end;charge=0
    value.update(version=4,helperID=obj['helperID'],unexpectedInherited=inherited,threads=threading.active_count())
    return deliver(value,end,stop,charge)
if __name__=='__main__':
    try:sys.exit(main())
    except SystemExit:raise
    except BaseException:sys.exit(20)
