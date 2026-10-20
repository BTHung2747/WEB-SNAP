"""Typed bounded proxy receipt↔trace validation; no network or scheduling behavior."""
import json,math,re,sys
from operation_coverage import operation_coverage
REGISTRY_PHASES={'LIBRARY_SELECT','SOCKET_CREATE','REGISTRY_CLOSE'}
TCP_PHASES={'TCP_CONNECT','FIXTURE_TCP'}
def ident(v):return isinstance(v,str) and re.fullmatch('[a-f0-9]{16}',v) is not None
def integer(v,lo,hi):return type(v) is int and lo<=v<=hi
def number(v,lo,hi):return type(v) in (int,float) and math.isfinite(v) and lo<=v<=hi
def near(a,b):return number(a,0,10) and number(b,0,10) and abs(a-b)<=1e-6
def validate(receipts,rows):
    reasons=set()
    def bad(code):reasons.add(code)
    def result():return {'version':1,'status':'PARTIAL' if reasons else 'COMPLETE','accepted':not reasons,'reasonCodes':sorted(reasons)[:48],'originReceipt':'UNKNOWN'}
    if not isinstance(receipts,list) or not 1<=len(receipts)<=64:bad('RECEIPT_SET_UNKNOWN');return result()
    if not isinstance(rows,list) or len(rows)>256 or operation_coverage(rows)['status']!='COMPLETE':bad('OPERATION_COVERAGE');return result()
    if any(not isinstance(r,dict) or not ident(r.get('ownerID')) for r in rows):bad('TRACE_OWNER');return result()
    contexts={r['ownerID'] for r in rows if r.get('phase')=='TUNNEL_CLOSE'}
    registry_owners={r['ownerID'] for r in rows if r.get('phase') in REGISTRY_PHASES}
    owners=[];registries=[]
    for c in receipts:
        if not isinstance(c,dict):bad('RECEIPT_SCHEMA');continue
        owner=c.get('ownerID');registry=c.get('registryOwnerID');owners.append(owner);registries.append(registry)
        if c.get('version')!=2 or type(c.get('version')) is not int or not ident(owner) or not ident(registry) or owner==registry:bad('RELATIONSHIP_UNKNOWN');continue
        if set(c)-{'version','ownerID','registryOwnerID','dns','setupFinished','socketsLeft','socketPeak','hostnameMode','batch','fixturePostfileFault'}:bad('EXTRA_RECEIPT_FIELD')
        b=c.get('batch')
        if not isinstance(b,dict):bad('BATCH_SCHEMA');continue
        if set(b)!={'code','groups','groupRecords','pending','reapFailed','lateDenied','suffixUnknown','epochActive'}:bad('BATCH_FIELDS')
        if b.get('code')!='WINNER':bad('NOT_WINNER');continue
        if c.get('setupFinished') is not True or not integer(c.get('socketsLeft'),0,0) or not integer(c.get('socketPeak'),1,2):bad('FINAL_PHYSICAL')
        if c.get('hostnameMode') not in ('RAM_STDLIB_HOSTS_FIXTURE','RAM_STDLIB_SOURCE'):bad('HOSTNAME_ENUM')
        if not integer(b.get('pending'),0,0) or b.get('reapFailed') is not False or b.get('epochActive') is not False or not integer(b.get('lateDenied'),0,0) or not integer(b.get('suffixUnknown'),0,64):bad('FINAL_BATCH_STATE')
        groups=b.get('groups');records=b.get('groupRecords')
        if not integer(groups,1,4) or not isinstance(records,list) or len(records)!=groups:bad('GROUP_COUNT_RECORDS');continue
        own=[(i,r) for i,r in enumerate(rows) if r['ownerID']==owner];reg=[(i,r) for i,r in enumerate(rows) if r['ownerID']==registry]
        if not own or not reg:bad('OWNER_DISJOINT');continue
        for phase in ('REQUEST_ACCEPT','DNS_RESULT','TUNNEL_CLOSE','WORKER_RETURN'):
            found=[r for _,r in own if r.get('phase')==phase]
            if len(found)!=1 or found[0].get('event')!='END':bad('CONTEXT_LIFECYCLE')
            elif phase=='TUNNEL_CLOSE' and found[0].get('setupFinished') is not True:bad('CONTEXT_HANDOFF')
        for phase in ('REQUEST_FINISH','REQUEST_SHUTDOWN','REQUEST_CLOSE','CONNECT_200'):
            found=[r for _,r in own if r.get('phase')==phase]
            if len(found)!=2 or [r.get('event') for r in found]!=['BEGIN','END']:bad('CONTEXT_LIFECYCLE')
        dns=[r for _,r in own if r.get('phase')=='DNS_RESULT'];answer_count=dns[0].get('answers') if len(dns)==1 else None
        if not integer(answer_count,1,64):bad('DNS_COUNT')
        libs=[(i,r) for i,r in reg if r.get('phase')=='LIBRARY_SELECT']
        if len(libs)!=2*groups:bad('LIBRARY_GROUP_COUNT')
        if any(r.get('contextOwnerID')!=owner for _,r in libs):bad('TRACE_RELATIONSHIP')
        socket_rows=[(i,r) for i,r in reg if r.get('phase')=='SOCKET_CREATE']
        tcp_rows=[(i,r) for i,r in own if r.get('phase') in TCP_PHASES]
        if any(not integer(r.get('groupIndex'),1,groups) for _,r in socket_rows+tcp_rows+libs):bad('GROUP_INDEX_UNKNOWN')
        if any(r.get('phase') in REGISTRY_PHASES for _,r in own) or any(r.get('phase') in TCP_PHASES for _,r in reg):bad('OWNER_ROLE')
        total_created=0;successes=0;last_end=-1;library_peak=0
        for n,record in enumerate(records,1):
            if not isinstance(record,dict) or set(record)!={'group','q','active','elapsed','created','closed','live','pending','success'}:bad('RECORD_SCHEMA');continue
            if not integer(record.get('group'),n,n):bad('RECORD_INDEX')
            for field,lo,hi in [('q',.6,2),('active',.5,1.9),('elapsed',0,2)]:
                if not number(record.get(field),lo,hi):bad('RECORD_NUMERIC')
            if not near(record.get('active'),record.get('q',0)-.1 if number(record.get('q'),0,2) else None):bad('ACTIVE_BUDGET')
            for field,lo,hi in [('created',0,2),('closed',0,2),('live',0,1),('pending',0,0)]:
                if not integer(record.get(field),lo,hi):bad('RECORD_NUMERIC')
            if type(record.get('success')) is not bool:bad('SUCCESS_TYPE')
            winner=n==groups
            if record.get('success') is not winner:bad('SUCCESS_SEQUENCE')
            if winner:
                if not integer(record.get('created'),1,2) or record.get('live')!=1 or record.get('closed')!=record.get('created',0)-1:bad('WINNER_HANDOFF_STATE')
                successes+=int(record.get('success') is True)
            elif record.get('live')!=0 or record.get('closed')!=record.get('created'):bad('ADVANCE_NOT_CLOSED')
            selected=[(i,r) for i,r in libs if r.get('groupIndex')==n]
            if len(selected)!=2 or [r.get('event') for _,r in selected]!=['BEGIN','END' if winner else 'ERROR']:bad('GROUP_TERMINAL');continue
            (start,begin),(end,terminal)=selected
            if start<=last_end or any(not integer(r.get('operationIndex'),n,n) for _,r in selected):bad('GROUP_ORDER')
            last_end=end
            if not near(begin.get('totalSeconds'),record.get('q')) or not near(begin.get('activeSeconds'),record.get('active')) or not number(begin.get('remaining'),record.get('q',10) if number(record.get('q'),0,2) else 10,10):bad('BEGIN_BUDGET')
            if not near(terminal.get('elapsed'),record.get('elapsed')):bad('ELAPSED_CONFLICT')
            for field in ('closed','live','pending'):
                if terminal.get(field)!=record.get(field) or type(terminal.get(field)) is not int:bad('TERMINAL_RECORD_CONFLICT')
            sockets=[(i,r) for i,r in socket_rows if r.get('groupIndex')==n]
            tcp=[(i,r) for i,r in tcp_rows if r.get('groupIndex')==n]
            if any(not start<i<end for i,_ in sockets+tcp):bad('OPERATION_OUTSIDE_GROUP')
            creates=[r for _,r in sockets if r.get('event')=='END'];attempts=[r for _,r in sockets if r.get('event')=='BEGIN']
            if len(creates)!=record.get('created') or not 1<=len(attempts)<=2 or len(sockets)!=2*len(attempts):bad('SOCKET_RECORD_COUNT')
            tcp_begins=[r for _,r in tcp if r.get('event')=='BEGIN']
            if len(tcp_begins)!=len(creates) or len(tcp)!=2*len(tcp_begins):bad('TCP_SOCKET_COUNT')
            if winner and not any(r.get('event')=='END' for _,r in tcp):bad('WINNER_TCP_STATUS')
            if integer(answer_count,1,64):
                size=min(2,answer_count-2*(n-1))
                if size<1 or len(attempts)>size:bad('GROUP_DNS_RANGE')
                if not number(record.get('q'),1 if size==2 else .6,2):bad('GROUP_FLOOR')
            total_created+=len(creates)
            observed_live=[r.get('live') for _,r in sockets+selected]
            if any(not integer(v,0,2) for v in observed_live):bad('LIVE_NUMERIC')
            else:library_peak=max([library_peak]+observed_live)
        if successes!=1:bad('WINNER_COUNT')
        if c.get('socketPeak')!=library_peak:bad('PEAK_CONFLICT')
        if integer(answer_count,1,64) and b.get('suffixUnknown')!=answer_count-total_created:bad('SUFFIX_CONFLICT')
        handoff=[i for i,r in own if r.get('phase')=='CONNECT_200' and r.get('event')=='BEGIN']
        if len(handoff)!=1 or handoff[0]<=last_end:bad('HANDOFF_ORDER')
    if any(not ident(o) for o in owners+registries):bad('RECEIPT_IDENTITY')
    else:
        if len(set(owners))!=len(owners) or len(set(registries))!=len(registries):bad('DUPLICATE_OWNER_REGISTRY')
        if set(owners)!=contexts:bad('RECEIPT_CONTEXT_SET')
        if set(registries)!=registry_owners:bad('RECEIPT_REGISTRY_SET')
    return result()

if __name__=='__main__':
    try:
        raw=sys.stdin.buffer.read(128*1024+1);assert len(raw)<=128*1024
        args=json.loads(raw);answer=validate(args['receipts'],args['trace'])
    except (ValueError,TypeError,KeyError,AssertionError,AttributeError):answer={'version':1,'status':'PARTIAL','accepted':False,'reasonCodes':['INVALID_INPUT'],'originReceipt':'UNKNOWN'}
    print(json.dumps({'scope':'BATCH_RECEIPT_TRACE_GATE','validation':answer}));sys.exit(0 if answer['accepted'] else 20)
