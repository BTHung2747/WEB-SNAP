"""Actual source supervisor entry; no resources/IO when the explicit switch is absent."""
import os,sys
def main():
    if os.environ.get('STEP5_EXECUTE_SOURCE')!='1':
        print('{"status":"SOURCE_DISABLED","sourceGrant":false,"sourceExecutionStarted":false,"sourceCalls":0}');return 78
    sys.path.insert(0,'/lab')
    from supervisor import run
    return run(['bash','/lab/start.sh','source'])
if __name__=='__main__':
    try:code=main()
    except BaseException:print('{"error":"SOURCE_ENTRY_FAILED"}');code=1
    sys.exit(code)
