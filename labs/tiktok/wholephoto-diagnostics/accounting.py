"""V2 lab receipt: Budget accepted GET attempts, adapter evidence, send/header observations.
No URL/body/cookie export. Missing evidence is UNKNOWN, never inferred zero.
"""
PHASES=('metadata','prepare');CAPS={'metadata':2,'prepare':1}
UNKNOWN='UNKNOWN'

def receipt(result,events,*,observer_present,observer_incomplete=False):
    rows={};conflict=False;complete={p:False for p in PHASES}
    for name in ('metadataPacket','preparePacket'):
        packet=result.get(name)
        if not isinstance(packet,dict) or packet.get('status') not in ('PASS','FAIL') or not isinstance(packet.get('rows'),list):continue
        phase='metadata' if name=='metadataPacket' else 'prepare';complete[phase]=True
        for row in packet['rows']:
            if not isinstance(row,dict):conflict=True;continue
            p=row.get('phase');index=row.get('index');b=row.get('boundaries') or {}
            if p not in PHASES or type(index) is not int or not 1<=index<=CAPS[p] or row.get('method')!='GET' or row.get('url')!='[url-redacted]':conflict=True;continue
            key=(p,index);signature=(b.get('requestID'),row.get('status'),row.get('decodedBytes'),(row.get('sendDiagnostic') or {}).get('code'))
            if key in rows and rows[key][0]!=signature:conflict=True
            rows[key]=(signature,row)
            observer_incomplete=observer_incomplete or b.get('incomplete') is True
    # The trusted parent never sends prepare after metadata FAIL / metadata-only.
    prepare_not_started=result.get('stage')=='metadata'
    if prepare_not_started:complete['prepare']=True
    if conflict:complete={p:False for p in PHASES}
    prepared={p:sum(key[0]==p for key in rows) if complete[p] else UNKNOWN for p in PHASES}
    phase_rows={p:[row for key,(_,row) in rows.items() if key[0]==p] for p in PHASES}
    adapter={p:len(phase_rows[p]) if complete[p] and all(isinstance(row.get('sendDiagnostic'),dict) for row in phase_rows[p]) else UNKNOWN for p in PHASES}
    decoded={p:sum(row['decodedBytes'] for row in phase_rows[p]) if complete[p] and all(type(row.get('decodedBytes')) is int for row in phase_rows[p]) else UNKNOWN for p in PHASES}
    policy=not conflict
    for key,(_,row) in rows.items():
        value=row.get('decodedBytes');policy=policy and type(value) is int and 0<=value<=(8*1024*1024 if key[0]=='metadata' else 20*1024*1024)
    for p in PHASES:
        if type(prepared[p]) is int:policy=policy and prepared[p]<=CAPS[p]
    if type(decoded['metadata']) is int:policy=policy and decoded['metadata']<=16*1024*1024
    if all(type(decoded[p]) is int for p in PHASES):policy=policy and sum(decoded.values())<=36*1024*1024
    pairs={};begins={p:set() for p in PHASES};ends={p:set() for p in PHASES};headers={p:set() for p in PHASES}
    partial=observer_incomplete or events is None or not observer_present
    if events is not None:
        partial=partial or len(events)>=128
        for e in events[:128]:
            if not isinstance(e,dict):partial=True;continue
            p=e.get('phase');rid=e.get('requestID');boundary=e.get('boundary');event=e.get('event')
            if p not in PHASES or not isinstance(rid,str) or len(rid)!=16 or boundary not in ('CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS') or event not in ('BEGIN','END','ERROR'):partial=True;continue
            key=(p,rid,boundary);pair=pairs.setdefault(key,[]);pair.append(event)
            if boundary=='REQUEST_SEND' and event=='BEGIN':begins[p].add(rid)
            if boundary=='REQUEST_SEND' and event=='END':ends[p].add(rid)
            if boundary=='RESPONSE_HEADERS' and event=='END':headers[p].add(rid)
        partial=partial or any(v.count('BEGIN')!=1 or sum(v.count(e) for e in ('END','ERROR'))!=1 for v in pairs.values())
    if rows and not pairs:partial=True
    send_begin={p:len(begins[p]) if not partial else UNKNOWN for p in PHASES}
    send_end={p:len(ends[p]) if not partial else UNKNOWN for p in PHASES}
    header_count={p:len(headers[p]) if not partial else UNKNOWN for p in PHASES}
    statuses={p:[row['status'] for key,(_,row) in rows.items() if key[0]==p and type(row.get('status')) is int] for p in PHASES}
    return {'version':2,'preparedGETAttempts':prepared,'adapterAttempts':adapter,
        'requestSendBegin':send_begin,'requestSendEnd':send_end,'responseHeadersEnd':header_count,
        'observedSendBeginLowerBound':{p:len(begins[p]) for p in PHASES},
        'httpStatusesObserved':statuses,'decodedBytesFromPackets':decoded,
        'packetCoverage':{p:'COMPLETE' if complete[p] else 'UNKNOWN' for p in PHASES},
        'observerCoverage':'COMPLETE' if not partial else ('MISSING' if not observer_present else 'PARTIAL'),
        'withinBudget':bool(policy and all(complete.values())),'exact':bool(policy and all(complete.values()) and not partial and all(type(adapter[p]) is int for p in PHASES)),
        'originReceipt':'UNKNOWN'}

def read_owned_observer(path):
    import json
    try:
        with path.open('rb') as f:data=f.read(128*1024+1)
    except FileNotFoundError:return None,False,True
    if len(data)>128*1024:return [],True,True
    try:events=[json.loads(line) for line in data.splitlines()]
    except (ValueError,TypeError):return [],True,True
    return events,True,len(events)>=128
