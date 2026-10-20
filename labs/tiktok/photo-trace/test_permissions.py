"""Read-only ownership capability proof; never exports file contents."""
import json,os,pathlib,stat,sys
rows=[]
for label,name in [('TRACE_PRIVATE','proxy-trace.jsonl'),('HEALTH_RECEIPT','proxy-health.json')]:
    p=pathlib.Path('/proxy')/name;s=p.stat()
    try:
        with p.open('rb') as f:f.read(1)
    except PermissionError:allowed=False;code='PERMISSION_DENIED'
    else:allowed=True;code='READABLE'
    rows.append({'kind':label,'uid':s.st_uid,'gid':s.st_gid,'mode':stat.S_IMODE(s.st_mode),'readable':allowed,'code':code})
print(json.dumps({'python':sys.version.split()[0],'core':[],'uid':os.geteuid(),'files':rows,'sourceCalls':0}))

