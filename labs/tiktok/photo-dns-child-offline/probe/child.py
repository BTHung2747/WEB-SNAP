"""Import-only child, executed with -c to retain the production cwd search semantics."""
import hashlib,importlib,importlib.util,json,os,pathlib,sys
names=('tiktok_policy','tiktok_policy.dns_helper','tiktok_policy.dns_ipc','tiktok_policy.dns_admission','tiktok_policy.runtime','aiohappyeyeballs')
rows=[]
for name in names:
    try:
        spec=importlib.util.find_spec(name)
        if spec is None:rows.append(dict(module=name,found=False,code='NOT_FOUND'));continue
        module=importlib.import_module(name);path=pathlib.Path(module.__file__).resolve()
        rows.append(dict(module=name,found=True,path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    except (ImportError,ModuleNotFoundError):rows.append(dict(module=name,found=False,code='IMPORT_ERROR'))
result=dict(interpreter=sys.executable,version=list(sys.version_info[:3]),cwd=os.getcwd(),sysPath=sys.path,pythonPath=os.environ.get('PYTHONPATH'),modules=rows,probe='IMPORT_ONLY_NO_DNS_NO_SOCKET')
sys.stdout.write(json.dumps(result,separators=(',',':')))
sys.exit(0 if all(row['found'] for row in rows) else 21)
