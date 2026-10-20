def main():
    """Network-none import/hash probe, Python -I ignores all fixture PYTHONPATH/sitecustomize."""
    import sys,pathlib,hashlib,json,importlib
    sys.path[:0]=['/lab','/app/apps/media/src']
    modules=['source_entry','proxy_entry','media_entry','media','proxy_collect','supervisor','collector','tiktok.photo_core','tiktok.photo_adapter','tiktok.photo_proxy','tiktok.connection_boundaries','requests','urllib3','yt_dlp']
    observed=[]
    for name in modules:
        m=importlib.import_module(name);p=pathlib.Path(m.__file__).resolve()
        assert '/fixture/' not in str(p) and '/offline/' not in str(p)
        observed.append(dict(module=name,path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    assert 'offline' not in sys.modules
    from tiktok.core import versions
    versions()
    custom=sys.modules.get('sitecustomize')
    if custom is not None:
        p=pathlib.Path(custom.__file__).resolve()
        pathlib.Path('/control/global-sitecustomize.json').write_text(json.dumps(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())))
        pathlib.Path('/control/global-sitecustomize.txt').write_bytes(p.read_bytes())
        assert str(p)=='/etc/python3.11/sitecustomize.py' and hashlib.sha256(p.read_bytes()).hexdigest()=='43d81125d92376b1a69d53a71126a041cc9a18d8080e92dea0a2ae23be138b1e'
    assert 'media_site' not in sys.modules
    import subprocess
    probe=subprocess.run(['node','/lab/ts_probe.cjs'],timeout=30,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    assert probe.returncode==0
    entry_results=[]
    for entry in ('source_entry.py','proxy_entry.py','media_entry.py'):
        before={p.name for p in pathlib.Path('/control').iterdir()}
        p=subprocess.run([sys.executable,'-I','/lab/'+entry],timeout=10,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
        assert p.returncode==78 and {p.name for p in pathlib.Path('/control').iterdir()}==before
        entry_results.append(dict(entry=entry,actualExit=p.returncode,newFiles=0))
    pathlib.Path('/control/python-default-deny.json').write_text(json.dumps(dict(entries=entry_results,sourceBranchInvoked=False,sourceExecutionStarted=False,sourceCalls=0)))
    pathlib.Path('/control/import-result.json').write_text(json.dumps(dict(status='PASS_ISOLATED_IMPORT_HASH_NO_FIXTURE',sourceGrant=False,sourceExecutionStarted=False,sourceCalls=0,network='none',modules=observed,fixtureImported=False),indent=2))
    print('PASS isolated imports; no source request')

if __name__=='__main__':
    import sys,json
    try:main()
    except SystemExit:raise
    except BaseException:
        print(json.dumps(dict(error='LAB_ENTRY_FAILED',sourceCalls=0)))
        sys.exit(1)
