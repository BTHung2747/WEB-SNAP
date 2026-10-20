"""Best-effort lifecycle observer; cleanup and fail-closed evidence are separate."""
import contextlib,importlib.util,json,math,pathlib,threading,time,uuid,re
def remaining(deadline):return max(0,deadline-time.monotonic())
class DiagnosticIncomplete(RuntimeError):pass
class MemoryFile:
    def __init__(self):self.rows=[];self.bytes=0;self.closed=False
    def write(self,text):
        if self.closed or self.bytes+len(text.encode())>128*1024:raise DiagnosticIncomplete('TRACE_BYTE_CAP')
        self.rows.append(json.loads(text));self.bytes+=len(text.encode());return len(text)
    def flush(self):pass
    def close(self):self.closed=True
class MemoryIO:
    def open(self,path):return MemoryFile()
    def write(self,file,text):return file.write(text)
    def flush(self,file):return file.flush()
    def close(self,file):return file.close()
class FileOps:
    def open(self,path):return path.open('a')
    def write(self,file,text):return file.write(text)
    def flush(self,file):return file.flush()
    def close(self,file):return file.close()
class Trace:
    def __init__(self,path=None,io=None):
        self.path=path;self.total_cap=256;self.connection_cap=32;self.count=0;self.incomplete=False
        self.lock=threading.RLock();self.counts={};self.file=None;self.owned_files=[]
        self.io=io or MemoryIO();self.attempted=0;self.dropped=0
        self.held={};self.groups_held={};self.connections={};self.operation_counts={};self.operation_open={}
    def _capacity(self,add):
        owners=set(self.counts)|set(self.held)|set(add)
        return (not self.incomplete and len(owners)<=64 and self.count+sum(sum(x.values()) for x in self.held.values())+sum(sum(x.values()) for x in add.values())<=256
                and all(self.counts.get(k,0)+sum(self.held.get(k,{}).values())+sum(add.get(k,{}).values())<=32 for k in owners))
    def attach_connection(self,registry,ctx):
        with self.lock:
            if registry in self.connections:return self.connections[registry]==ctx
            if registry==ctx:return False
            # Existing ctx rows are lifecycle snapshots before TCP starts.
            add={registry:{'close':4},ctx:{'lifecycle':max(0,12-self.counts.get(ctx,0))}}
            if not self._capacity(add):return False
            for cid,fields in add.items():
                target=self.held.setdefault(cid,{})
                for kind,n in fields.items():target[kind]=target.get(kind,0)+n
            self.connections[registry]=ctx;return True
    def group_capacity(self,registry,ctx,size):
        with self.lock:
            count=0
            for groups in range(1,5):
                add={registry:{'socket':2*size*groups,'select':2*groups},ctx:{'tcp':2*size*groups}}
                if self._capacity(add):count=groups
                else:break
            return count
    def admit_group(self,registry,ctx,size):
        with self.lock:
            if registry in self.groups_held:return False
            add={registry:{'socket':2*size,'select':2},ctx:{'tcp':2*size}}
            if not self._capacity(add):return False
            for cid,fields in add.items():
                target=self.held.setdefault(cid,{})
                for kind,n in fields.items():target[kind]=target.get(kind,0)+n
            self.groups_held[registry]=ctx;return True
    def release_group(self,registry,ctx):
        with self.lock:
            # Caller only releases after library tasks reaped/losers physically closed.
            for cid,kinds in ((registry,('socket','select')),(ctx,('tcp',))):
                for kind in kinds:self.held.get(cid,{}).pop(kind,None)
            self.groups_held.pop(registry,None)
    @property
    def rows(self):return self.count
    def mark_incomplete(self):
        with self.lock:self.incomplete=True;self.dropped=min(65535,self.dropped+1)
    def emit(self,cid,phase,event,elapsed=0,code='OK',**numbers):
        with self.lock:
            self.attempted=min(65535,self.attempted+1)
            try:
                valid=(event in ('BEGIN','END','ERROR') and phase.isupper() and code.isupper()
                       and type(elapsed) in (int,float) and math.isfinite(elapsed) and elapsed>=0
                       and all((isinstance(v,str) and re.fullmatch('[a-f0-9]{16}',v) is not None) if k=='contextOwnerID' else (type(v) in (bool,int,float) and (type(v)==bool or math.isfinite(v))) for k,v in numbers.items()))
                if not valid or self.incomplete or self.count>=self.total_cap or self.counts.get(cid,0)>=self.connection_cap or cid not in self.counts and len(self.counts)>=64:
                    self.mark_incomplete();return False
                from .operation_coverage import PAIRED,SNAPSHOTS
                operation=None
                if phase in PAIRED:
                    tcp=phase in ('TCP_CONNECT','FIXTURE_TCP')
                    index=numbers.get('index') if tcp else None
                    if tcp and (type(index) is not int or not 1<=index<=64):self.mark_incomplete();return False
                    key=(cid,phase,index) if tcp else (cid,phase)
                    if event=='BEGIN':
                        if key in self.operation_open:self.mark_incomplete();return False
                        operation=index if tcp else self.operation_counts.get(key,0)+1
                        self.operation_counts[key]=operation;self.operation_open[key]=operation
                    else:
                        operation=self.operation_open.pop(key,None)
                        if operation is None:self.mark_incomplete();return False
                elif phase not in SNAPSHOTS or event!='END':self.mark_incomplete();return False
                kind='socket' if phase=='SOCKET_CREATE' else 'select' if phase=='LIBRARY_SELECT' else 'tcp' if phase in ('TCP_CONNECT','FIXTURE_TCP') else 'close' if phase=='REGISTRY_CLOSE' else 'lifecycle'
                reserved=self.held.get(cid,{}).get(kind,0)
                if reserved:self.held[cid][kind]-=1
                elif self.count+sum(sum(x.values()) for x in self.held.values())>=256 or self.counts.get(cid,0)+sum(self.held.get(cid,{}).values())>=32:
                    self.mark_incomplete();return False
                row={'ownerID':cid,'phase':phase,'event':event,'code':code,'elapsed':elapsed,**numbers}
                if operation is not None:row['operationIndex']=operation
                if self.file is None:self.file=self.io.open(self.path);self.owned_files.append(self.file)
                self.io.write(self.file,json.dumps(row)+'\n');self.io.flush(self.file)
                self.count+=1;self.counts[cid]=self.counts.get(cid,0)+1;return True
            except Exception:self.mark_incomplete();return False
    def observe(self,*a,**k):
        try:return self.emit(*a,**k)
        except BaseException:self.mark_incomplete();return False
    @contextlib.contextmanager
    def phase(self,cid,phase,**numbers):
        started=time.monotonic();self.observe(cid,phase,'BEGIN',code='BEGIN',**numbers)
        try:yield
        except BaseException:self.observe(cid,phase,'ERROR',time.monotonic()-started,code='ERROR');raise
        else:self.observe(cid,phase,'END',time.monotonic()-started,**numbers)
    def summary(self):return {'rows':self.count,'totalCap':256,'connectionCap':32,'owners':len(self.counts),'incomplete':self.incomplete,'attempted':self.attempted,'dropped':self.dropped,'reservedRows':sum(sum(x.values()) for x in self.held.values()),'pendingGroups':len(self.groups_held),'openOperations':len(self.operation_open)}
    def close(self):
        with self.lock:
            if self.groups_held or self.operation_open:self.mark_incomplete()
            self.held.clear()
            if self.file is not None:
                try:self.io.close(self.file)
                except BaseException:self.mark_incomplete()
            for file in self.owned_files:
                try:file.close()
                except BaseException:self.mark_incomplete()
