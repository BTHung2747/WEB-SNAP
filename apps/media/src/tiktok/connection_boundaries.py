# AGPL-3.0 lab observer: documented adapter/pool/connection extension points only.
import contextlib,contextvars,json,math,os,pathlib,time,uuid
import requests,urllib3
from urllib3.connection import HTTPConnection,HTTPSConnection
from urllib3.connectionpool import HTTPConnectionPool,HTTPSConnectionPool
from .send_diagnostics import classify
ACTIVE=contextvars.ContextVar('wed_boundary_request',default=None)
BOUNDARIES={'CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS'}
def number(value):
    return value if type(value) in (int,float) and math.isfinite(value) and value>=0 else 'UNKNOWN'

class BoundaryObserver:
    def __init__(self,sink='tiktok-boundaries.jsonl',root=None):
        root=pathlib.Path(root).resolve() if root is not None else pathlib.Path('/media')
        self.path=root/sink;self.count=0;self.incomplete=False
        if self.path.parent!=root or not sink.endswith('.jsonl') or self.path.is_symlink():raise ValueError('OBSERVER_PATH_POLICY')
    def emit(self,event):
        if self.count>=128:self.incomplete=True;return
        self.count+=1
        try:
            fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_APPEND|os.O_NOFOLLOW,0o600)
            with os.fdopen(fd,'a',encoding='utf8') as f:f.write(json.dumps(event,separators=(',',':'))+'\n')
        except OSError:self.incomplete=True # Diagnostics never replace a library exception/behavior.
    @contextlib.contextmanager
    def request(self,row,phase):
        summary={'requestID':uuid.uuid4().hex[:16],'connectionID':'UNKNOWN','reused':False,'terminal':[],
                 'incomplete':False}
        row['boundaries']=summary
        token=ACTIVE.set((self,summary,phase if phase in ('metadata','prepare') else 'UNKNOWN'))
        try:yield
        finally:summary['incomplete']=summary['incomplete'] or self.incomplete;ACTIVE.reset(token)

class ConnectionObserverMixin:
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        self.boundary_connection_id=uuid.uuid4().hex[:16]
        self.boundary_last_setup_request=None
    def boundary_call(self,name,method,*args,**kwargs):
        context=ACTIVE.get()
        if context is None:return method(*args,**kwargs)
        observer,summary,phase=context;summary['connectionID']=self.boundary_connection_id
        if name=='REQUEST_SEND':
            # Public is_closed query; no socket data, probes or changes to TLS/HTTP state.
            summary['reused']=not self.is_closed and self.boundary_last_setup_request is not None and self.boundary_last_setup_request!=summary['requestID']
        start=time.monotonic()
        event={'requestID':summary['requestID'],'connectionID':self.boundary_connection_id,'phase':phase,
               'boundary':name,'event':'BEGIN','elapsed':0,'timeout':number(self.timeout),'code':'BEGIN','classes':[]}
        observer.emit(event.copy())
        try:result=method(*args,**kwargs)
        except Exception as error:
            event['event']='ERROR';event['code'],event['classes']=classify(error)
            raise
        else:
            event.update(event='END',code='OK')
            if name=='CONNECTION_SETUP':self.boundary_last_setup_request=summary['requestID']
            return result
        finally:
            event['elapsed']=round(time.monotonic()-start,6);observer.emit(event.copy())
            if len(summary['terminal'])<6:
                summary['terminal'].append({k:event[k] for k in ('boundary','event','elapsed','timeout','code')})
            else:summary['incomplete']=True
    def connect(self):return self.boundary_call('CONNECTION_SETUP',super().connect)
    def request(self,*args,**kwargs):return self.boundary_call('REQUEST_SEND',super().request,*args,**kwargs)
    def getresponse(self):return self.boundary_call('RESPONSE_HEADERS',super().getresponse)

class ObservedHTTPConnection(ConnectionObserverMixin,HTTPConnection):pass
class ObservedHTTPSConnection(ConnectionObserverMixin,HTTPSConnection):pass
class ObservedHTTPPool(HTTPConnectionPool):ConnectionCls=ObservedHTTPConnection
class ObservedHTTPSPool(HTTPSConnectionPool):ConnectionCls=ObservedHTTPSConnection

def configure(manager):
    # Pinned PoolManager explicitly provides a local mapping for customization.
    # Copy it: never mutate urllib3's shared module mapping or any private method.
    manager.pool_classes_by_scheme={**manager.pool_classes_by_scheme,'http':ObservedHTTPPool,'https':ObservedHTTPSPool}

class ObservedAdapter(requests.adapters.HTTPAdapter):
    def init_poolmanager(self,*args,**kwargs):
        super().init_poolmanager(*args,**kwargs);configure(self.poolmanager)
    def proxy_manager_for(self,*args,**kwargs):
        manager=super().proxy_manager_for(*args,**kwargs);configure(manager);return manager
