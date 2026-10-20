"""AGPL-3.0 lab glue. Pinned extractor/Cobalt/Requests/JPEG contract remain owners."""
import hashlib,json,os,pathlib,subprocess,sys,time
sys.path[:0]=['/app/apps/media/src','/app/apps/media/src/tiktok/source_photo']
from common import stage_policy
stage_policy() # Authority/runtime/expiry before any HTTP/extractor imports.
from tiktok.core import GuardedYDL,versions
from tiktok.adapter import error_code
from tiktok.prepare_operations import Operations
from yt_dlp.networking import Request
from worker import contract
from album_budget import AlbumBudget
from album_contract import summary,selection,filename,require,canonical
def emit(row):
    data=canonical(row);require(len(data)+1<=8192,'PACKET_LIMIT')
    sys.stdout.buffer.write(data+b'\n');sys.stdout.buffer.flush()
def main():
    execution_stage=stage_policy()
    if execution_stage in ('cold','bootstrap'):raise RuntimeError('COLD_ONLY_NO_CAPABILITY')
    folder=pathlib.Path(sys.argv[1]);meta_end=float(sys.argv[2]);control=pathlib.Path('/control/control.json')
    expected='7678209751167110421';target='https://www.tiktok.com/@adne_la.veil/video/'+expected
    b=AlbumBudget(meta_end);ydl=GuardedYDL(b,folder);stage='metadata';completed=[];data=None;current_index=None
    try:
        versions();ydl.allowed_url=target
        try:ydl.extract_info(target,download=False,ie_key='TikTok',process=False)
        except Exception:
            if b.failure or b.latest_body is None:raise
        b.check();require(b.latest_body is not None,'PHOTO_METADATA_UNAVAILABLE')
        p=subprocess.run(['node','/app/apps/media/src/tiktok/source_photo/picker.mjs',expected],input=b.latest_body,
                        stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=min(2,b.deadline-time.monotonic()))
        b.latest_body=None;b.check();require(p.returncode==0 and len(p.stdout)<=128*1024,'PHOTO_METADATA_UNAVAILABLE')
        data=json.loads(p.stdout);meta=summary(data,expected)
        emit(dict(stage=stage,status='PASS',summary=meta,rows=b.rows.copy(),metadataBytes=b.total))
        command=json.loads(sys.stdin.buffer.readline(8193))
        require(set(command)=={'selection','prepareEnd','ownedNames'},'COMMAND_POLICY')
        indices=selection(command['selection'],meta)
        settings=json.loads(control.read_text())
        stage_policy()
        from album_admission import check_metadata
        check_metadata(settings,meta)
        names=[n for i in indices for n in (filename(i),filename(i)+'.part')]
        require(command['ownedNames']==names and all(not os.path.lexists(folder/n) for n in names),'OUTPUT_OWNERSHIP')
        health=json.loads(pathlib.Path('/proxy/proxy-health.json').read_text());st=pathlib.Path('/proxy/proxy-health.json').stat()
        require(health.get('incomplete') is False and st.st_uid==65534 and (st.st_mode&0o777)==0o644 and type(health.get('rows')) is int and 0<health['rows']<256 and health.get('totalCap')==256 and health.get('connectionCap')==32,'TRACE_GATE')
        (folder/'trace-prepare-gate.json').write_text(json.dumps(dict(status='PASS',rows=health['rows'])))
        stage='prepare';b.begin_album(len(indices),command['prepareEnd'])
        for i in indices:
            stage_policy() # Recheck expiry/binding before every conditional GET.
            current_index=i
            health=json.loads(pathlib.Path('/proxy/proxy-health.json').read_text())
            require(health.get('incomplete') is False and type(health.get('rows')) is int and health['rows']<256,'TRACE_GATE')
            b.begin_item();item_begin=time.monotonic();selected=data['images'][i-1];name=filename(i);part=folder/(name+'.part')
            ops=Operations(b.deadline,sink=f'operations-{i:04d}.jsonl',root=folder)
            ydl.allowed_url=selected['url']
            with ops.step('DOWNLOADER'):
                with ydl.urlopen(Request(selected['url'])) as response:
                    mime=response.headers.get('Content-Type','')
                    with part.open('xb') as out:
                        while True:
                            chunk=response.read(min(16384,16*1024*1024-out.tell()+1))
                            if not chunk:break
                            b.write_check(out.tell(),len(chunk));out.write(chunk)
            with ops.step('CONTRACT'):checked=contract(part,mime,ops)
            require(all(selected[k]==checked[k] for k in ('width','height')),'DIMENSION_MISMATCH');b.check()
            with ops.step('HASH'):
                h=hashlib.sha256()
                with part.open('rb') as stream:
                    for chunk in iter(lambda:stream.read(65536),b''):h.update(chunk);b.check()
            # Original Operations sink remains private0600. Numeric-only projection
            # is explicitly published for the separate UID65534 finalizer.
            proof=ops.path.read_bytes();require(len(proof)<=16384,'TRACE_GATE')
            events=[json.loads(line) for line in proof.splitlines()]
            require(len(events)<=32 and all(set(row)=={'operation','event','code','elapsed','timeout','returncode'} for row in events),'TRACE_GATE')
            public=folder/f'operations-public-{i:04d}.json'
            envelope=dict(version=2,index=i,scope=dict(begin=item_begin,end=time.monotonic(),itemDeadline=b.deadline,prepareDeadline=b.prepare_end,reserveSeconds=10),events=events)
            with public.open('xb') as stream:stream.write(canonical(envelope))
            os.chmod(public,0o644)
            require(not os.path.lexists(folder/name),'OUTPUT_COLLISION');part.rename(folder/name)
            completed.append(dict(index=i,itemKey=meta['images'][i-1]['itemKey'],file=name,bytes=(folder/name).stat().st_size,sha256=h.hexdigest(),contract=checked))
        emit(dict(stage=stage,status='PASS',files=completed,rows=b.rows,metadataBytes=b.metadata_bytes,inputBytes=b.network_total,outputBytes=b.output_bytes,visual='FIXTURE_ONLY' if execution_stage=='offline' else 'NEEDS_VISUAL_REVIEW',contentIdentity='UNKNOWN'))
        return 0
    except Exception as error:
        fixed=error.args[0] if type(error) is RuntimeError and error.args and type(error.args[0]) is str and error.args[0] in {
          'ALBUM_METADATA','ALBUM_INDEX','ALBUM_DIMENSIONS','ALBUM_URL','ALBUM_SELECTION','ALBUM_SELECTION_LIMIT','ALBUM_SELECTION_ORDER','ALBUM_SNAPSHOT',
          'PREPARE_DEADLINE','COMMAND_POLICY','OUTPUT_OWNERSHIP','TRACE_GATE','OUTPUT_COLLISION','DIMENSION_MISMATCH','PHOTO_METADATA_UNAVAILABLE','PACKET_LIMIT','JPEG_REQUIRED','PIXEL_LIMIT','STATIC_IMAGE_REQUIRED','ALBUM_SOURCE_SNAPSHOT_CHANGED'} else error_code(error,b)
        emit(dict(stage=stage,status='FAIL',error=fixed,files=completed,failedIndex=current_index,rows=b.rows,decodedBytes=b.network_total))
        return 20
    finally:
        # Physical close is independent of evidence writes; parent exclusively rolls back files.
        ydl.close();data=None;b.latest_body=None
if __name__=='__main__':sys.exit(main())

