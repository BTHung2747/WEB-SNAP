# AGPL-3.0 integration: real OS-process deadline independent of Node event-loop/timers.
import json, os, pathlib, signal, subprocess, sys, time
from runtime_inventory import collect, require_match
METADATA_SECONDS=30
def run_child(argv, seconds, input_data=None):
    start=time.monotonic()
    proc=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    timed_out=False
    try: stdout,stderr=proc.communicate(input_data,timeout=seconds)
    except subprocess.TimeoutExpired:
        timed_out=True;os.killpg(proc.pid,signal.SIGKILL);stdout,stderr=proc.communicate()
    return {'code':proc.returncode,'timed_out':timed_out,'seconds':time.monotonic()-start,'stdout':stdout,'stderr':stderr}
def main():
    out=pathlib.Path('/out');url=sys.argv[1]
    report={'stage':'metadata','metadata':'FAIL','file':'NOT_RUN','watermark':'NOT_RUN'}
    current=collect()
    (out/'runtime-inventory.json').write_text(json.dumps(current,indent=2),encoding='utf8')
    try:require_match(json.loads((out/'offline-runtime.json').read_text()),current)
    except Exception:
        report.update(stage='hash-gate',error='OFFLINE_RUNTIME_SOURCE_OR_DEPENDENCY_HASH_MISMATCH')
        (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
        print(json.dumps(report));return 30
    report['runtimeHashGate']='PASS'
    meta=run_child(['node','/lab/src/main.mjs',url],METADATA_SECONDS)
    report['metadataNative']={k:meta[k] for k in ('code','timed_out','seconds')}
    if meta['timed_out']:
        report['error']='METADATA_EXTERNAL_DEADLINE_30s'
    else:
        packet=json.loads(meta['stdout']) if meta['stdout'] else {'report':{'error':'NO_METADATA_PACKET'},'contract':None}
        report.update(packet['report'])
        if meta['code']==0 and packet['contract']:
            report['stage']='prepare'
            prepared=run_child(['python3','/lab/src/download.py',str(out)],180,json.dumps(packet['contract']).encode())
            report['prepareNative']={k:prepared[k] for k in ('code','timed_out','seconds')}
            if prepared['timed_out']:report['error']='PREPARE_EXTERNAL_DEADLINE_180s'
            else:
                data=json.loads(prepared['stdout']) if prepared['stdout'] else {'status':'FAIL','error':'NO_PREPARE_PACKET'}
                report['download']=data;report['file']=data['status']
                if prepared['code']!=0:report['error']=data.get('error','PREPARE_FAILED')
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps({k:report.get(k) for k in ('stage','metadata','file','error')}))
    return 0 if report['metadata']=='PASS' and report['file']=='PASS' else 20
if __name__=='__main__':sys.exit(main())
