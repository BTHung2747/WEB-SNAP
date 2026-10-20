"""Lab-only numeric receipt acceptance. No network, metadata extractor or file acceptance."""
import json,sys
def main():
    try:
        raw=sys.stdin.buffer.read(4097)
        if len(raw)>4096:return 20
        state=json.loads(raw);trace=state['trace'];physical=state['physical']
        if type(trace['incomplete']) is not bool or trace['incomplete']:return 20
        if trace['totalCap']!=256 or trace['connectionCap']!=32 or not 0<=trace['rows']<=256:return 20
        if physical['requestSocketsLeft']!=0 or physical['workerThreadsLeft']!=0 or physical['errors']!=0:return 20
        return 0
    except Exception:return 20
if __name__=='__main__':
    rc=main();print('DIAGNOSTIC_PASS' if rc==0 else 'DIAGNOSTIC_FAIL',flush=True);sys.exit(rc)
