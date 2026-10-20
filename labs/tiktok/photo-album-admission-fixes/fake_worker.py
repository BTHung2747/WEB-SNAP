"""Offline provisional PASS followed by exit20/hang, through the real parent."""
import json,pathlib,sys,time
from album_contract import summary
meta=summary(dict(id='7678209751167110421',type='photo',images=[dict(index=i,width=64,height=64,url='https://fixture.invalid/FAKE') for i in (1,2)]),'7678209751167110421')
print(json.dumps(dict(stage='metadata',status='PASS',summary=meta,rows=[])),flush=True)
command=json.loads(input())
for name in command['ownedNames']:pathlib.Path('/out',name).write_bytes(b'OWNED_FAKE')
print(json.dumps(dict(stage='prepare',status='PASS',files=[],rows=[])),flush=True)
if sys.argv[1]=='native-nonzero':sys.exit(20)
time.sleep(180)
