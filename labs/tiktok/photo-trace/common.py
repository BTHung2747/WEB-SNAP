"""AGPL-3.0 lab wiring: numeric receipts and exact mounted-source inventory."""
import hashlib,json,pathlib,sys,time
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import versions
ROOTS={'integration':pathlib.Path('/integration'),'photo':pathlib.Path('/app/apps/media/src/tiktok/photo_lab'),
       'trace':pathlib.Path('/trace_lab'),'core':pathlib.Path('/app/apps/media/src/tiktok')}
def inventory():
    rows=[]
    for label,root in ROOTS.items():
        for p in root.rglob('*'):
            if not p.is_file() or any(s in p.parts for s in ('node_modules','__pycache__','photo_lab')) and label=='core':continue
            if '__pycache__' in p.parts or 'node_modules' in p.parts:continue
            rows.append({'path':label+'/'+str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    return sorted(rows,key=lambda r:r['path'])
def summary_valid(summary,rows):
    if not isinstance(summary,dict):return False
    if summary.get('final') is not True or summary.get('incomplete') is not False or summary.get('active')!=0:return False
    if summary.get('unhandled')!=0 or summary.get('totalCap')!=256 or summary.get('connectionCap')!=32:return False
    if summary.get('rows')!=len(rows) or not 0<=len(rows)<=256:return False
    entries=summary.get('connections')
    if not isinstance(entries,list) or len(entries)!=summary.get('connectionCount'):return False
    for item in entries:
        actual=[r for r in rows if r.get('connectionID')==item.get('connectionID')]
        if item.get('incomplete') is not False or item.get('closedRecorded') is not True:return False
        if item.get('rows')!=len(actual) or not 1<=len(actual)<=32:return False
        if len([r for r in actual if r.get('boundary')=='TUNNEL_CLOSE' and r.get('event')=='END'])!=1:return False
    return sum(i['rows'] for i in entries)==len(rows)

