"""Explicit offline dependency facade; reuse existing photo fixture bodies and JPEG generator.
No production DNS/TLS/HTTP implementation. No fixture imports in live stage.
"""
import http.server,importlib.util,io,json,os,pathlib,socket,socketserver,ssl,subprocess,sys,threading,time,types
import requests
from ownership import server_class,stop_server
REAL_SOCKET=socket
OUT=None
PUBLIC_META='1.1.1.1';PUBLIC_IMAGE='1.0.0.1'
class Fixture:
    def __init__(self,out,owners,trace,deadline):
        self.out=out;self.providers={};self.lock=threading.Lock()
        self.owners=owners;self.trace=trace;self.deadline=deadline;self.serverThreads=[];self.stallStop=threading.Event()
        self.media=pathlib.Path('/tmp/fixture.jpg')
        p=subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc=size=64x64','-frames:v','1','-threads','1','-c:v','mjpeg',str(self.media)],
                         stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
        assert p.returncode==0
        self.cert=pathlib.Path('/tmp/fixture.pem');self.key=pathlib.Path('/tmp/fixture.key')
        self.badcert=pathlib.Path('/tmp/bad.pem');self.badkey=pathlib.Path('/tmp/bad.key')
        for cert,key in ((self.cert,self.key),(self.badcert,self.badkey)):
            p=subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=www.tiktok.com',
                '-addext','subjectAltName=DNS:www.tiktok.com,DNS:media.tiktokcdn.com','-keyout',str(key),'-out',str(cert)],
                stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=10)
            assert p.returncode==0
        # Fixture CA only: retain original trust bundle plus ephemeral self-signed fixture cert.
        import certifi
        with (out/'fixture-ca.pem').open('x') as f:f.write(pathlib.Path(certifi.where()).read_text()+'\n'+self.cert.read_text())
        owner=self
        class Origin(http.server.BaseHTTPRequestHandler):
            protocol_version='HTTP/1.1'
            def log_message(self,*a):pass
            def do_GET(self):
                control=owner.control();case=control['case'];mode=control.get('mode','normal')
                with owner.lock:
                    provider=owner.provider(case,mode)
                    url='https://'+self.headers['Host']+self.path # RAM only; library fixture owns body, no logging.
                    prepared=requests.Request('GET',url,headers=dict(self.headers)).prepare()
                    # The reused fixture reads its media path at send time, not at module load.
                    # Scope that existing environment contract to this serialized offline provider call.
                    old_media=os.environ.get('FIXTURE_MEDIA_FILE');os.environ['FIXTURE_MEDIA_FILE']=str(owner.media)
                    try:reply=provider.send_fixture(prepared,stream=True,verify=True,proxies={'http':'http://egress:8888','https':'http://egress:8888'})
                    finally:
                        if old_media is None:os.environ.pop('FIXTURE_MEDIA_FILE',None)
                        else:os.environ['FIXTURE_MEDIA_FILE']=old_media
                    body=reply.raw.read(decode_content=True);reply.close()
                    # Offline-only fault in the shared numeric receipt, after metadata body2 is built.
                    if provider.pages==2 and self.headers['Host']=='www.tiktok.com':
                        health=owner.out/'proxy-health.json'
                        if mode=='health-missing':health.unlink(missing_ok=True)
                        elif mode=='health-incomplete':
                            value=json.loads(health.read_text());value['incomplete']=True;health.write_text(json.dumps(value))
                    row={'case':case,'kind':'IMAGE_GET' if self.headers['Host']=='media.tiktokcdn.com' else 'METADATA_GET','status':reply.status_code,'bytes':len(body)}
                    with (owner.out/'origin-events.jsonl').open('a') as f:f.write(json.dumps(row)+'\n')
                self.send_response(reply.status_code)
                for k,v in reply.headers.items():self.send_header(k,v)
                self.end_headers();self.wfile.write(body)
        self.servers=[]
        for cert,key in ((self.cert,self.key),(self.badcert,self.badkey)):
            ServerType=server_class(http.server.ThreadingHTTPServer,owners)
            server=ServerType(('127.0.0.1',0),Origin);server.daemon_threads=True
            def safe_error(*a):
                error=sys.exc_info()[1]
                codes={KeyError:'FIXTURE_KEY_ERROR',AssertionError:'FIXTURE_ASSERT',OSError:'FIXTURE_IO',RuntimeError:'FIXTURE_RUNTIME'}
                with (owner.out/'fixture-errors.jsonl').open('a') as f:
                    f.write(json.dumps({'phase':'FIXTURE_ORIGIN','code':codes.get(type(error),'UNKNOWN')})+'\n')
            server.handle_error=safe_error
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
            server.socket=context.wrap_socket(server.socket,server_side=True)
            worker=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.05},daemon=True)
            worker.start();self.serverThreads.append(worker);self.servers.append(server)
        class Stall(socketserver.BaseRequestHandler):
            def handle(self):owner.stallStop.wait(12)
        class StallServer(socketserver.ThreadingTCPServer):
            daemon_threads=True
            def handle_error(self,*a):pass
        self.stall=server_class(StallServer,owners)(('127.0.0.1',0),Stall)
        worker=threading.Thread(target=self.stall.serve_forever,kwargs={'poll_interval':.05},daemon=True)
        worker.start();self.serverThreads.append(worker)
        dead=socket.socket();dead.bind(('127.0.0.1',0));self.closed_port=dead.getsockname()[1];dead.close()
        class RoutedSocket:
            def __init__(self,*args):self.base=socket.socket(*args)
            def __getattr__(self,k):return getattr(self.base,k)
            def connect(self,addr):
                mode=owner.control().get('mode','normal');image=addr[0]==PUBLIC_IMAGE
                if image and mode=='image-tcp-failure':port=owner.closed_port
                elif image and mode=='image-tls-stall':port=owner.stall.server_address[1]
                elif image and mode=='image-cert-failure':port=owner.servers[1].server_address[1]
                else:port=owner.servers[0].server_address[1]
                return self.base.connect(('127.0.0.1',port))
        class API:
            AF_INET=socket.AF_INET;AF_INET6=socket.AF_INET6;SOCK_STREAM=socket.SOCK_STREAM
            socket=RoutedSocket
            @staticmethod
            def getaddrinfo(host,port,type=REAL_SOCKET.SOCK_STREAM):
                mode=owner.control().get('mode','normal')
                if host not in ('www.tiktok.com','media.tiktokcdn.com'):raise socket.gaierror(-2,'FIXTURE_DNS_DENIED')
                if host=='media.tiktokcdn.com' and mode=='image-dns-failure':raise socket.gaierror(-2,'FIXTURE_DNS_FAILURE')
                if mode=='dns-private':return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))]
                return [(socket.AF_INET,socket.SOCK_STREAM,6,'',(PUBLIC_IMAGE if host=='media.tiktokcdn.com' else PUBLIC_META,443))]
        self.socket_api=API
    def control(self):
        return json.loads(pathlib.Path('/control/control.json').read_text())
    def provider(self,case,mode):
        if case in self.providers:return self.providers[case]
        url='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421'
        folder=self.out/'fixture-provider'/case;folder.mkdir(parents=True)
        control=self.out/'fixture-control'/case;control.mkdir(parents=True)
        mode='normal' if mode.startswith('observer-') else mode
        fixturemode='normal' if mode.startswith('image-') and mode not in ('image-html','image-oversize','image-timeout') or mode in ('dns-private','normal') else mode
        # Direct body timeout is covered by the existing network-none regression, not serialized HTTP.
        (control/'mode.json').write_text(json.dumps({'mode':fixturemode}))
        names=('TIKTOK_APP_FIXTURE','FIXTURE_MEDIA_FILE','FIXTURE_CONTROL')
        env={k:os.environ.get(k) for k in names};argv=sys.argv;session=requests.Session
        try:
            os.environ.update(TIKTOK_APP_FIXTURE='1',FIXTURE_MEDIA_FILE=str(self.media),FIXTURE_CONTROL=str(self.out/'fixture-control'))
            sys.argv=['worker.py','analyze',url,str(folder),'7678209751167110421']
            spec=importlib.util.spec_from_file_location('photo_fixture_provider','/app/apps/media/src/tiktok/photo_lab/sitecustomize.py')
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            fixture=vars(module)
        finally:
            requests.Session=session;sys.argv=argv
            for k,v in env.items():
                if v is None:os.environ.pop(k,None)
                else:os.environ[k]=v
        provider=fixture['FakeSession']();provider.trust_env=False
        self.providers[case]=provider;return provider
    def close(self):
        self.stallStop.set()
        for s,t in zip(self.servers+[self.stall],self.serverThreads):stop_server(s,t,self.trace,self.deadline)

