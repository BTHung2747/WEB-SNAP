import os
def stage_policy():
    stage=os.environ.get('WHOLEPHOTO_STAGE','disabled')
    from dns_admission import strict_loads
    path=pathlib.Path('/control/control.json')
    with path.open('rb') as f:data=f.read(128*1024+1)
    if len(data)>128*1024 or path.is_symlink():raise RuntimeError('STAGE_POLICY')
    settings=strict_loads(data)
    if type(settings) is not dict:raise RuntimeError('STAGE_POLICY')
    if stage not in ('offline','source','cold') or settings.get('stage')!=stage or settings.get('sourceGate') is not (True if stage=='source' else False):raise RuntimeError('STAGE_POLICY')
    if 'admission' not in settings:raise RuntimeError('ALBUM_ADMISSION_REQUIRED')
    if stage=='offline':
        from album_admission import validate
        validate(settings['admission'])
    else:
        from source_isolation import validate_environment
        validate_environment()
        if stage=='cold' and settings.get('coldOnly') is not True:raise RuntimeError('COLD_SCOPE')
        if stage=='source' and any(k in settings for k in ('coldOnly','mode','case')):raise RuntimeError('SOURCE_CONTROL_POLICY')
        from live_admission import validate
        validate(settings['admission'],harness=stage=='cold')
    return stage
def trust_hash():
    import certifi
    return hashlib.sha256(pathlib.Path(certifi.where()).read_bytes()).hexdigest()
def isolation(path,stage):
    loaded=[m for m in ('owned_fixture','offline_glue','test_photo','fixture') if m in sys.modules]
    if stage=='source' and loaded:raise RuntimeError('SOURCE_IMPORT_POLICY')
    if stage=='source':
        from source_isolation import validate_environment
        validate_environment()
    pathlib.Path(path).write_text(json.dumps({'stage':stage,'fixtureModulesLoaded':loaded,'trustSHA':trust_hash(),'sourceSafe':stage=='source' and not loaded}))

import hashlib,importlib.metadata,json,pathlib,sys
ROOTS={'integration':'/integration','photo':'/app/apps/media/src/tiktok/source_photo','core':'/app/apps/media/src/tiktok','trace':'/trace_lab','vendor':'/vendor'}
def versions():return {p:importlib.metadata.version(p) for p in ('requests','urllib3','yt-dlp','aiohappyeyeballs')}
def inventory():
    rows=[]
    for label,base in ROOTS.items():
        root=pathlib.Path(base)
        # Public os.walk top-down pruning: same excluded set as the old rglob,
        # without repeatedly traversing cached node_modules or duplicate mounts.
        for folder,dirs,files in os.walk(root):
            dirs[:]=[d for d in dirs if d not in ('__pycache__','node_modules') and not(label=='core' and d in ('photo_lab','source_photo'))]
            for name in files:
                path=pathlib.Path(folder,name)
                if not path.is_file() or name in ('__pycache__','node_modules') or label=='core' and name in ('photo_lab','source_photo'):continue
                rows.append({'path':label+'/'+str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    return sorted(rows,key=lambda r:r['path'])
def summary_valid(summary):
    if not isinstance(summary,dict):return False
    return (summary.get('tcpCoverage',{}).get('status')=='COMPLETE' and summary.get('final') is True and summary.get('incomplete') is False and summary.get('traceClosed') is True
      and summary.get('owners',{}).get('requestSocketsLeft')==0 and summary.get('owners',{}).get('workerThreadsLeft')==0
      and summary.get('owners',{}).get('errors')==0 and summary.get('helpersActive')==0 and summary.get('helperGroupsLeft')==0
      and summary.get('trace',{}).get('rows',257)<=256 and summary.get('trace',{}).get('connectionCap')==32)

