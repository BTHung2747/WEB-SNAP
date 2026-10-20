import sys,json,importlib,pathlib,hashlib
try:
    sys.path.insert(0,'/app/apps/media/src')
    rows=[]
    for name in ('tiktok.photo_core','tiktok.photo_adapter','tiktok.photo_file','tiktok.connection_boundaries'):
        m=importlib.import_module(name);p=pathlib.Path(m.__file__).resolve()
        assert str(p).startswith('/app/apps/media/src/tiktok/')
        rows.append(dict(module=name,path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    from tiktok.core import versions
    v=versions()
    print(json.dumps(dict(kind='media-import',role='app',ok=True,python='.'.join(map(str,sys.version_info[:3])),modules=rows,versions=v,sourceCalls=0),separators=(',',':')))
except BaseException:
    print('{"kind":"failure","role":"app","stage":"MEDIA_IMPORT_OR_VERSION_PIN"}')
    raise SystemExit(20)
