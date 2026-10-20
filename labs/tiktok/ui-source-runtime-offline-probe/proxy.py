import sys,json,importlib,pathlib,hashlib
try:
    sys.path[:0]=['/repo/apps/egress/src','/repo/apps/egress/vendor']
    rows=[]
    for name in ('egress','tiktok_policy.dns_admission','tiktok_policy.runtime','aiohappyeyeballs'):
        module=importlib.import_module(name)
        path=pathlib.Path(module.__file__).resolve()
        if not str(path).startswith('/repo/apps/egress/'):raise ValueError('IMPORT_SCOPE')
        rows.append(dict(module=name,path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    from tiktok_policy.runtime import verify_vendor
    verify_vendor()
    assert sys.flags.isolated and 'media_site' not in sys.modules
    print(json.dumps(dict(kind='role',role='proxy',ok=True,python='.'.join(map(str,sys.version_info[:3])),isolated=True,modules=rows,vendorPinVerified=True,serverStarted=False),separators=(',',':')))
except BaseException:
    print('{"kind":"failure","role":"proxy","stage":"PYTHON_IMPORT_OR_VENDOR_PIN"}')
    raise SystemExit(20)
