# AGPL-3.0 lab parent: packet success is provisional until the owned worker exits0.
import json,os,pathlib,queue,signal,subprocess,sys,threading,time
PACKET_CAP=8192
EXIT_GRACE_SECONDS=1
def pipeline(url,expected_id,prepare=False,allow_network=False,worker_argv=None,metadata_seconds=30,prepare_seconds=180):
    if not 0<metadata_seconds<=30 or not 0<prepare_seconds<=180:raise ValueError('DEADLINE_POLICY')
    if not allow_network and worker_argv is None:return {'stage':'authorization','status':'FAIL','error':'SOURCE_DISABLED','sourceAttempts':0},30
    owned_dir=pathlib.Path('/out').resolve()
    output_names=[owned_dir/name for name in ('video.mp4','video.mp4.part','video.mp4.ytdl')]
    existing={path for path in output_names if path.exists()}
    argv=worker_argv or ['python3','/lab/src/yt_candidate.py','--worker',url,expected_id,'--allow-network']
    p=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,start_new_session=True)
    messages=queue.Queue(maxsize=3)
    def read():
        while True:
            data=p.stdout.readline(PACKET_CAP+1)
            if not data:messages.put(None);return
            if len(data)>PACKET_CAP:messages.put({'stage':'protocol','status':'FAIL','error':'PACKET_LIMIT'});return
            try:messages.put(json.loads(data))
            except Exception:messages.put({'stage':'protocol','status':'FAIL','error':'INVALID_PACKET'});return
    reader=threading.Thread(target=read,daemon=True);reader.start()
    result={'stage':'metadata','status':'FAIL','file':'NOT_RUN','metadataAccepted':False}
    code=20;provisional=None;phase_start=time.monotonic();deadline=phase_start+metadata_seconds
    def packet(timeout_label):
        try:return messages.get(timeout=max(0,deadline-time.monotonic()))
        except queue.Empty:result['error']=timeout_label;return None
    try:
        meta=packet('METADATA_EXTERNAL_DEADLINE_30s')
        result['metadataPacket']=meta
        if not isinstance(meta,dict) or meta.get('stage')!='metadata' or meta.get('status')!='PASS':
            result.setdefault('error',meta.get('error','NO_METADATA_PACKET') if isinstance(meta,dict) else 'NO_METADATA_PACKET')
        else:
            result['metadataSeconds']=time.monotonic()-phase_start
            if not prepare:
                try:p.stdin.write(b'stop\n');p.stdin.flush()
                except BrokenPipeError:pass
                provisional='METADATA_ONLY'
            else:
                result['stage']='prepare';phase_start=time.monotonic();deadline=phase_start+prepare_seconds
                try:p.stdin.write(b'prepare\n');p.stdin.flush()
                except BrokenPipeError:result['error']='WORKER_COMMAND_FAILED'
                if 'error' not in result:
                    file=packet('PREPARE_EXTERNAL_DEADLINE_180s');result['preparePacket']=file
                    result['prepareSeconds']=time.monotonic()-phase_start
                    if isinstance(file,dict) and file.get('stage')=='prepare' and file.get('status')=='PASS':
                        provisional='FILE_NEEDS_VISUAL_REVIEW'
                    else:result.setdefault('error',file.get('error','NO_PREPARE_PACKET') if isinstance(file,dict) else 'NO_PREPARE_PACKET')
        if provisional:
            # Preserve prior1s exit grace but never extend the active metadata/prepare deadline.
            try:p.wait(timeout=max(0,min(EXIT_GRACE_SECONDS,deadline-time.monotonic())))
            except subprocess.TimeoutExpired:result['error']='WORKER_EXIT_TIMEOUT'
            if p.returncode==0:
                result.update(status=provisional,metadataAccepted=True,file='NEEDS_VISUAL_REVIEW' if prepare else 'NOT_RUN')
                code=0
            elif p.returncode is not None:result['error']='WORKER_NONZERO_EXIT'
    except Exception:
        result['error']='PARENT_PROTOCOL_FAILURE'
    finally:
        if p.poll() is None:
            try:os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError:pass
        p.wait()
        result['workerActualExit']=p.returncode;result['workerSignal']=-p.returncode if p.returncode<0 else None
        # Final result is decided only after reap. No PASS packet can override failed/killed exit.
        if p.returncode!=0 or code!=0:
            code=20;result['status']='FAIL';result['metadataAccepted']=False
            result['file']='FAIL_DISCARDED' if result['stage']=='prepare' else 'NOT_RUN'
            result.setdefault('error','WORKER_NONZERO_EXIT' if p.returncode else 'PIPELINE_FAILURE')
            removed=[]
            for path in output_names:
                if path not in existing and path.is_file() and path.resolve().parent==owned_dir:
                    path.unlink();removed.append(path.name)
            result['ownedOutputRemoved']=removed
        else:result['ownedOutputRemoved']=[]
        result['preexistingOutputsPreserved']=[path.name for path in existing]
        for pipe in (p.stdin,p.stdout):
            try:pipe.close()
            except OSError:pass
    return result,code

if __name__=='__main__':
    if '--allow-network' not in sys.argv:raise SystemExit('SOURCE_DISABLED: new authorized source task and runtime guards required')
    result,code=pipeline(sys.argv[1],sys.argv[2],prepare='--prepare' in sys.argv,allow_network=True)
    pathlib.Path('/out/candidate-result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps(result));sys.exit(code)
