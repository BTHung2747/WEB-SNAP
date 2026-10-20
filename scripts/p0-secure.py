"""Real adapter validation through the network-isolated worker and egress proxy."""
import json,subprocess,pathlib,datetime,uuid,sys,os,shutil
samples=json.loads(pathlib.Path('/samples/p0-samples.json').read_text())
evidence=pathlib.Path('/evidence');evidence.mkdir(exist_ok=True)
report={'date':datetime.datetime.now(datetime.timezone.utc).isoformat(),'mode':'temporary','adapter':'yt-dlp-2026.08.19 + controlled CONNECT proxy','samples':[]}
for s in samples:
    folder=pathlib.Path('/media')/str(uuid.uuid4());row={'name':s['name'],'platform':s['platform'],'url':s['url']}
    try:
        p=subprocess.run(['python3','/app/infra/media_adapter.py','analyze',s['url'],str(folder)],capture_output=True,text=True,timeout=30)
        row['analyzeExit']=p.returncode
        info=json.loads(p.stdout.strip().splitlines()[-1]);row['analyze']=info.get('error') or 'selectable'
        if p.returncode==0 and info.get('formats'):
            selected=info['formats'][0]['id'];row['formatId']=selected
            p=subprocess.run(['python3','/app/infra/media_adapter.py','prepare',s['url'],str(folder),selected],capture_output=True,text=True,timeout=180)
            row['prepareExit']=p.returncode
            data=json.loads(p.stdout.strip().splitlines()[-1]);row['prepare']=data.get('error') or 'ready'
            if p.returncode==0:
                row['bytes']=data['size'];row['inputBytes']=data['inputBytes']
                probe=subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name:format=duration,size','-of','json',str(folder/'media.mp4')],text=True)
                row['probe']=json.loads(probe)
                # Preserve proof only for this run; no old file is considered success.
                target=evidence/(s['name']+'-secure.mp4')
                target.write_bytes((folder/'media.mp4').read_bytes())
    except subprocess.TimeoutExpired:row['error']='SOURCE_TIMEOUT'
    except Exception:row['error']='ADAPTER_FAILED'
    finally:
        if folder.parent==pathlib.Path('/media'):shutil.rmtree(folder,ignore_errors=True)
    report['samples'].append(row);(evidence/'p0-secure.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(row,ensure_ascii=False),flush=True)
