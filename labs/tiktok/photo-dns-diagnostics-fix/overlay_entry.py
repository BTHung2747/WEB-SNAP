"""Thin lab overlay: retain the frozen DNS-path fix entry, select the new projection."""
import importlib,pathlib,sys
def bind(base=pathlib.Path('/base')):
    overlay=pathlib.Path(__file__).resolve().parent;base=pathlib.Path(base).resolve()
    sys.path[:0]=[str(overlay),str(base),'/repo/apps/egress/src','/repo/apps/egress/vendor']
    collector=importlib.import_module('proxy_collect')
    entry=importlib.import_module('proxy_entry')
    if pathlib.Path(collector.__file__).resolve()!=overlay/'proxy_collect.py' or pathlib.Path(entry.__file__).resolve()!=base/'proxy_entry.py':raise ValueError('OVERLAY_IMPORT_PATH')
    return collector,entry
def main():
    import os
    if os.environ.get('STEP5_EXECUTE_SOURCE')!='1':return 78
    collector,entry=bind()
    return entry.main()
if __name__=='__main__':
    try:code=main()
    except BaseException:print('{"error":"OVERLAY_ENTRY_FAILED"}');code=1
    sys.exit(code)
