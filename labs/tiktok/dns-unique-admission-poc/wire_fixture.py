"""Adversarial offline IPC; no source or resolver calls."""
import json,sys,time
import dns_helper
obj=json.loads(sys.stdin.buffer.read(16385));mode=sys.argv[1]
if mode=='wire-incomplete':sys.stdout.write('{');sys.exit(0)
value,stop=dns_helper.packet_rows([(2,1,6,'',('8.8.8.8',443))],time.monotonic()+10)
value.update(version=3,helperID='e'*16 if mode=='wire-disjoint' else obj['helperID'],unexpectedInherited=0,threads=1)
if mode=='late-receive':time.sleep(3)
sys.stdout.buffer.write(json.dumps(value,separators=(',',':')).encode());sys.stdout.buffer.flush()
