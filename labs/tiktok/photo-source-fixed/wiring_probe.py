"""Read/import/invalid-input-only probe of the exact production-bound mount recipe."""
import hashlib,importlib,json,os,pathlib,subprocess,sys
def meta(module):
    p=pathlib.Path(module.__file__).resolve();return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
def main():
    assert os.environ.get('STEP5_EXECUTE_SOURCE') is None and os.environ.get('STEP5_OFFLINE_TEST') is None
    sys.path.insert(0,'/lab')
    import overlay_entry
    collector,entry=overlay_entry.bind()
    assert entry.main()==78 and overlay_entry.main()==78
    from dns_child_environment import configure
    configure()
    import dns_child_environment, tiktok_policy.dns_helper
    code='''import hashlib,importlib,json,pathlib,sys,os
rows=[]
for n in ("tiktok_policy","tiktok_policy.dns_helper","tiktok_policy.dns_ipc","tiktok_policy.dns_admission","tiktok_policy.runtime","aiohappyeyeballs"):
 m=importlib.import_module(n);p=pathlib.Path(m.__file__).resolve();rows.append(dict(module=n,path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
print(json.dumps(dict(interpreter=sys.executable,version=list(sys.version_info[:3]),cwd=os.getcwd(),pythonPath=os.environ.get("PYTHONPATH"),modules=rows)))'''
    child=subprocess.run([sys.executable,'-c',code],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8,close_fds=True,start_new_session=True)
    assert child.returncode==0 and len(child.stdout)<16384
    native=subprocess.run([sys.executable,'-m','tiktok_policy.dns_helper'],input=b'{}',stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8,close_fds=True,start_new_session=True)
    assert native.returncode==20 and len(native.stdout)==0
    denied=subprocess.run([sys.executable,'-I','/lab/overlay_entry.py'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8)
    assert denied.returncode==78
    observed=json.loads(child.stdout)
    assert len(observed['modules'])==6 and all(r['path'].startswith('/repo/apps/egress/') for r in observed['modules'])
    report=dict(status='PASS_CACHE_NETWORKNONE_FIXED_WIRING',parent=dict(interpreter=sys.executable,version=list(sys.version_info[:3]),cwd=os.getcwd()),overlay=meta(overlay_entry),collector=meta(collector),entry=meta(entry),configure=meta(dns_child_environment),helperParent=meta(tiktok_policy.dns_helper),child=observed,childImportExit=child.returncode,invalidInputHelperExit=native.returncode,invalidInputResponseBytes=0,childReaped=True,entryDenyExit=denied.returncode,sourceGrantNew=False,sourceRequestsNew=0,sourceExecutionStarted=False,publicDNS=0,externalSockets=0,serverStarted=False,probe='IMPORT_BINDING_AND_INVALID_SCHEMA_ONLY_NOT_NETWORK_PASS')
    pathlib.Path('/control/wiring-result.json').write_text(json.dumps(report,indent=2))
    print('{"status":"PASS_CACHE_NETWORKNONE_FIXED_WIRING","sourceRequestsNew":0}')
if __name__=='__main__':
    try:main()
    except BaseException:print('{"error":"WIRING_PROBE_FAILED"}');sys.exit(1)
