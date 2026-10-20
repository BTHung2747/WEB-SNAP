import hashlib,json,os,pathlib,subprocess,sys,time

def main():
    mode=sys.argv[1];assert mode in ('baseline','corrected','negative')
    sys.path[:0]=['/lab','/repo/apps/egress/src','/repo/apps/egress/vendor','/probe']
    if mode=='corrected':
        from dns_child_environment import configure
        configure()
    import tiktok_policy.dns_ipc as ipc,tiktok_policy.dns_helper as helper
    root=pathlib.Path('/control');start=time.monotonic()
    def meta(module):
        p=pathlib.Path(module.__file__).resolve();return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    code=pathlib.Path('/probe/child.py').read_text()
    child=subprocess.run([sys.executable,'-c',code],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8,close_fds=True,start_new_session=True)
    assert len(child.stdout)<=16384
    observed=json.loads(child.stdout)
    # Malformed input has no hostname and is rejected before the resolver in the pinned helper.
    native=subprocess.run([sys.executable,'-m','tiktok_policy.dns_helper'],input=b'{}',stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8,close_fds=True,start_new_session=True)
    assert len(native.stdout)<=32768
    result=dict(mode=mode,interpreter=sys.executable,version=list(sys.version_info[:3]),cwd=os.getcwd(),pythonPath=os.environ.get('PYTHONPATH'),parent=dict(dnsIPC=meta(ipc),dnsHelper=meta(helper)),childImport=observed,childImportExit=child.returncode,nativeInvalidInputExit=native.returncode,nativeResponseBytes=len(native.stdout),nativeReaped=True,probe='IMPORT_AND_INVALID_INPUT_REJECTION_ONLY',dnsRequests=0,socketRequests=0,elapsedSeconds=time.monotonic()-start)
    (root/'probe-result.json').write_text(json.dumps(result,indent=2))
    from collector_tests import run
    run(root,mode)
    print(json.dumps(dict(status='PROBE_RECORDED',mode=mode,childImportExit=child.returncode,helperExit=native.returncode,sourceRequests=0)))

if __name__=='__main__':
    try:main()
    except BaseException:
        print('{"error":"OFFLINE_PROBE_FAILED"}');sys.exit(1)
