# WED SNAP lab glue, AGPL-3.0. Fingerprint actual mounted code and installed libraries.
import hashlib, importlib.metadata, json, pathlib, shutil, sys

def records(paths, base=None):
    result=[]
    for path in sorted(set(paths)):
        h=hashlib.sha256()
        with path.open('rb') as f:
            for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
        result.append({'path':str(path.relative_to(base)) if base else str(path),
                       'bytes':path.stat().st_size,'sha256':h.hexdigest()})
    return result

def collect():
    src=pathlib.Path('/lab/src')
    deps=pathlib.Path('/opt/cobalt')
    yt=pathlib.Path(importlib.metadata.distribution('yt-dlp').locate_file('yt_dlp'))
    libraries=[pathlib.Path(importlib.metadata.distribution(name).locate_file(module)) for name,module in
               [('requests','requests'),('urllib3','urllib3'),('certifi','certifi'),('idna','idna'),('charset-normalizer','charset_normalizer')]]
    installed=[p for root in (deps,yt,*libraries) for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    installed += [pathlib.Path(importlib.metadata.distribution('brotli').locate_file(f)) for f in
                  importlib.metadata.distribution('brotli').files if str(f).endswith(('.py','.so'))]
    installed += [pathlib.Path(shutil.which(exe)).resolve() for exe in ('node','python3','ffmpeg','ffprobe')]
    installed += [pathlib.Path('/lab/package.json')]
    return {'schema':1,'source':records([p for p in src.rglob('*') if p.is_file() and '__pycache__' not in p.parts],src),
            'dependencies':records(installed)}

def require_match(expected,current):
    if expected != current:raise RuntimeError('OFFLINE_RUNTIME_SOURCE_OR_DEPENDENCY_HASH_MISMATCH')

if __name__=='__main__':
    pathlib.Path(sys.argv[1]).write_text(json.dumps(collect(),indent=2),encoding='utf8')
