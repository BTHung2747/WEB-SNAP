"""Run only against samples supplied by an operator who has permission to download."""
import json, subprocess, pathlib, sys, datetime
out = pathlib.Path('/evidence'); out.mkdir(exist_ok=True)
samples = json.loads(pathlib.Path(sys.argv[1]).read_text())
report = {'date': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'version': subprocess.check_output(['yt-dlp','--version'], text=True).strip(), 'samples': []}
for sample in samples:
    row = {'name': sample['name'], 'platform': sample['platform'], 'url': sample['url'], 'expected': sample.get('expected','video')}
    folder = out / sample['name']; folder.mkdir(exist_ok=True)
    try:
        p = subprocess.run(['yt-dlp','--ignore-config','--no-playlist','--no-cache-dir','--js-runtimes','node','--socket-timeout','10','--retries','1','--max-filesize','50M','--format','bv[height<=360][ext=mp4][vcodec^=avc1]+ba[ext=m4a]/b[height<=360][ext=mp4]','--merge-output-format','mp4','--output',str(folder/'media.%(ext)s'),'--',sample['url']], capture_output=True,text=True,timeout=120)
        row['exit'] = p.returncode
        # Logs may contain signed source URLs. Retain only normalized outcome.
        row['result'] = 'downloaded' if p.returncode == 0 else ('AUTH_REQUIRED' if any(x in p.stderr.lower() for x in ['sign in','login','log in','private']) else 'CONTENT_UNAVAILABLE')
        markers = ['403','429','requested format is not available','no video formats','unable to download','timed out','name or service not known','temporary failure','sign in','confirm','javascript','proxy','certificate']
        row['diagnosticMarkers'] = [m for m in markers if m in p.stderr.lower()]
        for f in (folder.glob('media.*') if p.returncode == 0 else []):
            if f.suffix in ('.part','.ytdl'): continue
            probe = subprocess.run(['ffprobe','-v','error','-show_entries','stream=codec_type,codec_name:format=duration,size','-of','json',str(f)],capture_output=True,text=True)
            row['probe'] = json.loads(probe.stdout) if probe.returncode == 0 else {'error':'invalid media'}
    except subprocess.TimeoutExpired:
        row['result'] = 'SOURCE_TIMEOUT'
    report['samples'].append(row)
    (out/'p0-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps(row,ensure_ascii=False),flush=True)
