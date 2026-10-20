"""Public Popen/selectors ownership glue; no host resolver or transport implementation."""
import asyncio,json,os,selectors,signal,subprocess,sys,time,uuid
import copy
from .ownership import Trace,DiagnosticIncomplete
from .dns_diagnostic import missing,observe,valid
from .dns_admission import strict_loads,packet_valid
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
async def resolve(hostname,deadline,receipt,*,trace,blocked=(),helper_path=None):
    from .candidate import guard
    if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
    cid=uuid.uuid4().hex[:16]
    body=json.dumps({'version':2,'expectedProtocol':4,'helperID':cid,'deadline':deadline,'blocked':blocked,'hostname':hostname},separators=(',',':')).encode()
    if len(body)>INPUT_CAP:raise ValueError('DNS_INPUT_CAP')
    start=time.monotonic()
    diagnostic=missing();receipt.update(dnsDiagnostic=diagnostic,dnsHelperID=cid,dnsAdmission=None)
    if trace:trace.observe(cid,'DNS_HELPER','BEGIN',code='BEGIN',inputBytes=len(body),callerThreads=__import__('threading').active_count())
    proc=None;selector=None;output=bytearray();offset=0;terminated=False;failure=True
    guarded=None;primary=None;cleanup_error=None
    try:
        proc=subprocess.Popen([sys.executable, str(helper_path)] if helper_path else [sys.executable,'-m','tiktok_policy.dns_helper'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
               stderr=subprocess.DEVNULL,close_fds=True,start_new_session=True)
        receipt['dnsPID']=proc.pid
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
        try:response=strict_loads(output)
        except (ValueError,UnicodeError):
            diagnostic['responseType']='MALFORMED_JSON'
            raise
        diagnostic.update(observe(response))
        if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
        receipt['dnsAdmission']=copy.deepcopy(diagnostic['admission'])
        # v4 has one admission object; no synthetic legacy fields.
        if diagnostic['helperID']!=cid:diagnostic['evidence']='PARTIAL'
        threads=response.get('threads')
        receipt.update(inheritanceClean=response.get('unexpectedInherited')==0,
                       helperThreads=threads if type(threads) is int and 1<=threads<=96 else None)
        if response.get('unexpectedInherited')!=0:raise RuntimeError('DNS_FD_INHERITED')
        if not packet_valid(response):raise DiagnosticIncomplete('DNS_RESPONSE_UNKNOWN')
        if response.get('status')!='OK':
            if response.get('code')=='DEADLINE':raise TimeoutError('SETUP_DEADLINE')
            if response.get('code')=='ANSWER_CAP':raise OSError('DNS_ANSWER_CAP')
            raise OSError('DNS_ERROR')
        rows=response.get('answers')
        if not isinstance(rows,list) or len(rows)>ANSWER_CAP:raise ValueError('DNS_ANSWER_CAP')
        rows=[(a[0],a[1],a[2],a[3],tuple(a[4])) for a in rows]
        guarded=guard(rows)
        if diagnostic['evidence']!='COMPLETE':raise DiagnosticIncomplete('DNS_RESPONSE_UNKNOWN')
        if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
        failure=False  # pending only: never return through finally
    except BaseException as exc:
        primary=exc
        raise
    finally:
        # Best effort ALL cleanup; never let a secondary exception replace primary.
        def attempt(action):
            nonlocal cleanup_error
            try:return action()
            except BaseException as exc:
                if cleanup_error is None:cleanup_error=exc
                return None
        if selector:attempt(selector.close)
        if proc:
            for pipe in (proc.stdin,proc.stdout):
                if pipe:attempt(pipe.close)
            def reap():
                nonlocal terminated
                if proc.poll() is None:
                    try:os.killpg(proc.pid,signal.SIGTERM);terminated=True
                    except ProcessLookupError:pass
                    try:proc.wait(timeout=min(.2,max(.001,deadline+1-time.monotonic())))
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=.2)
                else:proc.wait(timeout=0)
            attempt(reap)
            left=attempt(lambda:group_left(proc.pid))
            receipt.update(dnsElapsed=time.monotonic()-start,dnsChildReaped=proc.poll() is not None,dnsExit=proc.returncode,
                dnsGroupLeft=left,dnsPipesClosed=proc.stdin.closed and proc.stdout.closed,responseBytes=len(output),inputBytes=len(body),
                inputCap=INPUT_CAP,responseCap=OUTPUT_CAP,answerCap=ANSWER_CAP,rawCap=256,terminated=terminated)
            if left:cleanup_error=cleanup_error or RuntimeError('DNS_GROUP_LEFT')
        late=time.monotonic()>=deadline
        failure=failure or cleanup_error is not None or late
        # END/REAPED describes observation/closure, never a promise to return success.
        # The observer may itself consume the remaining time; authorization is later.
        if trace:attempt(lambda:trace.observe(cid,'DNS_HELPER','ERROR' if failure else 'END',time.monotonic()-start,
                          code='DEADLINE' if late and primary is None else 'ERROR' if failure else 'REAPED',
                          responseBytes=len(output),childReaped=bool(proc and proc.poll() is not None),
                          **({'nativeExit':proc.returncode} if proc and proc.poll() is not None else {})))
        diagnostic.update(elapsed=time.monotonic()-start,nativeExit=receipt.get('dnsExit'),
                          reaped=receipt.get('dnsChildReaped',False),pipesClosed=receipt.get('dnsPipesClosed',False),
                          groupsLeft=receipt.get('dnsGroupLeft'),resolution='FAIL')
        if cleanup_error is not None or trace is None or trace.incomplete or time.monotonic()>=deadline:
            diagnostic['evidence']='PARTIAL'
    # Primary exceptions re-raise through finally above, with identity/traceback kept.
    # Only pending success reaches this authorization boundary after all cleanup.
    if cleanup_error is not None:raise cleanup_error
    if time.monotonic()>=deadline:raise TimeoutError('SETUP_DEADLINE')
    if trace is None or trace.incomplete:raise DiagnosticIncomplete('DNS_TRACE_INCOMPLETE')
    diagnostic['resolution']='PASS'
    if not valid(diagnostic):
        diagnostic.update(evidence='PARTIAL',resolution='FAIL')
        raise DiagnosticIncomplete('DNS_CLOSURE_UNKNOWN')
    if time.monotonic()>=deadline:
        diagnostic.update(evidence='PARTIAL',resolution='FAIL')
        raise TimeoutError('SETUP_DEADLINE')
    return guarded
