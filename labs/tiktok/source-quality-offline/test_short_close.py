"""Focused successor for resolver construction/absolute-deadline cleanup only."""
import hashlib,json,os,pathlib,time,subprocess,sys,uuid
from unittest.mock import patch
import requests
from tiktok import shortlink
from tiktok.photo_contract import PhotoError
from tiktok.photo_core import PhotoBudget,PhotoLimits
URL='https://vt.tiktok.com/FAKEcode'
os.environ.update(WED_MEDIA_PROFILE='tiktok-short-analyze',WED_MEDIA_SELECTION='ts1_'+hashlib.sha256(URL.encode()).hexdigest())
base=requests.Session();base.cookies.set('fixture','FAKECOOKIE',domain='vt.tiktok.com');closed=[]
original_close=base.close
base.close=lambda:(closed.append(1),original_close())[-1]
error=RuntimeError('FIXTURE_CONSTRUCTION')
with patch.object(shortlink.requests,'Session',return_value=base),patch.object(shortlink,'PhotoProxyAdapter',side_effect=error):
    try:shortlink.resolve_short(URL,time.monotonic()+30)
    except RuntimeError as caught:assert caught is error
    else:raise AssertionError('constructor error')
assert closed==[1] and not base.cookies
base=requests.Session();base.cookies.set('fixture','FAKECOOKIE',domain='vt.tiktok.com');sends=[]
base.get_adapter=lambda url:sends.append(url)
try:shortlink.resolve_short(URL,time.monotonic()-1,lambda:base)
except shortlink.ShortError as caught:assert caught.args==('SOURCE_TIMEOUT',)
else:raise AssertionError('absolute deadline')
assert sends==[] and not base.cookies
for code in ('LIMIT_EXCEEDED','SOURCE_TIMEOUT','INVALID_ASSET_PATH'):
    assert shortlink.public_error(PhotoError(code))==code
assert shortlink.public_error(shortlink.ShortError('https://FAKE_SECRET'))=='CONTENT_UNAVAILABLE'
end=time.monotonic()+.05
budget=PhotoBudget(PhotoLimits(),'analyze',deadline=end)
assert budget.deadline<=end and budget.prepare_end<=end
root=pathlib.Path('/out/media');root.mkdir();folder=root/str(uuid.uuid4());folder.mkdir()
env={**os.environ,'TIKTOK_ADAPTER_ENABLED':'1','TIKTOK_PHOTO_ENABLED':'1','TIKTOK_VIDEO_ENABLED':'1','VERIFIED_PLATFORMS':'tiktok','MEDIA_ROOT':str(root)}
p=subprocess.run([sys.executable,'/fixture/test_short.py','--child','analyze','photo',str(folder),'-'],env=env,capture_output=True,text=True,timeout=35)
assert p.returncode==0
assert json.loads(p.stdout)['resolved']['kind']=='photo'
assert json.loads((pathlib.Path('/out')/(folder.name+'-analyze.json')).read_text())['shortGets']==2
for url in ('https://tiktok.com/@'+'a'*2048+'/video/1234567890123456', 'https://www.tiktok.com/t/a/extra'):
    try:shortlink.route(url)
    except shortlink.ShortError:pass
    else:raise AssertionError('URL policy')
pathlib.Path('/out/short-close-result.json').write_text(json.dumps({'status':'PASS','sourceRequests':0,
    'cases':['construction-error-closes-session-clears-cookie','expired-deadline-zero-send-cookie-clear','URL-length-and-path-boundary','photo-errors-preserved-unknown-error-redacted','photo-absolute-deadline-and-real-parser-short-child'],
    'sameConstructionException':True},indent=2))
print('PASS focused short construction / deadline / URL limits')
