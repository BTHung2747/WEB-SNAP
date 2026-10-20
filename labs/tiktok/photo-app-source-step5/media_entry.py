"""Lab-only production CLI delegate; durable phase fence before any core request."""
import hashlib,json,os,pathlib,sys,time
from collector import diagnostics,collect_files,write_once
ROOT=pathlib.Path('/control')
def main():
    if os.environ.get('STEP5_MODE')!='offline':return 78
    args=sys.argv[1:]
    if len(args) not in (3,4) or args[0] not in ('analyze','prepare'):return 21
    phase=args[0];folder=pathlib.Path(args[2]);job=folder.name
    config=json.loads((ROOT/'active.json').read_text());case=ROOT/'cases'/config['case']
    if config['mode']!='offline' or args[1]!=config['url'] or (case/'stopped').exists() or time.monotonic()>=config['end']:return 22
    case.mkdir(exist_ok=True)
    if json.loads((case/'job-once.json').read_text())['id']!=job:return 27
    # Never released: a crashed/stalled/restarted child cannot obtain this phase twice.
    ticks=int(pathlib.Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19])
    try:write_once(case/(phase+'.child-once'),dict(jobId=job,pid=os.getpid(),pgid=os.getpgrp(),startTicks=ticks))
    except FileExistsError:return 23
    from tiktok import photo_core,photo_adapter
    from tiktok.core import versions
    versions()
    if not str(pathlib.Path(photo_core.__file__).resolve()).startswith('/app/apps/media/src/tiktok/'):return 24
    if os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET'):return 25
    if config['fault']=='cancel-wait':
        time.sleep(20) # Offline fault before any metadata; parent must kill/reap.
    diag={};delegate=photo_core.analyze_album if phase=='analyze' else photo_core.prepare_photo
    def wrapped(*a,**kw):
        kw['diagnostics']=diag
        try:return delegate(*a,**kw)
        finally:
            if config['fault']=='missing-diagnostics':diag.clear()
            try:
                receipt=diagnostics(diag,phase)
                receipt.update(collect_files(folder))
                write_once(case/(phase+'.diagnostics.json'),receipt)
                if not receipt['complete']:raise ValueError('INCOMPLETE_DIAGNOSTICS')
            except BaseException as error:
                if not (case/(phase+'.diagnostics.json')).exists():
                    allowed={'COLLECT_DEPTH','COLLECT_NUMBER','COLLECT_STRING','COLLECT_ROWS','COLLECT_TYPE','COLLECT_BYTES','MISSING_DIAGNOSTICS','ATTEMPT_LIMIT','COLLECT_FILE','INCOMPLETE_DIAGNOSTICS'}
                    fixed=error.args[0] if type(error) is ValueError and error.args and error.args[0] in allowed else 'MISSING_OR_INVALID_DIAGNOSTICS'
                    write_once(case/(phase+'.diagnostics.json'),dict(complete=False,phase=phase,wireGET='UNKNOWN',attempts='UNKNOWN',code=fixed))
                raise
    if phase=='analyze':photo_core.analyze_album=wrapped
    else:photo_core.prepare_photo=wrapped
    result=photo_adapter.main(args)
    file=folder/'image.jpg'
    write_once(case/(phase+'.native.json'),dict(phase=phase,coreExit=result,pid=os.getpid(),pgid=os.getpgrp(),
       fileExists=file.exists(),sha256=hashlib.sha256(file.read_bytes()).hexdigest() if file.exists() else None,
       controlSecretAbsent=not bool(os.environ.get('TIKTOK_EGRESS_CONTROL_SECRET')),module='apps/media/src/tiktok/photo_core.py'))
    return result
if __name__=='__main__':
    try:code=main()
    except BaseException:print('{"error":"CONTENT_UNAVAILABLE"}');code=26
    sys.exit(code)
