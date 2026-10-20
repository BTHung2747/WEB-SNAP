"""Lab diagnostics only: bounded numeric events; never inspect exception strings or network contents."""
import contextvars,json,math,os,pathlib,socket,threading,time,uuid
CURRENT=contextvars.ContextVar('proxy_trace_connection',default=None)
BOUNDARIES={'DNS_LOOKUP','UPSTREAM_TCP_CONNECT','CONNECT_200_SENT','TUNNEL_CLOSE'}
LABELS={'BEGIN','OK','ERROR','UNKNOWN','IPv4','IPv6','OTHER','DNS_ERROR','TIMEOUT','CONNECTION_REFUSED',
        'CONNECTION_RESET','BROKEN_PIPE','OS_ERROR','POLICY_DENIED','PEER_EOF','TIME_BOUND','NOT_OPENED'}
CLASSES={socket.gaierror:'DNS_ERROR',TimeoutError:'TIMEOUT',ConnectionRefusedError:'CONNECTION_REFUSED',
         ConnectionResetError:'CONNECTION_RESET',BrokenPipeError:'BROKEN_PIPE',OSError:'OS_ERROR',ValueError:'POLICY_DENIED'}
def numeric(n):return n if type(n) in (int,float) and math.isfinite(n) and n>=0 else 'UNKNOWN'
class TraceSink:
    def __init__(self,path,total_cap=256,connection_cap=32):
        self.path=pathlib.Path(path);self.total_cap=total_cap;self.connection_cap=connection_cap
        self.count=0;self.incomplete=False;self.lock=threading.Lock()
    def connection(self):return ConnectionTrace(self)
    def emit(self,row,connection):
        # Observer I/O failure/cap never changes socket outcome, exception or timeout.
        with self.lock:
            if self.count>=self.total_cap or connection.count>=self.connection_cap:
                self.incomplete=True;connection.incomplete=True;return
            try:
                fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_APPEND|os.O_NOFOLLOW,0o600)
                with os.fdopen(fd,'a') as f:f.write(json.dumps(row,separators=(',',':'))+'\n')
                self.count+=1;connection.count+=1
            except OSError:self.incomplete=True;connection.incomplete=True
class ConnectionTrace:
    def __init__(self,sink):
        self.sink=sink;self.id=uuid.uuid4().hex[:16];self.count=0;self.incomplete=False
    def emit(self,boundary,event,elapsed=0,code='UNKNOWN',**fields):
        if boundary not in BOUNDARIES or event not in ('BEGIN','END','ERROR'):return
        row={'connectionID':self.id,'boundary':boundary,'event':event,'elapsed':numeric(elapsed),
             'code':code if code in LABELS else 'UNKNOWN'}
        # Only caller-owned numeric observations/fixed enum fields can leave RAM.
        for k,v in fields.items():
            if k in ('attemptIndex','timeoutSeconds','deadlineMonotonicSeconds','ipv4Count','ipv6Count'):
                row[k]=numeric(v)
            elif k=='family':row[k]=v if v in ('IPv4','IPv6','OTHER') else 'OTHER'
        self.sink.emit(row,self)
    def call(self,boundary,method,*args,after=None,**fields):
        start=time.monotonic()
        self.emit(boundary,'BEGIN',code='BEGIN',**fields)
        try:result=method(*args)
        except Exception as error:
            self.emit(boundary,'ERROR',time.monotonic()-start,CLASSES.get(type(error),'UNKNOWN'),**fields)
            raise # Exactly the delegate's exception; no message/repr/stack.
        else:
            values=after(result) if after is not None else {}
            self.emit(boundary,'END',time.monotonic()-start,'OK',**fields,**values)
            return result
def call(boundary,method,*args,after=None,**fields):
    connection=CURRENT.get()
    if connection is None:return method(*args)
    return connection.call(boundary,method,*args,after=after,**fields)
