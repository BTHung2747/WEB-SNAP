"""AGPL-3.0 lab glue: existing parent/worker, bounded file contract and ephemeral session."""
import json,os,pathlib,stat,sys
sys.path.insert(0,'/app/apps/media/src/tiktok/photo_lab')
sys.path.insert(0,'/app/apps/media/src')
sys.excepthook=lambda *a:print('PHOTO_ENTRY_FAILURE',flush=True)
from common import inventory,versions
URL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';ID='7678209751167110421'
def pipeline_run(folder,metadata_seconds=30,prepare_seconds=60):
    from parent import pipeline
    return pipeline(URL,ID,prepare=True,worker_argv=['python3','/integration/worker_entry.py','child',str(folder)],
                    metadata_seconds=metadata_seconds,prepare_seconds=prepare_seconds,output_dir=str(folder))
def main():
    if len(sys.argv)>1 and sys.argv[1]=='child':
        from worker import worker
        # The existing worker has no pre-prepare trace callback. Adapt only its owned IPC input;
        # no extractor, HTTP, TLS or downloader override is introduced.
        original=sys.stdin
        class TraceInput:
            def readline(self):
                command=original.readline()
                if command.strip()=='prepare':
                    valid=False;receipt={'status':'FAIL','code':'TRACE_RECEIPT_UNKNOWN','clientCorrelation':'UNKNOWN'}
                    try:
                        path=pathlib.Path('/proxy/proxy-health.json');st=path.stat();health=json.loads(path.read_text())
                        valid=(health.get('incomplete') is False and health.get('uid')==65534 and st.st_uid==65534
                               and type(health.get('rows')) is int and 0<health['rows']<=256
                               and health.get('totalCap')==256 and health.get('connectionCap')==32)
                        receipt.update(status='PASS' if valid else 'FAIL',code='TRACE_RECEIPT_OK' if valid else 'TRACE_RECEIPT_INCOMPLETE',
                                       proxyRowsReported=health.get('rows') if type(health.get('rows')) is int else None,
                                       proxyHealthUID=st.st_uid,proxyHealthMode=stat.S_IMODE(st.st_mode))
                    except FileNotFoundError:receipt['code']='TRACE_RECEIPT_MISSING'
                    except PermissionError:receipt['code']='TRACE_RECEIPT_PERMISSION'
                    except (ValueError,TypeError):receipt['code']='TRACE_RECEIPT_INVALID'
                    with (pathlib.Path(sys.argv[2])/'trace-prepare-gate.json').open('x') as f:json.dump(receipt,f)
                    if not valid:raise RuntimeError('TRACE_GATE_FAIL')
                return command
        sys.stdin=TraceInput()
        return worker(URL,ID,sys.argv[2])
    stage=os.environ.get('PHOTO_TRACE_STAGE')
    assert stage in ('offline','live') and os.geteuid()==1000 and sys.version.split()[0]=='3.11.2'
    OUT=pathlib.Path('/out')
    with (OUT/'worker-runtime.json').open('x') as f:json.dump({'python':sys.version.split()[0],'versions':versions(),'sources':inventory(),'uid':os.geteuid()},f)
    if stage=='offline':
        from offline_pipeline import run
        return run(OUT)
    result,code=pipeline_run(OUT)
    result.update(sourceAnalyzeAttempts=1,source=False if result.get('error')=='SOURCE_DISABLED' else True)
    with (OUT/'result.json').open('x') as f:json.dump(result,f,indent=2)
    print(json.dumps(result),flush=True)
    return code
if __name__=='__main__':sys.exit(main())

