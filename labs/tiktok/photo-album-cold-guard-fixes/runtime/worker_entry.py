"""Offline album parent role; no source authority or main app code."""
import hashlib,json,os,pathlib,socket,stat,sys,time
from common import stage_policy,versions,inventory,trust_hash
stage_policy() # Bind authority before consumer HTTP-related module imports.
from album_parent import pipeline
from accounting import receipt,read_owned_observer
from evidence_contract import publish_observer
sys.excepthook=lambda *a:print('ALBUM_ENTRY_FAILURE',flush=True)
def main():
    stage=stage_policy()
    if stage=='cold':raise RuntimeError('COLD_ONLY_NO_CAPABILITY')
    assert os.getuid()==1000 and sys.version.split()[0]=='3.11.2'
    out=pathlib.Path('/out');control=json.loads(pathlib.Path('/control/control.json').read_text())
    (out/'worker-runtime.json').write_text(json.dumps(dict(python=sys.version.split()[0],versions=versions(),sources=inventory(),uid=os.getuid(),trustSHA=trust_hash())))
    trace=pathlib.Path('/proxy/proxy-trace.jsonl');st=trace.stat();denied=False
    try:trace.read_bytes()
    except PermissionError:denied=True
    assert denied and st.st_uid==65534 and stat.S_IMODE(st.st_mode)==0o600
    bypass=True
    try:s=socket.create_connection(('192.0.2.1',443),timeout=.3);s.close();bypass=False
    except OSError:pass
    assert bypass
    (out/'permission-network.json').write_text(json.dumps(dict(uid=1000,privateReadDenied=denied,noBypass=bypass)))
    mode=control.get('mode','normal');argv=None
    if mode=='symlink':(out/'image-0001.jpg').symlink_to(out/'keep.bin')
    if mode in ('native-nonzero','native-hang'):
        argv=['python3','/integration/fake_worker.py',mode]
    result,code=pipeline(out,mode=control.get('selectionMode','all'),indices=control.get('indices'),argv=argv,metadata_seconds=.2 if mode=='cancel' else 30)
    selected_count=len((result.get('selection') or {}).get('indices',[])) or 1
    events,present,incomplete=read_owned_observer(out/'tiktok-boundaries.jsonl')
    publish_observer(out)
    accounting=receipt(result,events,observer_present=present,observer_incomplete=incomplete,selected_count=selected_count)
    result.update(requestAccounting=accounting,sourceGate=stage=='source',sourceCalls='UNKNOWN_USE_REQUEST_ACCOUNTING' if stage=='source' else 0,fixture=stage=='offline',contentIdentity='UNKNOWN')
    (out/'request-accounting.json').write_text(json.dumps(accounting));(out/'result.json').write_text(json.dumps(result,indent=2))
    # Only public bounded receipts; never URL/cookie/body.
    print('ALBUM_PARENT_EXIT_'+str(code),flush=True)
    return code
if __name__=='__main__':sys.exit(main())
