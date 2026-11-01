"""Bounded internal phase proofs. No source permissions, log/PID authority or DB."""
import base64,hmac,http.server,ipaddress,json,os,re,secrets,socket,threading,time
from .dns_admission import strict_loads
HEX=re.compile(r'[a-f0-9]{64}')
def hex64(value):return type(value) is str and HEX.fullmatch(value) is not None
def credentials(headers):
    values=headers.get_all('Proxy-Authorization',[])
    if not values:return None
    if len(values)!=1 or not values[0].startswith('Basic ') or len(values[0])>256:raise ValueError('PHASE_AUTH')
    try:a,b=base64.b64decode(values[0][6:],validate=True).decode('ascii').split(':')
    except (ValueError,UnicodeError):raise ValueError('PHASE_AUTH') from None
    if not hex64(a) or not hex64(b):raise ValueError('PHASE_AUTH')
    return a,b

class Broker:
    def __init__(self):
        self.lock=threading.RLock();self.entries={};self.limit=64
        self.secret=os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET','');self.networks=[]
        try:
            for value in os.environ.get('TIKTOK_EGRESS_CONTROL_NETWORKS','').split(','):
                net=ipaddress.ip_network(value,strict=True)
                internal=[ipaddress.ip_network(n) for n in ('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16','127.0.0.0/8','fc00::/7','::1/128')]
                if not any(net.version==n.version and net.subnet_of(n) for n in internal):raise ValueError('INTERNAL_ONLY')
                self.networks.append(net)
        except ValueError:self.networks=[]
        self.enabled=bool(hex64(self.secret) and self.networks)
    def authorize(self,request,headers):
        if not self.enabled:return False
        try:
            peer=ipaddress.ip_address(request.getpeername()[0]);local=ipaddress.ip_address(request.getsockname()[0])
            values=headers.get_all('Authorization',[])
            return any(peer in n and local in n for n in self.networks) and len(values)==1 and hmac.compare_digest(values[0],'Bearer '+self.secret)
        except (ValueError,OSError):return False
    def tick(self):
        cancel=[];now=time.monotonic()
        with self.lock:
            for key,e in list(self.entries.items()):
                if now>=e['end']:
                    e['expired']=True;e['cap']=''
                    cancel.extend(v['ctx'] for v in e['members'].values() if v['ctx'] is not None)
                    for member in e['members'].values():
                        ctx=member['ctx'];worker=getattr(ctx,'_worker_thread',None) if ctx else None
                        if worker is not None and not worker.is_alive() and ctx.client.fileno()==-1 and ctx.loop_closed and ctx.registry.live()==0 and not ctx.registry.pending:
                            worker.join(0);member.update(ctx=None,accepted=False)
                    if now>=e['end']+5 and not any(v['ctx'] is not None for v in e['members'].values()):del self.entries[key]
        for ctx in cancel:
            ctx.cancel.set()
            try:ctx.client.shutdown(socket.SHUT_RDWR)
            except OSError:pass
    def reply(self,p,e,state):
        reply=dict(v=p.get('v',1),id=p['id'],job=p['job'],phase=p['phase'],epoch=e['epoch'] if e else p.get('epoch',''),state=state,connections=len(e['members']) if e else 0)
        if p.get('v')==2:reply.update(profile=p['profile'],selection=p['selection'])
        return reply
    def state(self,e):
        if e['expired']:return 'EXPIRED'
        if e['failed'] or e['consumed']:return 'REJECTED'
        if not e['sealed']:return 'OPEN'
        if not e['members']:return 'REJECTED'
        if any(v['ctx'] is not None for v in e['members'].values()):return 'PENDING'
        return 'ACCEPTED' if all(v['accepted'] is True for v in e['members'].values()) else 'REJECTED'
    def command(self,p):
        self.tick()
        if type(p) is not dict or p.get('op') not in ('open','seal','poll','take','abort'):raise ValueError('CONTROL_SCHEMA')
        keys={'op','id','job','phase'}|({'deadline'} if p['op']=='open' else {'epoch'})
        pair=p.get('v')==2
        if pair:
            keys|={'v','profile','selection'}
            profile_ok=(p.get('profile')=='hevc-copy-pair' and p.get('phase')=='prepare' and type(p.get('selection')) is str and re.fullmatch(r'tt2_[a-f0-9]{64}',p['selection']))
            short_ok=(p.get('profile')=='tiktok-short-analyze' and p.get('phase')=='analyze' and type(p.get('selection')) is str and re.fullmatch(r'ts1_[a-f0-9]{64}',p['selection']))
            preview_ok=(os.environ.get('TIKTOK_PREVIEW_ENABLED')=='1' and p.get('profile')=='tiktok-preview-cache' and p.get('phase')=='analyze'
                and type(p.get('selection')) is str and re.fullmatch(r'pv1_([1-9]|[1-4][0-9]|50)_[a-f0-9]{64}',p['selection']))
            if type(p['v']) is not int or not (profile_ok or short_ok or preview_ok):raise ValueError('CONTROL_PROFILE')
        if set(p)!=keys or not hex64(p['id']) or not hex64(p['job']) or p['phase'] not in ('analyze','prepare') or (p['op']!='open' and not hex64(p['epoch'])):raise ValueError('CONTROL_SCHEMA')
        with self.lock:
            e=self.entries.get(p['id'])
            if p['op']=='open':
                if e or len(self.entries)>=self.limit:return self.reply(p,None,'REJECTED')
                cap=30 if p['phase']=='analyze' else 180
                remaining=(p['deadline']-time.time()*1000)/1000 if type(p['deadline']) is int else -1
                if not 0<remaining<=cap+.1:return self.reply(p,None,'EXPIRED')
                e=dict(job=p['job'],phase=p['phase'],epoch=secrets.token_hex(32),cap=secrets.token_hex(32),end=time.monotonic()+min(cap,remaining),
                    expired=False,sealed=False,consumed=False,failed=False,members={},queries=0,
                    profile=p.get('profile'),selection=p.get('selection'))
                self.entries[p['id']]=e
                return dict(self.reply(p,e,'OPEN'),connectKey=e['cap'])
            if not e:return self.reply(p,None,'UNKNOWN')
            if p['job']!=e['job'] or p['phase']!=e['phase'] or p['epoch']!=e['epoch']:return self.reply(p,None,'REJECTED')
            if p.get('profile')!=e['profile'] or p.get('selection')!=e['selection']:return self.reply(p,None,'REJECTED')
            e['queries']+=1
            if e['queries']>28:e['failed']=True
            if p['op']=='seal':
                if e['sealed']:e['failed']=True
                e['sealed']=True;e['cap']=''
            if p['op']=='abort':
                e['failed']=True;e['sealed']=True;e['cap']=''
                for member in e['members'].values():
                    ctx=member['ctx']
                    if ctx is not None:
                        ctx.cancel.set()
                        try:ctx.client.shutdown(socket.SHUT_RDWR)
                        except OSError:pass
            state=self.state(e);reply=self.reply(p,e,state)
            if p['op']=='take' and state=='ACCEPTED':e['consumed']=True
            return reply
    def attach(self,auth,ctx):
        if auth is None:return
        self.tick();key,cap=auth
        with self.lock:
            e=self.entries.get(key)
            if not self.enabled or not e or e['expired'] or e['sealed'] or e['failed'] or not hmac.compare_digest(e['cap'],cap):raise ValueError('PHASE_DENIED')
            cap=4 if e['profile'] in ('hevc-copy-pair','tiktok-short-analyze') else 2 if e['phase']=='analyze' else 3
            if e['profile']=='tiktok-preview-cache':cap=int(e['selection'].split('_')[1])
            if len(e['members'])>=cap:e['failed']=True;raise ValueError('PHASE_OVERFLOW')
            if ctx.cid in e['members']:e['failed']=True;raise ValueError('PHASE_REPLAY')
            e['members'][ctx.cid]=dict(ctx=ctx,accepted=None);ctx._phase_key=key
    def finish(self,ctx,result):
        key=getattr(ctx,'_phase_key',None)
        if key is None:return
        with self.lock:
            e=self.entries.get(key)
            if e is None:return
            member=e['members'].get(ctx.cid)
            if member is None or member['ctx'] is not ctx:e['failed']=True;return
            accepted=(type(result) is dict and result.get('ownerID')==ctx.cid and result.get('accepted') is True
                and result.get('workerThreadClosed') is True and result.get('clientClosed') is True and result.get('loopClosed') is True
                and result.get('traceIncomplete') is False and result.get('validation',{}).get('accepted') is True
                and ctx.client.fileno()==-1 and ctx.loop_closed and not ctx.failed and not ctx.trace.incomplete
                and ctx.registry.live()==0 and not ctx.registry.pending and not ctx.registry.reap_failed
                and ctx.dns.get('dnsExit')==0 and ctx.dns.get('dnsChildReaped') is True and ctx.dns.get('dnsGroupLeft')==0)
            member.update(ctx=None,accepted=bool(accepted))

