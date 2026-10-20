"""Process-isolated stdlib getaddrinfo; stdin/stdout are bounded RAM IPC, never logs."""
import json,os,socket,sys,threading,time
from dns_counts import diagnostics_a,unknown_counts
INPUT_CAP=16384;OUTPUT_CAP=32768;ANSWER_CAP=64
def main():
    data=sys.stdin.buffer.read(INPUT_CAP+1)
    if len(data)>INPUT_CAP:return 20
    obj=json.loads(data);mode=obj.get('mode','numeric');end=obj['deadline'];counts=unknown_counts()
    # Audit descriptor identity in RAM. Only three communicated standard handles allowed.
    blocked={(x['dev'],x['ino'],x['mode']) for x in obj.get('blocked',[])}
    inherited=0
    for file in os.listdir('/proc/self/fd'):
        try:
            stat=os.fstat(int(file));inherited+=int((stat.st_dev,stat.st_ino,stat.st_mode) in blocked)
        except OSError:pass
    if mode=='crash':os._exit(20)
    time.sleep(obj.get('delay',0))  # explicit DNS fixture latency, not cleanup polling.
    if mode=='oversize':
        sys.stdout.buffer.write(b'X'*(OUTPUT_CAP+4096));sys.stdout.buffer.flush();return 0
    if mode=='late-reply':
        # Adversarial fixture response: parent must reject after its absolute deadline.
        value={'status':'OK','answers':obj['addresses']}
    elif time.monotonic()>=end:
        value={'status':'ERROR','code':'DEADLINE','answers':[]}
        counts=unknown_counts('DEADLINE')
    else:
        try:
            answers=[]
            if mode=='error':socket.getaddrinfo('FAKE_NOT_NUMERIC',443,flags=socket.AI_NUMERICHOST)
            if mode=='hostname':answers=socket.getaddrinfo(obj['hostname'],443,type=socket.SOCK_STREAM)
            elif mode=='localhost':answers=socket.getaddrinfo('localhost',443,type=socket.SOCK_STREAM)
            else:
                for family,_,_,_,address in obj['addresses']:
                    answers.extend(socket.getaddrinfo(address[0],443,family=family,type=socket.SOCK_STREAM,flags=socket.AI_NUMERICHOST))
            if mode=='answer-oversize':answers=answers[:1]*65
            counts=diagnostics_a(answers,end)
            if time.monotonic()>=end:
                value={'status':'ERROR','code':'DEADLINE','answers':[]}
                counts=unknown_counts('DEADLINE')
            elif len(answers)>ANSWER_CAP and mode!='answer-oversize':value={'status':'ERROR','code':'ANSWER_CAP','answers':[]}
            else:value={'status':'OK','answers':answers}
        except socket.gaierror:value={'status':'ERROR','code':'DNS_ERROR','answers':[]}
    value.update(helperID=obj.get('helperID'),counts=counts,unexpectedInherited=inherited,threads=threading.active_count())
    encoded=json.dumps(value,separators=(',',':')).encode()
    if len(encoded)>OUTPUT_CAP:return 20
    sys.stdout.buffer.write(encoded);sys.stdout.buffer.flush();return 0
if __name__=='__main__':
    try:sys.exit(main())
    except BaseException as exc:
        if isinstance(exc,SystemExit):raise
        sys.exit(20)  # never emit exception/message/stack to stderr/stdout.
