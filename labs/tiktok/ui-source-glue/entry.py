"""Passive app entry for a future authorized owner; never starts an API workflow."""
def main():
    import os
    if os.environ.get('STEP5_EXECUTE_SOURCE')!='1' or os.environ.get('STEP5_OFFLINE_TEST') is not None:return 78
    import pathlib,sys
    sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
    from handshake import contract
    contract(pathlib.Path('/control'),check_owner_clock=False) # Host and Linux ticks are not comparable.
    sys.path.insert(0,'/lab')
    from supervisor import run
    return run(['bash','/labs/tiktok/ui-source-glue/start.sh'])
if __name__=='__main__':
    try:code=main()
    except BaseException:code=78
    raise SystemExit(code)
