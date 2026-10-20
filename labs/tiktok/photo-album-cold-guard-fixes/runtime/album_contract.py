"""AGPL-3.0: public album selection/ownership glue; no source parser or transport."""
import hashlib,json,os,pathlib,re,time
VERSION='tt-photo-album-v1'
MIB=1024*1024
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def key(value):return hashlib.sha256(canonical(value)).hexdigest()
def require(ok,code):
    if not ok:raise RuntimeError(code)
def integer(v,lo,hi):return type(v) is int and lo<=v<=hi
def summary(private,expected):
    require(type(private) is dict and private.get('id')==expected and private.get('type')=='photo','ALBUM_METADATA')
    images=private.get('images');require(type(images) is list and 1<=len(images)<=50,'ALBUM_METADATA')
    descriptors=[]
    for i,row in enumerate(images,1):
        require(type(row) is dict and type(row.get('index')) is int and row['index']==i,'ALBUM_INDEX')
        w,h=row.get('width'),row.get('height')
        require(integer(w,1,8192) and integer(h,1,8192) and w*h<=16000000,'ALBUM_DIMENSIONS')
        # Cobalt picker already checked URLs with WHATWG URL; no URL enters a public fingerprint.
        require(type(row.get('url')) is str,'ALBUM_URL')
        descriptors.append(dict(index=i,width=w,height=h,itemKey=key([expected,'photo',i,w,h])))
    value=dict(version=VERSION,id=expected,type='photo',imageCount=len(images),images=descriptors)
    value['snapshotKey']=key(value)
    return value
def validate_summary(value,expected):
    require(type(value) is dict and set(value)=={'version','id','type','imageCount','images','snapshotKey'},'ALBUM_METADATA')
    require(value['version']==VERSION and value['id']==expected and value['type']=='photo','ALBUM_METADATA')
    n=value['imageCount'];require(integer(n,1,50) and type(value['images']) is list and len(value['images'])==n,'ALBUM_METADATA')
    rows=[]
    for i,row in enumerate(value['images'],1):
        require(type(row) is dict and set(row)=={'index','width','height','itemKey'},'ALBUM_METADATA')
        require(type(row['index']) is int and row['index']==i,'ALBUM_INDEX')
        w,h=row['width'],row['height'];require(integer(w,1,8192) and integer(h,1,8192) and w*h<=16000000,'ALBUM_DIMENSIONS')
        require(type(row['itemKey']) is str and row['itemKey']==key([expected,'photo',i,w,h]),'ALBUM_KEY')
        rows.append(row)
    base={k:v for k,v in value.items() if k!='snapshotKey'}
    require(type(value['snapshotKey']) is str and value['snapshotKey']==key(base),'ALBUM_KEY')
    return value
def selection(value,meta):
    require(type(value) is dict and set(value)=={'version','mode','snapshotKey','indices'},'ALBUM_SELECTION')
    require(value['version']==VERSION and type(value['mode']) is str and value['mode'] in ('single','subset','all'),'ALBUM_SELECTION')
    require(type(value['snapshotKey']) is str and value['snapshotKey']==meta['snapshotKey'],'ALBUM_SNAPSHOT')
    indices=value['indices'];require(type(indices) is list and 1<=len(indices)<=5,'ALBUM_SELECTION_LIMIT')
    require(all(integer(i,1,meta['imageCount']) for i in indices) and indices==sorted(set(indices)),'ALBUM_SELECTION_ORDER')
    require(value['mode']!='single' or len(indices)==1,'ALBUM_SELECTION')
    require(value['mode']!='all' or (meta['imageCount']<=5 and indices==list(range(1,meta['imageCount']+1))),'ALBUM_SELECTION_LIMIT')
    return indices
def filename(i):return f'image-{i:04d}.jpg'
def file_rows(rows,indices,meta):
    require(type(rows) is list and len(rows)==len(indices),'FILE_LEDGER')
    for i,row in zip(indices,rows):
        require(type(row) is dict and set(row)=={'index','itemKey','file','bytes','sha256','contract'},'FILE_LEDGER')
        require(type(row['index']) is int and row['index']==i and type(row['file']) is str and row['file']==filename(i),'FILE_LEDGER')
        require(type(row['itemKey']) is str and row['itemKey']==meta['images'][i-1]['itemKey'],'FILE_LEDGER')
        require(integer(row['bytes'],1,16*MIB) and type(row['sha256']) is str and re.fullmatch('[a-f0-9]{64}',row['sha256']) is not None,'FILE_LEDGER')
        c=row['contract'];require(type(c) is dict and set(c)=={'magic','mime','width','height','pixels','frames','fullDecode'},'FILE_LEDGER')
        require(c['magic']=='jpeg' and type(c['magic']) is str and c['mime']=='image/jpeg' and type(c['mime']) is str and type(c['fullDecode']) is str and c['fullDecode']=='PASS','FILE_LEDGER')
        require(integer(c['frames'],1,1) and integer(c['width'],1,8192) and integer(c['height'],1,8192) and integer(c['pixels'],1,16000000),'FILE_LEDGER')
        require(c['width']==meta['images'][i-1]['width'] and c['height']==meta['images'][i-1]['height'] and c['pixels']==c['width']*c['height'],'FILE_LEDGER')
    return rows
def item_deadline(prepare_end,now=None):
    now=time.monotonic() if now is None else now
    require(prepare_end-now>10,'PREPARE_DEADLINE')
    return min(now+60,prepare_end-10)
class Ledger:
    """Parent-created authority; worker packets can never authorize deletion."""
    def __init__(self,folder):
        self.root=pathlib.Path(folder).resolve();self.names=[x for i in range(1,51) for x in (filename(i),filename(i)+'.part')]
        self.prior={n for n in self.names if os.path.lexists(self.root/n)}
        self.sentinels={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.root.iterdir() if p.is_file() and not p.is_symlink() and p.name not in self.names}
        self.prior_hashes={n:hashlib.sha256((self.root/n).read_bytes()).hexdigest() for n in self.prior if (self.root/n).is_file() and not (self.root/n).is_symlink()}
        self.prior_links={n:os.readlink(self.root/n) for n in self.prior if (self.root/n).is_symlink()}
        self.selected=[]
    def register(self,indices):
        require(not self.selected,'OWNERSHIP_REGISTERED')
        names=[n for i in indices for n in (filename(i),filename(i)+'.part')]
        require(not any(n in self.prior or os.path.lexists(self.root/n) for n in names),'OUTPUT_COLLISION')
        self.selected=names
    def snapshot(self):return dict(policy='SOURCE_INDEX_1_TO_50',candidates=self.names,preexisting=sorted(self.prior),sentinels=self.sentinels,preexistingHashes=self.prior_hashes,preexistingLinks=self.prior_links,selected=self.selected)
    def cleanup(self):
        removed=[]
        # Only the finite policy registered before spawn, minus all preexisting names.
        for n in self.names:
            p=self.root/n
            if n not in self.prior and os.path.lexists(p):
                require(p.parent==self.root and not p.is_dir(),'OUTPUT_OWNERSHIP')
                p.unlink();removed.append(n)
        return removed
    def preserved(self):
        return (all((self.root/n).exists() and not (self.root/n).is_symlink() and hashlib.sha256((self.root/n).read_bytes()).hexdigest()==sha for n,sha in {**self.sentinels,**self.prior_hashes}.items())
                and all((self.root/n).is_symlink() and os.readlink(self.root/n)==target for n,target in self.prior_links.items())
                and all(os.path.lexists(self.root/n) for n in self.prior))
