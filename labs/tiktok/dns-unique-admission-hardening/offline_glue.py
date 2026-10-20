from tcp_observer import next_index,coverage
import asyncio,json,pathlib,time
from ownership import FileOps
from dns_ipc import resolve
CONTROL=pathlib.Path('/control/control.json')
def control():return json.loads(CONTROL.read_text())
class FaultIO(FileOps):
    def __init__(self,kind):self.kind=kind
    def open(self,path):
        if self.kind=='trace-open':raise OSError('FIXTURE_IO')
        return super().open(path)
    def write(self,file,text):
        if self.kind=='trace-write':raise OSError('FIXTURE_IO')
        return super().write(file,text)
    def close(self,file):
        if self.kind=='final-close-fail':raise OSError('FIXTURE_IO')
        return super().close(file)
class OfflineLoop(asyncio.SelectorEventLoop):
    def __init__(self,ctx,fixture):super().__init__();self.ctx=ctx;self.fixture=fixture;self.calls=0
    async def sock_connect(self,sock,address):
        index=next_index(self);mode=control()['mode'];image=address[0]=='1.0.0.1'
        cid=self.ctx.cid;trace=self.ctx.trace;start=time.monotonic()
        group=getattr(getattr(self.ctx,'registry',None),'group_index',0)
        if getattr(self.ctx,'registry',None):self.ctx.registry.worker_tasks.add(asyncio.current_task())
        trace.observe(cid,'FIXTURE_TCP','BEGIN',code='BEGIN',index=index,groupIndex=group)
        try:
            if mode=='batch-stall-third' and address[0].startswith('1.1.1.') and int(address[0].split('.')[-1])<=2:await asyncio.sleep(30)
            if mode in ('batch-fast7','batch-fast45','batch-fast64') and address[0].startswith('1.0.0.'):
                target=int(address[0].split('.')[-1]);winner={'batch-fast7':7,'batch-fast45':45,'batch-fast64':64}[mode]
                if target!=winner:raise ConnectionRefusedError('FIXTURE_REFUSED')
            if mode=='candidate-latency' and len(self.ctx.addresses)>1:
                await asyncio.sleep(10 if index==1 else .421074)
                if index==1:raise TimeoutError('FIXTURE_STALL')
            port=self.fixture.servers[0].server_address[1]
            if image and mode=='image-tcp-failure':port=self.fixture.closed_port
            elif image and mode=='image-cert-failure':port=self.fixture.servers[1].server_address[1]
            elif image and mode=='image-tls-stall':port=self.fixture.stall.server_address[1]
            if mode=='handoff-fail':raise ConnectionError('FIXTURE_HANDOFF')
            await super().sock_connect(sock,('127.0.0.1',port))
            trace.observe(cid,'FIXTURE_TCP','END',time.monotonic()-start,index=index,groupIndex=group)
        except asyncio.CancelledError:
            trace.observe(cid,'FIXTURE_TCP','ERROR',time.monotonic()-start,code='CANCELLED',index=index,groupIndex=group);raise
        except BaseException:
            trace.observe(cid,'FIXTURE_TCP','ERROR',time.monotonic()-start,code='ERROR',index=index,groupIndex=group);raise
def dns(ctx,host,settings,receipt):
    if settings['mode'] in ('dup65','mock129','unique65','bound257','private-tail','unicode-cap'):
        # Public Popen boundary redirects the owned helper ENTRYPOINT only in fixture.
        # Entire actual producer/parser/parent observer/deadline stays exercised.
        import subprocess,sys
        from unittest.mock import patch
        original=subprocess.Popen
        def fixture(args,**kwargs):
            return original([sys.executable,'/integration/inspection_fixture.py'],**kwargs)
        with patch('dns_ipc.subprocess.Popen',side_effect=fixture):
            return asyncio.run(resolve(0,[],ctx.end-1,receipt,mode='hostname',hostname=host))
    mode=settings['mode'];options={'mode':'hostname','hostname':host}
    delay=6.353045 if mode=='candidate-latency' else 0
    if mode=='dns-private':options['hostname']='localhost'
    elif mode=='image-dns-failure' and host=='media.tiktokcdn.com':options['mode']='error'
    elif mode=='helper-crash':options['mode']='crash'
    elif mode=='helper-cap':options['mode']='oversize'
    elif mode=='helper-late':options['mode']='late-reply';delay=30
    elif mode=='helper-answer-cap':options['mode']='answer-oversize'
    seed=[(2,1,6,'',('1.1.1.1',443))]
    if mode=='batch-stall-third' and host=='www.tiktok.com':
        seed=[(2,1,6,'',('1.1.1.'+str(i),443)) for i in range(1,4)];options={'mode':'numeric'}
    elif mode in ('batch-fast7','batch-fast45','batch-fast64') and host=='media.tiktokcdn.com':
        size={'batch-fast7':7,'batch-fast45':45,'batch-fast64':64}[mode]
        seed=[(2,1,6,'',('1.0.0.'+str(i),443)) for i in range(1,size+1)];options={'mode':'numeric'}
    if mode=='proxy-parent-block':
        async def blocked():
            task=asyncio.create_task(resolve(30,seed,ctx.end-1,receipt,**options))
            await asyncio.sleep(.1);time.sleep(30)
            return await task
        return asyncio.run(blocked())
    return asyncio.run(resolve(delay,seed,ctx.end-1,receipt,**options))
