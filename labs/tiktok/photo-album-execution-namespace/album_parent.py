"""Parent-owned finite filenames and deadlines. PASS requires native exit0 and reap."""
import json,os,pathlib,queue,signal,subprocess,threading,time
from album_contract import Ledger,VERSION,validate_summary,selection,require,canonical
ID='7678209751167110421'
def pipeline(folder,mode='all',indices=None,argv=None,metadata_seconds=30,prepare_seconds=180):
    from common import stage_policy
    require(stage_policy() in ('offline','source'),'COLD_ONLY_NO_CAPABILITY')
    require(0<metadata_seconds<=30 and 0<prepare_seconds<=180,'DEADLINE_POLICY')
    folder=pathlib.Path(folder);ledger=Ledger(folder)
    (folder/'ownership-before.json').write_bytes(canonical(ledger.snapshot()))
    start=time.monotonic();end=start+metadata_seconds
    control=pathlib.Path('/control/control.json')
    def phase(deadline):
        settings=json.loads(control.read_text());settings['phaseDeadline']=deadline
        temp=control.with_suffix('.tmp');temp.write_bytes(canonical(settings));os.replace(temp,control)
    phase(end)
    p=subprocess.Popen(argv or ['python3','/integration/album_worker.py',str(folder),str(end)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,start_new_session=True)
    messages=queue.Queue(maxsize=3);stop=threading.Event()
    def reader():
        try:
            for _ in range(3):
                line=p.stdout.readline(8193)
                if not line:messages.put(None);return
                row=json.loads(line) if len(line)<=8192 else {'status':'FAIL','error':'PACKET_LIMIT'}
                if stop.is_set():return
                messages.put(row,timeout=1)
        except Exception:
            try:messages.put({'status':'FAIL','error':'INVALID_PACKET'},timeout=.1)
            except queue.Full:pass
    thread=threading.Thread(target=reader,daemon=True);thread.start()
    result=dict(stage='metadata',status='FAIL',metadataAccepted=False,sourceCalls=0,sourceGate=False);code=20
    def packet():return messages.get(timeout=max(0,end-time.monotonic()))
    try:
        meta=packet();result['metadataPacket']=meta;require(type(meta) is dict and meta.get('stage')=='metadata' and meta.get('status')=='PASS','METADATA_FAILED')
        value=validate_summary(meta['summary'],ID)
        settings=json.loads(control.read_text())
        from common import stage_policy
        stage_policy()
        from album_admission import check_metadata
        check_metadata(settings,value)
        chosen=dict(version=VERSION,mode=mode,snapshotKey=value['snapshotKey'],indices=indices if indices is not None else list(range(1,value['imageCount']+1)))
        selected=selection(chosen,value);ledger.register(selected)
        (folder/'ownership-selected.json').write_bytes(canonical(ledger.snapshot()))
        (folder/'selection.json').write_bytes(canonical(chosen));result['selection']=chosen
        result['metadataSeconds']=time.monotonic()-start;result['stage']='prepare'
        prepare_start=time.monotonic();end=prepare_start+prepare_seconds;phase(end)
        p.stdin.write(canonical(dict(selection=chosen,prepareEnd=end,ownedNames=ledger.selected))+b'\n');p.stdin.flush()
        prepared=packet();result['preparePacket']=prepared;result['prepareSeconds']=time.monotonic()-prepare_start
        require(type(prepared) is dict and prepared.get('stage')=='prepare' and prepared.get('status')=='PASS','PREPARE_FAILED')
        p.wait(timeout=max(0,min(1,end-time.monotonic())));require(p.returncode==0,'WORKER_NONZERO_EXIT')
        result.update(status='ALBUM_PROVISIONAL',metadataAccepted=True);code=0
    except queue.Empty:result['error']='PHASE_EXTERNAL_DEADLINE'
    except subprocess.TimeoutExpired:result['error']='WORKER_EXIT_TIMEOUT'
    except Exception as error:
        safe={'METADATA_FAILED','PREPARE_FAILED','WORKER_NONZERO_EXIT','ALBUM_METADATA','ALBUM_KEY','ALBUM_DIMENSIONS','ALBUM_INDEX','ALBUM_SELECTION','ALBUM_SELECTION_LIMIT','ALBUM_SELECTION_ORDER','ALBUM_SNAPSHOT','OUTPUT_COLLISION','ALBUM_SOURCE_SNAPSHOT_CHANGED'}
        result['error']=error.args[0] if type(error) is RuntimeError and error.args and type(error.args[0]) is str and error.args[0] in safe else 'PARENT_PROTOCOL'
    finally:
        # Never let trace failure prevent kill/reap/pipe close.
        stop.set()
        if p.poll() is None:
            try:os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError:pass
        p.wait();result.update(workerActualExit=p.returncode,workerSignal=-p.returncode if p.returncode<0 else None)
        for pipe in (p.stdin,p.stdout):
            try:pipe.close()
            except OSError:pass
        thread.join(1);result['readerJoined']=not thread.is_alive()
        if p.returncode!=0 or code!=0 or thread.is_alive():
            code=20;result.update(status='FAIL',metadataAccepted=False)
            result['ownedOutputRemoved']=ledger.cleanup()
        else:result['ownedOutputRemoved']=[]
        result['sentinelsPreserved']=ledger.preserved();result['parentActualExit']=code
        result['scope']=dict(activeEpoch=start,activeSeconds=time.monotonic()-start,watchdogSeconds=225,watchdogScope='METADATA30_PREPARE180_END15',hostE2EBound='NOT_CLAIMED')
        packet=result.get('preparePacket') or {};verified={f.get('index') for f in packet.get('files',[]) if type(f) is dict}
        failed=packet.get('failedIndex')
        result['itemStates']=[dict(index=i,state='VERIFIED' if code==0 else 'VERIFIED_THEN_DISCARDED' if i in verified else 'FAILED' if type(failed) is int and i==failed else 'SKIPPED',cause='UNKNOWN') for i in (result.get('selection') or {}).get('indices',[])]
    return result,code
