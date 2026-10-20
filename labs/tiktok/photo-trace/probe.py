import hashlib,inspect,json,pathlib,ssl,sys,socket,socketserver
import requests,urllib3,certifi
sys.path.insert(0,'/app/apps/media/src')
from tiktok.core import versions
assert sys.version.split()[0]=='3.11.2'
print(json.dumps({'python':sys.version.split()[0],'pins':versions(),'caBundle':requests.adapters.DEFAULT_CA_BUNDLE_PATH,
 'socketSHA':hashlib.sha256(pathlib.Path(inspect.getfile(socket)).read_bytes()).hexdigest(),
 'socketserverSHA':hashlib.sha256(pathlib.Path(inspect.getfile(socketserver)).read_bytes()).hexdigest(),
 'adapterSHA':hashlib.sha256(pathlib.Path(inspect.getfile(requests.adapters.HTTPAdapter)).read_bytes()).hexdigest(),
 'connectionSHA':hashlib.sha256(pathlib.Path(inspect.getfile(urllib3.connection.HTTPSConnection)).read_bytes()).hexdigest(),
 'core':[{'path':str(p.relative_to(pathlib.Path('/app/apps/media/src/tiktok'))),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 for p in pathlib.Path('/app/apps/media/src/tiktok').rglob('*') if p.is_file() and 'node_modules' not in p.parts and '__pycache__' not in p.parts]}))

