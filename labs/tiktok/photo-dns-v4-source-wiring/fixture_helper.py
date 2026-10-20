"""Offline worker-exit/IPC fault producer. No resolver, transport or source."""
import io,json,os,sys,time
from dns_admission import strict_loads,compact
import dns_helper
obj=strict_loads(sys.stdin.buffer.read(16385));mode=os.environ.get('V4_FAULT','pass20')
if mode=='oversize':sys.stdout.buffer.write(b'X'*32769);sys.stdout.buffer.flush();sys.exit(0)
if mode=='truncate':sys.stdout.buffer.write(b'{');sys.stdout.buffer.flush();sys.exit(0)
if mode=='wrong-input':obj['version']=1
if mode=='rows129':
    from unittest.mock import patch
    rows=[(2,1,6,'',('8.8.0.'+str(i%40+1),443)) for i in range(129)]
    sys.stdin=io.TextIOWrapper(io.BytesIO(compact(obj)))
    with patch('dns_helper.socket.getaddrinfo',return_value=rows):sys.exit(dns_helper.main())
if mode=='wrong-input':
    sys.stdin=io.TextIOWrapper(io.BytesIO(compact(obj)));sys.exit(dns_helper.main())
p,stop,charge=dns_helper.packet_rows([(2,1,6,'',('8.8.8.8',443))],obj['deadline'])
p.update(version=4,helperID=obj['helperID'],unexpectedInherited=0,threads=1)
if mode=='legacy':p.update(version=3)
if mode=='family-conflict':p['admission'].update(ipv4Rows=0,ipv6Rows=1)
if mode=='wrong-id':p['helperID']='b'*16
sys.stdout.buffer.write(compact(p));sys.stdout.buffer.flush()
if mode=='hang':time.sleep(10)
sys.exit(20 if mode=='pass20' else 0)
