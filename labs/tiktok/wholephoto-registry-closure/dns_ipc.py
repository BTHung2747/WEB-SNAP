"""Public Popen/selectors ownership glue; no host resolver or transport implementation."""
import asyncio,json,os,selectors,signal,subprocess,sys,time,uuid
from ownership import Trace
INPUT_CAP=16384;OUTPUT_CAP=32768;ANSWER_CAP=64
def identity(fd):
    st=os.fstat(fd);return {'dev':st.st_dev,'ino':st.st_ino,'mode':st.st_mode}
def group_left(group):
    count=0
    for file in os.listdir('/proc'):
        if not file.isdigit():continue
        try:count+=int(os.getpgid(int(file))==group)
        except ProcessLookupError:pass
    return count
async def resolve(delay,addresses,deadline,receipt,*,mode='numeric',blocked=(),hostname=None):
    from candidate import guard
    if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
    if len(addresses)>ANSWER_CAP:raise ValueError('DNS_ANSWER_CAP')
    body=json.dumps({'version':1,'deadline':deadline,'addresses':addresses,'delay':delay,'mode':mode,'blocked':blocked,'hostname':hostname},separators=(',',':')).encode()
    if len(body)>INPUT_CAP:raise ValueError('DNS_INPUT_CAP')
    start=time.monotonic();cid=uuid.uuid4().hex[:16];trace=Trace.current
    if trace:trace.emit(cid,'DNS_HELPER','BEGIN',code='BEGIN',inputBytes=len(body),callerThreads=__import__('threading').active_count())
    proc=None;selector=None;output=bytearray();offset=0;terminated=False;failure=True
    try:
        proc=subprocess.Popen([sys.executable,'/poc/dns_helper.py'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
               stderr=subprocess.DEVNULL,close_fds=True,start_new_session=True)
        receipt['dnsPID']=proc.pid
        if trace:
            startTicks=__import__('pathlib').Path('/proc',str(proc.pid),'stat').read_text().split(')',1)[1].split()[19]
            ownerFile=trace.path.with_name(trace.path.stem+'-helper-owners.jsonl')
            with ownerFile.open('a') as f:f.write(json.dumps({'parentPID':os.getpid(),'helperPID':proc.pid,'startTicks':startTicks})+'\n')
        selector=selectors.DefaultSelector()
        for pipe in (proc.stdin,proc.stdout):os.set_blocking(pipe.fileno(),False)
        selector.register(proc.stdin,selectors.EVENT_WRITE);selector.register(proc.stdout,selectors.EVENT_READ)
        eof=False
        while not eof or proc.poll() is None:
            if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
            for key,events in selector.select(0):
                if key.fileobj is proc.stdin:
                    try:offset+=os.write(proc.stdin.fileno(),body[offset:offset+4096])
                    except BrokenPipeError:offset=len(body)
                    if offset==len(body):selector.unregister(proc.stdin);proc.stdin.close()
                else:
                    chunk=os.read(proc.stdout.fileno(),min(4096,OUTPUT_CAP+1-len(output)))
                    output.extend(chunk)
                    if len(output)>OUTPUT_CAP:raise ValueError('DNS_RESPONSE_CAP')
                    if not chunk:selector.unregister(proc.stdout);eof=True
            if not eof or proc.poll() is None:await asyncio.sleep(min(.01,max(0,deadline-time.monotonic())))
        if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
        if proc.returncode!=0:raise OSError('DNS_CHILD_EXIT')
        response=json.loads(output)
        receipt.update(inheritanceClean=response.get('unexpectedInherited')==0,helperThreads=response.get('threads'))
        if response.get('unexpectedInherited')!=0:raise RuntimeError('DNS_FD_INHERITED')
        if response.get('status')!='OK':
            if response.get('code')=='DEADLINE':raise TimeoutError('SETUP_DEADLINE')
            raise OSError('DNS_ERROR')
        rows=response.get('answers')
        if not isinstance(rows,list) or len(rows)>ANSWER_CAP:raise ValueError('DNS_ANSWER_CAP')
        rows=[(a[0],a[1],a[2],a[3],tuple(a[4])) for a in rows]
        guarded=guard(rows);failure=False;return guarded
    finally:
        if selector:selector.close()
        if proc:
            for pipe in (proc.stdin,proc.stdout):
                if pipe:pipe.close()
            if proc.poll() is None:
                try:os.killpg(proc.pid,signal.SIGTERM);terminated=True
                except ProcessLookupError:pass
                try:proc.wait(timeout=min(.2,max(.001,deadline+1-time.monotonic())))
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=.2)
            else:proc.wait(timeout=0)
            left=group_left(proc.pid)
            receipt.update(dnsElapsed=time.monotonic()-start,dnsChildReaped=proc.poll() is not None,dnsExit=proc.returncode,
                dnsGroupLeft=left,dnsPipesClosed=proc.stdin.closed and proc.stdout.closed,responseBytes=len(output),inputBytes=len(body),
                inputCap=INPUT_CAP,responseCap=OUTPUT_CAP,answerCap=ANSWER_CAP,terminated=terminated)
            if left:raise RuntimeError('DNS_GROUP_LEFT')
        if trace:trace.emit(cid,'DNS_HELPER','ERROR' if failure else 'END',time.monotonic()-start,
                          code='ERROR' if failure else 'OK',responseBytes=len(output),childReaped=bool(proc and proc.poll() is not None))
