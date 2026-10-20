"""AGPL-3.0 lab-only entrypoint. Existing proxy delegates DNS/TCP/CONNECT unchanged."""
import json,os,pathlib,signal,sys,threading,time
sys.path.insert(0,'/trace_lab')
import egress_trace as proxy
from trace import TraceSink
from common import inventory,versions
sys.excepthook=lambda *a:print('PROXY_ENTRY_FAILURE',flush=True)
OUT=pathlib.Path('/out')
class ReceiptSink(TraceSink):
    def __init__(self,path):
        super().__init__(path);self.condition=threading.Condition();self.active=0
        self.entries={};self.connection_count=0;self.unhandled=0;self.publish_lock=threading.Lock()
    def connection(self):
        con=super().connection()
        with self.condition:
            self.connection_count+=1
            if len(self.entries)<64:self.entries[con.id]={'connectionID':con.id,'rows':0,'incomplete':False,'closedRecorded':False}
            else:self.incomplete=True
        return con
    def emit(self,row,con):
        before=con.count;super().emit(row,con)
        with self.condition:
            if con.id in self.entries:
                entry=self.entries[con.id];entry['rows']=con.count;entry['incomplete']=con.incomplete
                if row['boundary']=='TUNNEL_CLOSE' and row['event']=='END' and con.count>before:entry['closedRecorded']=True
        self.publish()
    def publish(self):
        try:
            with self.publish_lock:
                with self.condition:
                    health={'rows':self.count,'incomplete':self.incomplete,'totalCap':256,'connectionCap':32,'uid':os.geteuid()}
                temp=self.path.parent/'proxy-health.tmp'
                with temp.open('w') as f:json.dump(health,f)
                os.replace(temp,self.path.parent/'proxy-health.json')
        except OSError:self.incomplete=True
    def enter(self):
        with self.condition:self.active+=1
    def leave(self):
        with self.condition:self.active-=1;self.condition.notify_all()
    def final(self,grace=15):
        limit=time.monotonic()+grace
        with self.condition:
            while self.active and time.monotonic()<limit:self.condition.wait(max(0,limit-time.monotonic()))
            return {'final':True,'rows':self.count,'incomplete':self.incomplete or self.active!=0 or self.unhandled!=0,
                    'active':self.active,'unhandled':self.unhandled,'connectionCount':self.connection_count,
                    'totalCap':self.total_cap,'connectionCap':self.connection_cap,'connections':list(self.entries.values()),
                    'uid':os.geteuid(),'shutdownGraceSeconds':grace,'TLSDetail':'UNKNOWN','clientCorrelation':'UNKNOWN'}
class Handler(proxy.Handler):
    def handle(self):
        proxy.TRACE.enter()
        try:return super().handle()
        finally:proxy.TRACE.leave()
class Server(proxy.Server):
    def handle_error(self,*a):
        proxy.TRACE.unhandled+=1;proxy.TRACE.incomplete=True
def main():
    stage=os.environ.get('PHOTO_TRACE_STAGE')
    if stage not in ('offline','live'):raise RuntimeError('STAGE_POLICY')
    assert sys.version.split()[0]=='3.11.2' and os.geteuid()==65534
    runtime={'python':sys.version.split()[0],'versions':versions(),'sources':inventory(),'uid':os.geteuid()}
    with (OUT/'proxy-runtime.json').open('x') as f:json.dump(runtime,f)
    proxy.TRACE=ReceiptSink(OUT/'proxy-trace.jsonl')
    proxy.TRACE.publish()
    fixture=None
    if stage=='offline':
        from fixture_origin import Fixture
        fixture=Fixture(OUT);proxy.socket=fixture.socket_api
    stop=threading.Event()
    signal.signal(signal.SIGTERM,lambda *a:stop.set());signal.signal(signal.SIGINT,lambda *a:stop.set())
    server=Server(('0.0.0.0',8888),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    with (OUT/'proxy-ready.json').open('x') as f:json.dump({'ready':True,'uid':os.geteuid(),'stage':stage,'fixture':stage=='offline'},f)
    stop.wait()
    server.shutdown();server.server_close() # shutdown runs outside serve_forever's thread.
    summary=proxy.TRACE.final()
    with (OUT/'proxy-summary.json').open('x') as f:json.dump(summary,f,indent=2)
    if fixture:fixture.close()
    return 0 if not summary['incomplete'] else 30
if __name__=='__main__':sys.exit(main())

