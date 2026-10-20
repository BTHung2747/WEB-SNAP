"""Offline import/capability and installed source/dependency inventory."""
import hashlib
import importlib.metadata as md
import json
import pathlib
import runpy
import sys
runpy.run_path('/p37/cap_check.py', run_name='__main__')
path = pathlib.Path('/out/capability.json')
rep = json.loads(path.read_text())
rep['all_distributions'] = {d.metadata['Name']: d.version for d in md.distributions()}
root = pathlib.Path(md.distribution('yt-dlp').locate_file('yt_dlp'))
rep['installed_yt_dlp_sources'] = {str(f): hashlib.sha256((root / f).read_bytes()).hexdigest()
                                   for f in ('networking/common.py', 'networking/_curlcffi.py', 'extractor/tiktok.py')}
rep['no_request_made'] = True
path.write_text(json.dumps(rep, indent=2), encoding='utf-8')
if rep.get('ydl_error') or rep['yt_dlp'] != '2026.08.19':
    sys.exit(1)
