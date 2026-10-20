"""V3 bounded receipt validation. Libraries own HTTP; glue binds Budget and observer evidence."""
import json,re
PHASES=('metadata','prepare');CAPS={'metadata':2,'prepare':1};UNKNOWN='UNKNOWN'
BOUNDARIES=('CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS')
def rid_valid(value):return isinstance(value,str) and re.fullmatch('[a-f0-9]{16}',value) is not None

def receipt(result,events,*,observer_present,observer_incomplete=False):
    rows={};packet_conflict=False;complete={p:False for p in PHASES};reasons=set()
    def bad(code):reasons.add(code)
    for name in ('metadataPacket','preparePacket'):
        packet=result.get(name)
        if not isinstance(packet,dict) or packet.get('status') not in ('PASS','FAIL') or not isinstance(packet.get('rows'),list):continue
        complete['metadata' if name=='metadataPacket' else 'prepare']=True
        if len(packet['rows'])>3:packet_conflict=True;bad('PACKET_CAP')
        for row in packet['rows'][:4]:
            if not isinstance(row,dict):packet_conflict=True;bad('PACKET_ROW');continue
            p=row.get('phase');index=row.get('index')
            if p not in PHASES or type(index) is not int or not 1<=index<=CAPS[p] or row.get('method')!='GET' or row.get('url')!='[url-redacted]':packet_conflict=True;bad('PACKET_IDENTITY');continue
            try:signature=json.dumps(row,sort_keys=True,separators=(',',':'),allow_nan=False)
            except (ValueError,TypeError):packet_conflict=True;bad('PACKET_CONTENT');continue
            key=(p,index)
            if key in rows and rows[key][0]!=signature:packet_conflict=True;bad('AGGREGATE_CONFLICT')
            rows[key]=(signature,row)
    if result.get('stage')=='metadata':complete['prepare']=True
    if packet_conflict:complete={p:False for p in PHASES}
    phase_rows={p:[row for key,(_,row) in rows.items() if key[0]==p] for p in PHASES}
    prepared={p:len(phase_rows[p]) if complete[p] else UNKNOWN for p in PHASES}
    adapter={p:len(phase_rows[p]) if complete[p] and all(isinstance(r.get('sendDiagnostic'),dict) for r in phase_rows[p]) else UNKNOWN for p in PHASES}
    decoded={p:sum(r['decodedBytes'] for r in phase_rows[p]) if complete[p] and all(type(r.get('decodedBytes')) is int for r in phase_rows[p]) else UNKNOWN for p in PHASES}
    budget=not packet_conflict
    packet_by_rid={}
    for key,(_,row) in rows.items():
        value=row.get('decodedBytes')
        budget=budget and type(value) is int and 0<=value<=(8*1024*1024 if key[0]=='metadata' else 20*1024*1024)
        b=row.get('boundaries')
        if not isinstance(b,dict):bad('PACKET_RID_MISSING');continue
        request_id=b.get('requestID')
        if not rid_valid(request_id):bad('PACKET_RID_INVALID');continue
        if request_id in packet_by_rid and packet_by_rid[request_id][0]!=key:bad('PACKET_RID_REUSED')
        else:packet_by_rid[request_id]=(key,row)
        if b.get('incomplete') is True:observer_incomplete=True
        conn=b.get('connectionID')
        if conn is not None and conn!=UNKNOWN and not rid_valid(conn):bad('PACKET_CONNECTION_INVALID')
        status=row.get('status')
        if status is not None and (type(status) is not int or not 100<=status<=599):bad('PACKET_STATUS_INVALID')
    for p in PHASES:
        if type(prepared[p]) is int:budget=budget and prepared[p]<=CAPS[p]
    if type(decoded['metadata']) is int:budget=budget and decoded['metadata']<=16*1024*1024
    if all(type(decoded[p]) is int for p in PHASES):budget=budget and sum(decoded.values())<=36*1024*1024
    if not budget:bad('BUDGET_INVALID')
    pairs={};by_request={};begins={p:set() for p in PHASES};ends={p:set() for p in PHASES};headers={p:set() for p in PHASES}
    if not observer_present or events is None:bad('OBSERVER_MISSING')
    if observer_incomplete:bad('OBSERVER_PARTIAL')
    if events is not None:
        if not isinstance(events,list):bad('OBSERVER_INVALID');events=[]
        if len(events)>=128:bad('OBSERVER_CAP')
        for e in events[:128]:
            if not isinstance(e,dict):bad('OBSERVER_INVALID');continue
            p=e.get('phase');request_id=e.get('requestID');boundary=e.get('boundary');event=e.get('event')
            if p not in PHASES or not rid_valid(request_id) or boundary not in BOUNDARIES or event not in ('BEGIN','END','ERROR'):bad('OBSERVER_IDENTITY');continue
            key=(p,request_id,boundary);pairs.setdefault(key,[]).append(e)
            by_request.setdefault((p,request_id),[]).append(e)
            if boundary=='REQUEST_SEND' and event=='BEGIN':begins[p].add(request_id)
            if boundary=='REQUEST_SEND' and event=='END':ends[p].add(request_id)
            if boundary=='RESPONSE_HEADERS' and event=='END':headers[p].add(request_id)
            match=packet_by_rid.get(request_id)
            if match is None:bad('OBSERVER_UNACCOUNTED_RID')
            elif match[0][0]!=p:bad('OBSERVER_PHASE_CONFLICT')
            else:
                packet_conn=(match[1].get('boundaries') or {}).get('connectionID');conn=e.get('connectionID')
                if conn is not None and (not rid_valid(conn) or packet_conn not in (None,UNKNOWN,conn)):bad('CONNECTION_CONFLICT')
    for entries in pairs.values():
        if sum(e['event']=='BEGIN' for e in entries)!=1 or sum(e['event'] in ('END','ERROR') for e in entries)!=1:bad('OBSERVER_TERMINAL')
    def terminal(p,request_id,name):
        return [e for e in pairs.get((p,request_id,name),[]) if e['event'] in ('END','ERROR')]
    for request_id,(key,row) in packet_by_rid.items():
        p=key[0];observed=by_request.get((p,request_id),[])
        if not observed:bad('PACKET_OBSERVER_MISSING');continue
        send=terminal(p,request_id,'REQUEST_SEND');head=terminal(p,request_id,'RESPONSE_HEADERS');setup=terminal(p,request_id,'CONNECTION_SETUP')
        sent=any(e['event']=='END' for e in send);received=any(e['event']=='END' for e in head)
        if head and not sent:bad('HEADER_WITHOUT_SEND')
        if any(e['event']=='ERROR' for e in setup) and (sent or head):bad('SETUP_AFTER_SEND_CONFLICT')
        d=row.get('sendDiagnostic')
        if not isinstance(d,dict):bad('ADAPTER_EVIDENCE_MISSING')
        else:
            status=row.get('status');diag_status=d.get('status')
            if d.get('code')=='HTTP_RESPONSE':
                if type(status) is not int or not 100<=status<=599 or not sent or not received:bad('STATUS_HEADER_CONFLICT')
                if diag_status is not None and diag_status!=status:bad('DIAGNOSTIC_STATUS_CONFLICT')
            elif status is not None or received or diag_status not in (None,UNKNOWN):bad('ERROR_HEADER_CONFLICT')
            elif row.get('decodedBytes',0)!=0:bad('BODY_WITHOUT_HEADER')
        summary=(row.get('boundaries') or {}).get('terminal')
        if summary is not None:
            if not isinstance(summary,list) or len(summary)>6:bad('PACKET_TERMINAL_INVALID')
            else:
                actual=[(e['boundary'],e['event'],e.get('code')) for e in observed if e['event'] in ('END','ERROR')]
                wanted=[(e.get('boundary'),e.get('event'),e.get('code')) for e in summary if isinstance(e,dict)]
                if len(wanted)!=len(summary) or actual!=wanted:bad('PACKET_TERMINAL_CONFLICT')
    for p in PHASES:
        if type(prepared[p]) is int and (len(begins[p])>prepared[p] or len(ends[p])>len(begins[p]) or len(headers[p])>len(ends[p])):bad('COUNTER_CONFLICT')
        if type(prepared[p]) is int and len(phase_rows[p]) and sorted(r['index'] for r in phase_rows[p])!=list(range(1,len(phase_rows[p])+1)):bad('PACKET_INDEX_GAP')
    partial=bool(reasons)
    def linked_count(values):return {p:len(values[p]) if not partial else UNKNOWN for p in PHASES}
    statuses={p:[r['status'] for r in phase_rows[p] if type(r.get('status')) is int and 100<=r['status']<=599] for p in PHASES}
    exact=budget and all(complete.values()) and not partial and all(type(adapter[p]) is int for p in PHASES)
    return {'version':3,'preparedGETAttempts':prepared,'adapterAttempts':adapter,
        'requestSendBegin':linked_count(begins),'requestSendEnd':linked_count(ends),'responseHeadersEnd':linked_count(headers),
        'observedSendBeginLowerBound':{p:len(begins[p]) for p in PHASES},
        'httpStatusesObserved':statuses,'decodedBytesFromPackets':decoded,
        'packetCoverage':{p:'COMPLETE' if complete[p] else UNKNOWN for p in PHASES},
        'observerCoverage':'COMPLETE' if not partial else ('MISSING' if not observer_present else 'PARTIAL'),
        'linkageCoverage':{'status':'COMPLETE' if not partial else 'PARTIAL','reasonCodes':sorted(reasons)[:32],
            'packetRows':len(rows),'packetRIDCount':len(packet_by_rid),'observerRequests':len(by_request)},
        'budgetWithinCaps':bool(budget and all(complete.values())),
        'withinBudget':bool(exact),'exact':bool(exact),'originReceipt':UNKNOWN}

def read_owned_observer(path):
    try:
        with path.open('rb') as f:data=f.read(128*1024+1)
    except FileNotFoundError:return None,False,True
    if len(data)>128*1024:return [],True,True
    try:events=[json.loads(line) for line in data.splitlines()]
    except (ValueError,TypeError):return [],True,True
    return events,True,len(events)>=128
