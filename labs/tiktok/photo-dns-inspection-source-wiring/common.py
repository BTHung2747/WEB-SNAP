import os
def stage_policy():
    stage=os.environ.get('WHOLEPHOTO_STAGE','offline')
    settings=json.loads(pathlib.Path('/control/control.json').read_text())
    if stage!='offline' or settings.get('stage')!=stage:raise RuntimeError('SOURCE_DISABLED_SUCCESSOR')
    if stage=='source':
        from source_policy import validate
        validate(settings)
    return stage
def trust_hash():
    import certifi
    return hashlib.sha256(pathlib.Path(certifi.where()).read_bytes()).hexdigest()
def isolation(path,stage):
    loaded=[m for m in ('owned_fixture','offline_glue','test_photo','fixture') if m in sys.modules]
    if stage=='source' and loaded:raise RuntimeError('SOURCE_IMPORT_POLICY')
    if stage=='source':
        from source_policy import validate
        validate(json.loads(pathlib.Path('/control/control.json').read_text()))
    pathlib.Path(path).write_text(json.dumps({'stage':stage,'fixtureModulesLoaded':loaded,'trustSHA':trust_hash(),'sourceSafe':stage=='source' and not loaded}))

import hashlib,importlib.metadata,json,pathlib,sys
ROOTS={'integration':'/integration','photo':'/app/apps/media/src/tiktok/photo_lab','core':'/app/apps/media/src/tiktok','trace':'/trace_lab','vendor':'/vendor'}
def versions():return {p:importlib.metadata.version(p) for p in ('requests','urllib3','yt-dlp','aiohappyeyeballs')}
def inventory():
    rows=[]
    for label,base in ROOTS.items():
        root=pathlib.Path(base)
        for path in root.rglob('*'):
            if not path.is_file() or '__pycache__' in path.parts or 'node_modules' in path.parts or label=='core' and 'photo_lab' in path.parts:continue
            rows.append({'path':label+'/'+str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    return sorted(rows,key=lambda r:r['path'])
def summary_valid(summary):
    if not isinstance(summary,dict):return False
    return (summary.get('tcpCoverage',{}).get('status')=='COMPLETE' and summary.get('final') is True and summary.get('incomplete') is False and summary.get('traceClosed') is True
      and summary.get('owners',{}).get('requestSocketsLeft')==0 and summary.get('owners',{}).get('workerThreadsLeft')==0
      and summary.get('owners',{}).get('errors')==0 and summary.get('helpersActive')==0 and summary.get('helperGroupsLeft')==0
      and summary.get('trace',{}).get('rows',257)<=256 and summary.get('trace',{}).get('connectionCap')==32)
