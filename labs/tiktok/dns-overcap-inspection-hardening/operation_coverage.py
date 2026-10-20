"""Bounded full operation evidence, independent of physical cleanup or TCP outcome."""
import json,sys
PAIRED={'DNS_HELPER','SOCKET_CREATE','LIBRARY_SELECT','REGISTRY_CLOSE','TCP_CONNECT','FIXTURE_TCP','CONNECT_200','REQUEST_FINISH','REQUEST_SHUTDOWN','REQUEST_CLOSE','SERVER_SERVE_CLOSE','CLOSURE_BARRIER'}
SNAPSHOTS={'REQUEST_ACCEPT','REQUEST_ABORT','WORKER_RETURN','DNS_RESULT','TUNNEL_CLOSE'}
def operation_coverage(rows):
    states={};bad=set()
    if not isinstance(rows,list) or len(rows)>256:return {'status':'INCOMPLETE','reasonCodes':['ROW_CAP'],'operations':0}
    for r in rows:
        if not isinstance(r,dict):bad.add('ROW');continue
        phase=r.get('phase');event=r.get('event');owner=r.get('ownerID')
        if not isinstance(owner,str) or len(owner)!=16:bad.add('OWNER');continue
        if phase in SNAPSHOTS:
            if event!='END':bad.add('SNAPSHOT_EVENT')
            continue
        if phase not in PAIRED:bad.add('PHASE');continue
        index=r.get('operationIndex')
        if type(index) is not int or not 1<=index<=64:bad.add('OPERATION_INDEX');continue
        key=(owner,phase,index);previous=states.get(key)
        if event=='BEGIN':
            if previous is not None:bad.add('DUPLICATE_REOPEN')
            else:states[key]='OPEN'
        elif event in ('END','ERROR'):
            if previous!='OPEN':bad.add('TERMINAL_ORDER')
            else:states[key]=event
        else:bad.add('EVENT')
    if any(v=='OPEN' for v in states.values()):bad.add('MISSING_TERMINAL')
    return {'status':'INCOMPLETE' if bad else 'COMPLETE','reasonCodes':sorted(bad),'operations':len(states)}
if __name__=='__main__':
    try:
        raw=sys.stdin.buffer.read(128*1024+1);assert len(raw)<=128*1024
        p=json.loads(raw);coverage=operation_coverage(p['rows']);accepted=coverage['status']=='COMPLETE' and not p.get('incomplete') and p['socketsLeft']==0
    except (ValueError,TypeError,KeyError,AssertionError):accepted=False;coverage={'status':'INCOMPLETE'}
    print(json.dumps({'scope':'OPERATION_COVERAGE_GATE','accepted':accepted,'coverage':coverage}));sys.exit(0 if accepted else 20)
