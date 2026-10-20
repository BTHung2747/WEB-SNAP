"""Offline uncooperative loop containment, exit30 closes kernel-owned child sockets."""
import asyncio,os,pathlib,socket,threading,time
from candidate import Sockets,connect
from ownership import Trace
trace=Trace(pathlib.Path('/out/blocked-loop-trace.jsonl'));Trace.current=trace;registry=Sockets()
class Blocked(asyncio.SelectorEventLoop):
    async def sock_connect(self,*args):time.sleep(5)
loop=Blocked();deadline=time.monotonic()+1.2
watchdog=threading.Timer(1.2,lambda:os._exit(30));watchdog.daemon=True;watchdog.start()
loop.run_until_complete(connect([(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443)),(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.2',443))],deadline,registry,loop=loop))
raise SystemExit(40)
