"""Demonstrate public loader behavior behind the offline fixture guard; no HTTP."""
import importlib.util,json,os,pathlib,requests,runpy,sys
root=pathlib.Path('/out');(root/'provider-job').mkdir()
os.environ.update(TIKTOK_APP_FIXTURE='1',FIXTURE_CONTROL='/out/control',FIXTURE_MEDIA_FILE='/tmp/unused.jpg')
original=requests.Session
sys.argv=['worker.py','analyze','https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421','/out/provider-job','7678209751167110421']
path='/app/apps/media/src/tiktok/photo_lab/sitecustomize.py'
old=runpy.run_path(path)
assert 'FakeSession' not in old
spec=importlib.util.spec_from_file_location('provider_proof',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
assert hasattr(module,'FakeSession')
requests.Session=original
result={'python':sys.version.split()[0],'core':[],'runpyGuardClassDefined':False,'importlibGuardClassDefined':True,'sourceCalls':0}
print(json.dumps(result))