class ControlHandler(http.server.BaseHTTPRequestHandler):
    """Reuse stdlib HTTP parser with the CONNECT handler's bounded first line/streams."""
    def __init__(self,outer,line):
        self.outer=outer;self.line=line
        super().__init__(outer.request,outer.client_address,outer.server)
    def setup(self):
        self.connection=self.request;self.wfile=self.outer.wfile
        class BoundedHeaders:
            def __init__(self,base):self.base=base;self.bytes=0
            def readline(self,limit=-1):
                data=self.base.readline(min(4097,limit) if limit>=0 else 4097);self.bytes+=len(data)
                if len(data)>4096 or self.bytes>16384:raise ValueError('CONTROL_HEADERS')
                return data
            def read(self,n):return self.base.read(n)
        self.rfile=BoundedHeaders(self.outer.rfile)
    def finish(self):pass # Outer StreamRequestHandler owns physical stream closure.
    def log_message(self,*args):pass
    def handle_one_request(self):
        self.raw_requestline=self.line
        if not self.parse_request():return
        self.close_connection=True
        if self.command!='POST' or self.path!='/_wed/phase':return self.answer(403,dict(error='DENIED'))
        self.do_POST()
    def answer(self,status,value):
        data=json.dumps(value,separators=(',',':'),allow_nan=False).encode()
        if len(data)>2048:status=403;data=b'{"error":"DENIED"}'
        self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.send_header('Connection','close');self.end_headers();self.wfile.write(data)
    def do_POST(self):
        broker=getattr(self.server,'phase_broker',None)
        if broker is None or not broker.authorize(self.request,self.headers):return self.answer(403,dict(error='DENIED'))
        try:
            lengths=self.headers.get_all('Content-Length',[])
            if len(lengths)!=1 or not lengths[0].isdigit() or not 0<int(lengths[0])<=1024 or self.headers.get('Transfer-Encoding'):raise ValueError('CONTROL_SIZE')
            raw=self.rfile.read(int(lengths[0]))
            if len(raw)!=int(lengths[0]):raise ValueError('CONTROL_SIZE')
            self.answer(200,broker.command(strict_loads(raw)))
        except Exception:self.answer(403,dict(error='DENIED'))
