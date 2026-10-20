"""Targeted offline unit probes; whole HTTPS pipeline is separately run by run.ps1."""
import copy,gzip,hashlib,io,json,pathlib,subprocess,sys,tempfile,time
import urllib3
from album_contract import *
from album_budget import AlbumBudget
from tiktok.core import BoundedBody
from tiktok.prepare_operations import Operations
from dns_admission import admit,stats_valid,strict_loads
from accounting import receipt
ID='7678209751167110421';results=[]
def check(name,fn):
    begin=time.monotonic()
    try:fn();results.append(dict(case=name,status='PASS',elapsed=time.monotonic()-begin))
    except Exception as error:
        results.append(dict(case=name,status='FAIL',errorClass=type(error).__name__,elapsed=time.monotonic()-begin));raise
def deny(fn):
    try:fn()
    except Exception:return
    raise AssertionError('MUST_DENY')
def private(n):return dict(id=ID,type='photo',images=[dict(index=i,width=8192,height=1,url='https://fixture.invalid/FAKE') for i in range(1,n+1)])
def choose(meta,mode,indices):return dict(version=VERSION,mode=mode,snapshotKey=meta['snapshotKey'],indices=indices)
def equal(a,b):assert a==b
def main():
    meta=summary(private(50),ID)
    packet=canonical(dict(stage='metadata',status='PASS',summary=meta,rows=[],metadataBytes=0))
    check('metadata50_actual_serialization',lambda:require(len(packet)+1<=8192,'PACKET_LIMIT'))
    check('summary_roundtrip',lambda:equal(validate_summary(copy.deepcopy(meta),ID),meta))
    for label,mut in [('bool-index',lambda x:x['images'][0].update(index=True)),('float-width',lambda x:x['images'][-1].update(width=64.0)),('tail-null',lambda x:x['images'][-1].update(height=None)),('pixel-cap',lambda x:x['images'][-1].update(height=8192)),('wrong-id',lambda x:x.update(id='0000000000000000'))]:
        value=private(50);mut(value);check(label,lambda v=value:deny(lambda:summary(v,ID)))
    for label,mode,indices in [('unsorted','subset',[3,1]),('duplicate','subset',[1,1]),('bool','single',[True]),('float','single',[1.0]),('six','subset',[1,2,3,4,5,6]),('all50','all',[1,2,3,4,5]),('out-of-range','single',[51])]:
        check('selection-'+label,lambda m=mode,i=indices:deny(lambda:selection(choose(meta,m,i),meta)))
    check('selection-subset',lambda:equal(selection(choose(meta,'subset',[1,3,50]),meta),[1,3,50]))
    check('selection-single',lambda:equal(selection(choose(meta,'single',[50]),meta),[50]))
    altered=choose(meta,'single',[1]);altered['snapshotKey']='0'*64
    check('selection-snapshot',lambda:deny(lambda:selection(altered,meta)))
    good=dict(index=1,itemKey=meta['images'][0]['itemKey'],file=filename(1),bytes=1,sha256='a'*64,contract=dict(magic='jpeg',mime='image/jpeg',width=8192,height=1,pixels=8192,frames=1,fullDecode='PASS'))
    check('file-ledger-valid',lambda:equal(file_rows([good],[1],meta),[good]))
    for label,mutate in [('bool-index',lambda x:x.update(index=True)),('bool-bytes',lambda x:x.update(bytes=True)),('float-bytes',lambda x:x.update(bytes=1.0)),('array-sha',lambda x:x.update(sha256=['a'*64])),('traversal',lambda x:x.update(file='../keep.bin')),('bool-frames',lambda x:x['contract'].update(frames=True)),('float-width',lambda x:x['contract'].update(width=8192.0)),('wrong-pixels',lambda x:x['contract'].update(pixels=1))]:
        value=copy.deepcopy(good);mutate(value);check('file-ledger-'+label,lambda v=value:deny(lambda:file_rows([v],[1],meta)))
    check('deadline-exhausted-before-spawn',lambda:deny(lambda:item_deadline(109,100)))
    check('deadline-clamp',lambda:equal(item_deadline(150,100),140))
    check('deadline-item60',lambda:equal(item_deadline(280,100),160))
    b=AlbumBudget(time.monotonic()+30);b.sent();b.total=123;b.network_total=123
    b.begin_album(2,time.monotonic()+180);b.begin_item();b.sent();b.begin_item();b.sent()
    check('budget-no-reset',lambda:equal((b.requests,b.image_requests,b.total,b.network_total),(3,2,123,123)))
    check('budget-request-overflow',lambda:deny(b.sent))
    check('budget-prepare-reset-denied',lambda:deny(b.prepare))
    check('aggregate-output',lambda:deny(lambda:b.write_check(0,33*MIB)))
    def body_cap(compressed=False,total=False):
        budget=AlbumBudget(time.monotonic()+30);budget.response_cap=100;budget.total_cap=60 if total else 100
        payload=b'X'*101
        raw=urllib3.HTTPResponse(body=io.BytesIO(gzip.compress(payload) if compressed else payload),headers={'content-encoding':'gzip'} if compressed else {},preload_content=False,decode_content=False)
        response=type('Reply',(),{'raw':raw,'close':lambda self:raw.close()})()
        deny(lambda:BoundedBody(response,budget,dict(decodedBytes=0)).read())
        require(budget.failure=='BYTE_LIMIT','BYTE_LIMIT')
    check('response-cap-scaled',body_cap);check('decompressed-cap-scaled',lambda:body_cap(True));check('cumulative-cap-scaled',lambda:body_cap(total=True))
    with tempfile.TemporaryDirectory() as d:
        root=pathlib.Path(d);(root/'keep.bin').write_bytes(b'SENTINEL');ledger=Ledger(root);ledger.register([1,2]);
        for n in ledger.selected:(root/n).write_bytes(b'OWNED')
        check('rollback-sentinel',lambda:(equal(len(ledger.cleanup()),4),require(ledger.preserved(),'SENTINEL')))
        (root/filename(1)).write_bytes(b'PREEXISTING');other=Ledger(root)
        check('collision-denied',lambda:deny(lambda:other.register([1])))
        check('preexisting-preserved',lambda:(other.cleanup(),equal((root/filename(1)).read_bytes(),b'PREEXISTING')))
        (root/filename(1)).write_bytes(b'CHANGED')
        check('preexisting-tamper-detected',lambda:require(not other.preserved(),'SENTINEL'))
        (root/filename(2)).symlink_to(root/'keep.bin');third=Ledger(root)
        check('symlink-denied',lambda:deny(lambda:third.register([2])))
        check('native-exhausted',lambda:deny(lambda:Operations(time.monotonic()-1,root=root).native('DECODE',['false'],30)))
        ops=Operations(time.monotonic()+3,root=root,sink='kill.jsonl')
        check('native-timeout-reap',lambda:deny(lambda:ops.native('DECODE',[sys.executable,'-c','import time;time.sleep(5)'],.1)))
        require(ops.terminals[-1]['returncode']==-9,'REAP')
    row=[2,1,6,'',['1.1.1.1',443]];values=[copy.deepcopy(row) for _ in range(129)]
    admitted,stats,_,_=admit(values,time.monotonic()+1)
    check('dns-v4-duplicate129',lambda:require(len(admitted)==1 and stats_valid(stats) and stats['validatedCount']==129,'DNS'))
    values[-1][4][0]='127.0.0.1'
    check('dns-private-duplicate-tail',lambda:equal(admit(values,time.monotonic()+1)[0],[]))
    wrong=copy.deepcopy(stats);wrong['admittedCount']=True
    check('dns-scalar-bool',lambda:require(not stats_valid(wrong),'DNS'))
    check('dns-duplicate-json',lambda:deny(lambda:strict_loads('{"x":1,"x":2}')))
    check('missing-byte-structured-deny',lambda:require(not receipt({'stage':'metadata','metadataPacket':{'status':'PASS','rows':[{'phase':'metadata','index':1,'method':'GET','url':'[url-redacted]'}]}},[],observer_present=True,selected_count=5)['exact'],'ACCOUNTING'))
    out=dict(status='PASS_TARGETED_OFFLINE',actualExit=0,cases=results,count=len(results),metadata50PublicPacketBytes=len(packet)+1,sourceCalls=0,sourceGate=False,fixtureScaledCaps=True,utc=time.time())
    pathlib.Path('/out/probes.json').write_text(json.dumps(out,indent=2));print(json.dumps(dict(status=out['status'],count=out['count'],metadata50PublicPacketBytes=out['metadata50PublicPacketBytes'])))
if __name__=='__main__':
    try:main()
    except Exception:
        pathlib.Path('/out/probes.json').write_text(json.dumps(dict(status='FAIL_TARGETED_OFFLINE',actualExit=20,cases=results),indent=2));print('TARGETED_PROBE_FAILURE');sys.exit(20)
