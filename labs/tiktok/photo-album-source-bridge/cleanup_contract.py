"""Runner readonly finite ownership policy; worker packets never grant deletion."""
import hashlib,os,pathlib,re
from album_contract import filename,require
def validated(settings):
    require(type(settings) is dict,'CLEANUP_POLICY_INVALID')
    p=settings.get('cleanupPolicy');require(type(p) is dict and set(p)=={'version','policy','candidates','preexisting','preexistingHashes','sentinels'},'CLEANUP_POLICY_INVALID')
    require(type(p['version']) is int and p['version']==1 and type(p['policy']) is str and p['policy']=='SOURCE_INDEX_1_TO_50','CLEANUP_POLICY_INVALID')
    candidates=[n for i in range(1,51) for n in (filename(i),filename(i)+'.part')]
    require(type(p['candidates']) is list and len(p['candidates'])==100 and all(type(n) is str for n in p['candidates']) and p['candidates']==candidates,'CLEANUP_POLICY_INVALID')
    prior=p['preexisting'];require(type(prior) is list and all(type(n) is str and n in candidates for n in prior) and len(set(prior))==len(prior),'CLEANUP_POLICY_INVALID')
    hashes=p['preexistingHashes'];sentinels=p['sentinels']
    require(type(hashes) is dict and set(hashes)==set(prior) and type(sentinels) is dict and 1<=len(sentinels)<=32,'CLEANUP_POLICY_INVALID')
    for n,h in {**hashes,**sentinels}.items():
        require(type(n) is str and re.fullmatch('[A-Za-z0-9][A-Za-z0-9_.-]{0,127}',n) is not None and n not in ('.','..') and type(h) is str and re.fullmatch('[a-f0-9]{64}',h) is not None,'CLEANUP_POLICY_INVALID')
    require(not(set(sentinels)&set(candidates)),'CLEANUP_POLICY_INVALID')
    require(type(settings.get('preexisting')) is list and settings['preexisting']==prior and settings.get('sentinels')==sentinels,'CLEANUP_POLICY_CONFLICT')
    return p
def disposition(settings,root,rollback):
    removed=[]
    try:p=validated(settings)
    except Exception:return dict(status='DENIED_NO_VALID_READONLY_POLICY',removed=[],preserved='UNKNOWN',limitation='OUTPUTS_RETAINED_NO_DELETION_AUTHORITY')
    root=pathlib.Path(root)
    preserved=True
    for name,sha in {**p['sentinels'],**p['preexistingHashes']}.items():
        path=root/name
        try:ok=path.is_file() and not path.is_symlink() and hashlib.sha256(path.read_bytes()).hexdigest()==sha
        except OSError:ok=False
        preserved=preserved and ok
    errors=0
    if rollback:
        for name in p['candidates']:
            if name in p['preexisting']:continue
            path=root/name
            try:
                if os.path.lexists(path):
                    if path.is_dir():errors+=1;continue
                    path.unlink();removed.append(name) # unlink symlink itself, never follow target
            except OSError:errors+=1
    return dict(status='COMPLETE' if preserved and errors==0 else 'FAIL_PRESERVATION_OR_IO',removed=removed,preserved=preserved,errors=errors,limitation=None)
