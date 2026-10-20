"""Bounded projection of owned completion; delegate the original broker exactly once."""
import json,math,pathlib,re
from tiktok_policy.dns_admission import REASONS,stats_valid
from tiktok_policy.operation_coverage import PAIRED,SNAPSHOTS
CAP=512*1024
REASON_CODES=set('ACTIVE_BUDGET ADVANCE_NOT_CLOSED BATCH_FIELDS BATCH_SCHEMA BEGIN_BUDGET CONTEXT_HANDOFF CONTEXT_LIFECYCLE DNS_COUNT DUPLICATE_OWNER_REGISTRY ELAPSED_CONFLICT EXTRA_RECEIPT_FIELD FINAL_BATCH_STATE FINAL_PHYSICAL GROUP_COUNT_RECORDS GROUP_DNS_RANGE GROUP_FLOOR GROUP_INDEX_UNKNOWN GROUP_ORDER GROUP_TERMINAL HANDOFF_ORDER HOSTNAME_ENUM LIBRARY_GROUP_COUNT LIVE_NUMERIC NOT_WINNER OPERATION_COVERAGE OPERATION_OUTSIDE_GROUP OWNER_DISJOINT OWNER_ROLE PEAK_CONFLICT RECEIPT_CONTEXT_SET RECEIPT_IDENTITY RECEIPT_REGISTRY_SET RECEIPT_SCHEMA RECEIPT_SET_UNKNOWN RECORD_INDEX RECORD_NUMERIC RECORD_SCHEMA REGISTRY_CLOSE_COUNT REGISTRY_CLOSE_INDEX REGISTRY_CLOSE_LIVE REGISTRY_CLOSE_NUMERIC REGISTRY_CLOSE_ORDER REGISTRY_CLOSE_SCHEMA REGISTRY_CLOSE_TERMINAL REGISTRY_COMPLETION_ORDER REGISTRY_COMPLETION_UNKNOWN RELATIONSHIP_UNKNOWN SOCKET_RECORD_COUNT SUCCESS_SEQUENCE SUCCESS_TYPE SUFFIX_CONFLICT TCP_SOCKET_COUNT TERMINAL_RECORD_CONFLICT TRACE_OWNER TRACE_RELATIONSHIP WINNER_COUNT WINNER_HANDOFF_STATE WINNER_TCP_STATUS'.split())
TRACE_CODES={'OK','BEGIN','ERROR','REAPED','DEADLINE','WINNER','CANCELLED','EXHAUSTED','DENIED','CLOSED'}
NUMBERS={'nativeExit','responseBytes','inputBytes','childReaped','callerThreads','answers','ipv4','ipv6','workerThreadsLeft','requestSocketsLeft','workerStarted','workerReturned','setupFinished','socketOpen','groupIndex','operationIndex','index','live','pending','closed','totalSeconds','activeSeconds','remaining'}
def opaque(v):return v if type(v) is str and re.fullmatch('[a-f0-9]{16}',v) else 'UNKNOWN'
def number(v,low=0,high=1048576):return type(v) in (int,float) and math.isfinite(v) and low<=v<=high
def boolean(v):return v if type(v) is bool else 'UNKNOWN'
def enum(v,allowed):return v if type(v) is str and v in allowed else 'UNKNOWN'
def project(ctx,result,phase):
    if type(result) is not dict or result.get('ownerID')!=ctx.cid:raise ValueError('PROJECTION_OWNER')
    dns=result.get('receipt',{}).get('dns',{})
    if type(dns) is not dict:raise ValueError('PROJECTION_DNS')
    observed={}
    for key,source in [('nativeExit','dnsExit'),('groupsLeft','dnsGroupLeft'),('responseBytes','responseBytes'),('inputBytes','inputBytes')]:
        value=dns.get(source);observed[key]=value if type(value) is int and number(value,-255 if key=='nativeExit' else 0) else 'UNKNOWN'
    for key,source in [('reaped','dnsChildReaped'),('pipesClosed','dnsPipesClosed')]:observed[key]=dns[source] if type(dns.get(source)) is bool else 'UNKNOWN'
    admission=dns.get('dnsAdmission');known=type(admission) is dict and stats_valid(admission)
    observed['admission']=dict(admission) if known else 'UNKNOWN'
    observed['admissionReason']=admission['reason'] if known and admission.get('reason') in REASONS else 'UNKNOWN'
    diagnostic=dns.get('dnsDiagnostic',{})
    observed['responseCode']=enum(diagnostic.get('responseCode') if type(diagnostic) is dict else None,REASONS)
    validation=result.get('validation',{})
    reasons=validation.get('reasonCodes') if type(validation) is dict else None
    if type(reasons) is not list or len(reasons)>48:reasons=['UNKNOWN']
    else:reasons=[v if type(v) is str and v in REASON_CODES else 'UNKNOWN' for v in reasons]
    raw=result.get('trace');trace=[];incomplete=False
    if type(raw) is not list or len(raw)>128:raw=[];incomplete=True
    for item in raw:
        if type(item) is not dict:incomplete=True;continue
        phaseName=enum(item.get('phase'),PAIRED|SNAPSHOTS);event=enum(item.get('event'),('BEGIN','END','ERROR'));code=enum(item.get('code'),TRACE_CODES)
        row=dict(ownerID=opaque(item.get('ownerID')),phase=phaseName,event=event,code=code,elapsed=item['elapsed'] if number(item.get('elapsed'),0,360) else 'UNKNOWN')
        if 'UNKNOWN' in row.values():incomplete=True
        if phaseName in PAIRED and (type(item.get('operationIndex')) is not int or not 1<=item['operationIndex']<=64):row['operationIndex']='UNKNOWN';incomplete=True
        for key in NUMBERS:
            if key not in item:continue
            if key=='operationIndex' and row.get(key)=='UNKNOWN':continue
            value=item[key]
            if key in ('childReaped','workerStarted','workerReturned','setupFinished','socketOpen'):row[key]=boolean(value)
            elif number(value,-255 if key=='nativeExit' else 0) and (key in ('totalSeconds','activeSeconds','remaining') or type(value) is int):row[key]=value
            else:row[key]='UNKNOWN'
            if row[key]=='UNKNOWN':incomplete=True
        trace.append(row)
    evidence=dict(phase=enum(phase,('analyze','prepare')),ownerID=opaque(ctx.cid),accepted=boolean(result.get('accepted')),
        threadClosed=boolean(result.get('workerThreadClosed')),clientClosed=boolean(result.get('clientClosed')),loopClosed=boolean(result.get('loopClosed')),traceIncomplete=boolean(result.get('traceIncomplete')))
    complete=not incomplete and bool(trace) and 'UNKNOWN' not in evidence.values() and all(v!='UNKNOWN' for v in observed.values()) and 'UNKNOWN' not in reasons and evidence['traceIncomplete'] is False
    return dict(version=1,**evidence,diagnosticComplete=complete,dns=observed,reasonCodes=reasons,boundaries=trace)
def install(server,root):
    root=pathlib.Path(root);broker=server.phase_broker;delegate=broker.finish;count=0;size=0
    def finish(ctx,result):
        nonlocal count,size
        count+=1
        try:
            if count>64:raise ValueError('COLLECTOR_CAP')
            entry=broker.entries.get(getattr(ctx,'_phase_key',None),{})
            row=project(ctx,result,entry.get('phase','UNKNOWN'))
            if not row['diagnosticComplete']:ctx.trace.mark_incomplete()
            data=(json.dumps(row,separators=(',',':'),allow_nan=False)+'\n').encode()
            if len(data)>32768 or size+len(data)>CAP:raise ValueError('COLLECTOR_BYTES')
            with (root/'completions.jsonl').open('ab') as file:file.write(data)
            size+=len(data)
        except BaseException:
            # Observation failure cannot suppress broker completion or physical cleanup.
            ctx.trace.mark_incomplete()
        return delegate(ctx,result)
    broker.finish=finish
