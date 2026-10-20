"""Inspect static image startup customization, network-none; no source main."""
import hashlib,json,pathlib,sys
module=sys.modules.get('sitecustomize');path=pathlib.Path(module.__file__) if module else None
row={'loaded':module is not None,'path':str(path) if path else None,'sha256':hashlib.sha256(path.read_bytes()).hexdigest() if path else None}
pathlib.Path('/out/site-identity.json').write_text(json.dumps(row))
if path and str(path)=='/usr/lib/python3.11/sitecustomize.py':
    pathlib.Path('/out/image-system-sitecustomize.py').write_bytes(path.read_bytes())
print('IMAGE_STARTUP_IDENTITY_RECORDED',flush=True)
