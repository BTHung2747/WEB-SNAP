"""One owned ThreadingTCPServer request per DNS fault; no source hostname traffic."""
import asyncio,json,os,pathlib,socket,socketserver,threading,time,uuid
from dns_ipc import resolve,identity
from ownership import Requests,server_class,stop_server
def threaded_case(name,deadline,trace):
    mode=name.removeprefix('dns-thread-')
    infos=[(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))]
    owners=Requests(trace,deadline);receipt={'case':name,'sourceCalls':0,'fixture':True};done=threading.Event();stop=threading.Event()
    idle=threading.Thread(target=stop.wait);idle.start()
    opened=pathlib.Path('/tmp/owned-dns-trace.proof').open('wb');sentinelA,sentinelB=socket.socketpair()
    for fd in (opened.fileno(),sentinelA.fileno(),sentinelB.fileno()):os.set_inheritable(fd,True)
    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            receipt['callerThreads']=threading.active_count()
            os.set_inheritable(self.request.fileno(),True)
            descriptors=[opened.fileno(),sentinelA.fileno(),sentinelB.fileno(),self.request.fileno(),trace.file.fileno()]
            for fd in descriptors:os.set_inheritable(fd,True)
            blocked=[identity(fd) for fd in descriptors]
            async def call():
                rows=infos
                delay=30 if mode in ('cancel','deadline','late-reply','parent-block') else .03
                dns_mode={'success':'numeric','inheritance':'numeric','inputcap':'numeric','deadline':'numeric','cancel':'numeric'}.get(mode,mode)
                task=asyncio.create_task(resolve(delay,rows,deadline-1,receipt,mode=dns_mode,blocked=blocked*300 if mode=='inputcap' else blocked))
                if mode=='cancel':asyncio.get_running_loop().call_later(.15,task.cancel)
                if mode=='parent-block':
                    await asyncio.sleep(.1);time.sleep(30) # controlled event-loop block with owned helper alive.
                try:
                    answers=await task;assert len(answers)==1;receipt['outcome']='PASS'
                except asyncio.CancelledError:receipt['outcome']='CANCEL'
                except TimeoutError:receipt['outcome']='DEADLINE'
                except ValueError:receipt['outcome']='CONTRACT_REJECT'
                except OSError:receipt['outcome']='DNS_ERROR'
            try:asyncio.run(call())
            finally:done.set()
    Server=server_class(socketserver.ThreadingTCPServer,owners);Server.daemon_threads=True
    server=Server(('127.0.0.1',0),Handler);serve=threading.Thread(target=server.serve_forever,kwargs={'poll_interval':.05});serve.start()
    client=None
    try:
        client=socket.create_connection(('127.0.0.1',server.server_address[1]),timeout=min(10,max(.001,deadline-time.monotonic())))
        if not done.wait(max(0,deadline-time.monotonic())):raise TimeoutError('HANDLER_DEADLINE')
    finally:
        if client:client.close()
        stop_server(server,serve,trace,deadline);receipt['barrier']=owners.wait()
        stop.set();idle.join(max(0,deadline-time.monotonic()));opened.close();sentinelA.close();sentinelB.close()
    expected={'success':'PASS','inheritance':'PASS','error':'DNS_ERROR','crash':'DNS_ERROR',
       'oversize':'CONTRACT_REJECT','answer-oversize':'CONTRACT_REJECT','localhost':'CONTRACT_REJECT','inputcap':'CONTRACT_REJECT',
       'cancel':'CANCEL','deadline':'DEADLINE','late-reply':'DEADLINE'}[mode]
    assert receipt['outcome']==expected and receipt['callerThreads']>=3
    if receipt.get('dnsPID'):assert receipt['dnsChildReaped'] and receipt['dnsGroupLeft']==0 and receipt['dnsPipesClosed']
    if mode in ('success','inheritance'):assert receipt['inheritanceClean'] and receipt['helperThreads']==1
    if mode=='oversize':assert receipt['responseBytes']==32769
    if mode=='inputcap':assert 'dnsPID' not in receipt
    receipt.update(owners=owners.snapshot(),threadsAtFinal=threading.active_count(),upstreamSocketsCreated=0,
                   resourceTrackerCreated=False,hostnameMode='LOCALHOST_ONLY' if mode=='localhost' else 'NUMERIC_FIXTURE')
    assert not idle.is_alive() and receipt['threadsAtFinal']==1
    return receipt
