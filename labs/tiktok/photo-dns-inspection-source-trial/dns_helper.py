"""Same stdlib resolver/Popen protocol; freeze refusal before optional inspection.
No endpoint, hostname, exception text or source data is emitted in overcap packets.
"""
import json,os,socket,sys,threading,time
from dns_counts import diagnostics_a,unknown_counts
from dns_inspection import inspect,partial,stats_bytes,bundle_valid,SECONDS,FINISH_RESERVE,STATS_BYTES
INPUT_CAP=16384;OUTPUT_CAP=32768;ANSWER_CAP=64

def packet_rows(rows,end,*,clock=time.monotonic,inspector=inspect):
    inspection=None;stop=None
    if type(rows) is list and len(rows)>ANSWER_CAP:
        # Authoritative refusal is set BEFORE a possibly failing observer runs.
        value={'status':'ERROR','code':'ANSWER_CAP','answers':[]}
        counts=unknown_counts('RAW_CAP',65,'AT_LEAST_65')
        start=clock();stop=min(start+SECONDS,end-FINISH_RESERVE)
        try:inspection=inspector(rows,stop,clock=clock)
        except MemoryError:inspection=partial('MEMORY_BOUND')
        except Exception:inspection=partial('MISSING')
    else:
        counts=diagnostics_a(rows,end,clock=clock)
        if clock()>=end:value={'status':'ERROR','code':'DEADLINE','answers':[]};counts=unknown_counts('DEADLINE')
        else:value={'status':'OK','code':'OK','answers':rows}
    value.update(counts=counts,inspection=inspection)
    return value,stop

def encoded(value,end,stop,*,clock=time.monotonic,encoder=None):
    """Check scan subdeadline before/after encoding; never rescue absolute expiry."""
    encode=encoder or (lambda v:json.dumps(v,separators=(',',':'),allow_nan=False).encode())
    def expired():
        if stop is not None and clock()>=stop:value['inspection']=partial('DEADLINE')
    if clock()>=end:return None
    expired()
    if not bundle_valid(value['counts'],value['inspection']):
        if value['code']!='ANSWER_CAP':return None
        value['inspection']=partial('MISSING')
    try:
        if len(stats_bytes(value['counts'],value['inspection']))>STATS_BYTES:raise OverflowError()
        data=encode(value)
    except Exception as exc:
        if value['code']!='ANSWER_CAP':return None
        value['inspection']=partial('MEMORY_BOUND' if isinstance(exc,MemoryError) else 'ENCODE_CAP')
        if clock()>=end:return None
        try:data=encode(value)
        except Exception:return None
    if clock()>=end:return None
    # If encoding used up the observation slice, discard COMPLETE and re-encode.
    if stop is not None and clock()>=stop and value['inspection']['reason']!='DEADLINE':
        value['inspection']=partial('DEADLINE')
        try:data=encode(value)
        except Exception:return None
    if clock()>=end or len(stats_bytes(value['counts'],value['inspection']))>STATS_BYTES or len(data)>OUTPUT_CAP:return None
    return data

def deliver(value,end,stop,*,clock=time.monotonic,writer=None,encoder=None):
    data=encoded(value,end,stop,clock=clock,encoder=encoder)
    if data is None or clock()>=end:return 20
    if stop is not None and clock()>=stop and value['inspection']['reason']!='DEADLINE':
        value['inspection']=partial('DEADLINE');data=encoded(value,end,stop,clock=clock,encoder=encoder)
        if data is None or clock()>=end:return 20
    write=writer or sys.stdout.buffer.write
    write(data)  # public pipe; parent enforces absolute receive deadline even if write blocks
    if writer is None:sys.stdout.buffer.flush()
    return 0

def main():
    data=sys.stdin.buffer.read(INPUT_CAP+1)
    if len(data)>INPUT_CAP:return 20
    obj=json.loads(data);mode=obj.get('mode','numeric');end=obj['deadline']
    blocked={(x['dev'],x['ino'],x['mode']) for x in obj.get('blocked',[])};inherited=0
    for file in os.listdir('/proc/self/fd'):
        try:
            st=os.fstat(int(file));inherited+=int((st.st_dev,st.st_ino,st.st_mode) in blocked)
        except OSError:pass
    if mode=='crash':os._exit(20)
    time.sleep(obj.get('delay',0))
    if mode=='oversize':sys.stdout.buffer.write(b'X'*(OUTPUT_CAP+4096));sys.stdout.buffer.flush();return 0
    stop=None
    if time.monotonic()>=end:value=dict(status='ERROR',code='DEADLINE',answers=[],counts=unknown_counts('DEADLINE'),inspection=None)
    else:
        try:
            rows=[]
            if mode=='error':socket.getaddrinfo('FAKE_NOT_NUMERIC',443,flags=socket.AI_NUMERICHOST)
            if mode=='hostname':rows=socket.getaddrinfo(obj['hostname'],443,type=socket.SOCK_STREAM)
            elif mode=='localhost':rows=socket.getaddrinfo('localhost',443,type=socket.SOCK_STREAM)
            else:
                for family,_,_,_,address in obj['addresses']:
                    rows.extend(socket.getaddrinfo(address[0],443,family=family,type=socket.SOCK_STREAM,flags=socket.AI_NUMERICHOST))
            if mode=='answer-oversize':rows=rows[:1]*65
            value,stop=packet_rows(rows,end)
        except socket.gaierror:value=dict(status='ERROR',code='DNS_ERROR',answers=[],counts=unknown_counts(),inspection=None)
        except MemoryError:value=dict(status='ERROR',code='DNS_ERROR',answers=[],counts=unknown_counts(),inspection=None)
    value.update(version=3,helperID=obj.get('helperID'),unexpectedInherited=inherited,threads=threading.active_count())
    return deliver(value,end,stop)
if __name__=='__main__':
    try:sys.exit(main())
    except SystemExit:raise
    except BaseException:sys.exit(20)
