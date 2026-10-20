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
    observed['responseCode']=diagnostic.get('responseCode') if diagnostic.get('responseCode') in REASONS else 'UNKNOWN'
    reasons=result.get('validation',{}).get('reasonCodes')
    if type(reasons) is not list or len(reasons)>48:reasons=['UNKNOWN']
    else:reasons=[v if type(v) is str and v in REASON_CODES else 'UNKNOWN' for v in reasons]
    raw=result.get('trace');trace=[];incomplete=False
    if type(raw) is not list or len(raw)>128:raw=[];incomplete=True
    for item in raw:
        if type(item) is not dict:incomplete=True;continue
        phaseName=item.get('phase');event=item.get('event');code=item.get('code')
        if phaseName not in PAIRED|SNAPSHOTS or event not in ('BEGIN','END','ERROR') or code not in TRACE_CODES or not number(item.get('elapsed'),0,360):incomplete=True;continue
        row=dict(ownerID=opaque(item.get('ownerID')),phase=phaseName,event=event,code=code,elapsed=item['elapsed'])
        for key in NUMBERS:
            value=item.get(key)
            if type(value) is bool:row[key]=value
            elif number(value,-255 if key=='nativeExit' else 0):row[key]=value
            elif key in item:incomplete=True
        trace.append(row)
    complete=not incomplete and bool(trace) and all(v!='UNKNOWN' for k,v in observed.items() if k!='admission') and 'UNKNOWN' not in reasons and result.get('traceIncomplete') is False
    return dict(version=1,phase=phase if phase in ('analyze','prepare') else 'UNKNOWN',ownerID=opaque(ctx.cid),accepted=result.get('accepted') is True,
        threadClosed=result.get('workerThreadClosed') is True,clientClosed=result.get('clientClosed') is True,traceIncomplete=result.get('traceIncomplete') is not False,
        diagnosticComplete=complete,dns=observed,reasonCodes=reasons,boundaries=trace)
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
