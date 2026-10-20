"""Strict v3 same-IPC/ID/bundle observation, never migrate historical receipts."""
import copy,math,re
from dns_counts import counts_valid
from dns_inspection import bundle_valid,valid as inspection_valid
def ident(v):return type(v) is str and re.fullmatch('[a-f0-9]{16}',v) is not None
def byte_count(value,cap):return type(value) is int and 0<value<=cap
def missing():
    return dict(version=3,helperID=None,responseStatus='MISSING',responseCode='UNKNOWN',responseType='MISSING',answerCount=None,
      counts=None,countsState='MISSING',inspection=None,inspectionState='MISSING',evidence='PARTIAL',resolution='FAIL')
def observe(value):
    row=missing();row['responseType']={dict:'OBJECT',list:'ARRAY',str:'STRING',int:'NUMBER',float:'NUMBER',bool:'BOOLEAN',type(None):'NULL'}.get(type(value),'UNKNOWN')
    if type(value) is not dict:return row
    status=value.get('status');code=value.get('code')
    row['responseStatus']=status if type(status) is str and status in ('OK','ERROR') else 'UNKNOWN'
    row['responseCode']=code if type(code) is str and code in ('OK','DNS_ERROR','ANSWER_CAP','DEADLINE') else 'UNKNOWN'
    if ident(value.get('helperID')):row['helperID']=value['helperID']
    answers=value.get('answers')
    if type(answers) is list and len(answers)<=32768:row['answerCount']=len(answers)
    counts=value.get('counts');inspection=value.get('inspection')
    row['countsState']='MISSING' if 'counts' not in value else 'INVALID'
    row['inspectionState']='MISSING' if 'inspection' not in value else 'INVALID'
    if counts_valid(counts):row.update(counts=copy.deepcopy(counts),countsState='VALID')
    if 'inspection' in value and (inspection is None or inspection_valid(inspection)):
        row.update(inspection=copy.deepcopy(inspection),inspectionState='VALID')
    relation=False
    if row['countsState']=='VALID' and row['inspectionState']=='VALID' and bundle_valid(counts,inspection):
        if status=='OK' and code=='OK':relation=counts['reason']=='OK' and counts['rawCount']==row['answerCount'] and inspection is None
        elif status=='ERROR' and code=='ANSWER_CAP':relation=counts['reason']=='RAW_CAP' and row['answerCount']==0
        elif status=='ERROR' and code=='DEADLINE':relation=counts['reason']=='DEADLINE' and row['answerCount']==0 and inspection is None
        elif status=='ERROR' and code=='DNS_ERROR':relation=counts['reason']=='MISSING' and counts['rawCountMode']=='UNKNOWN' and row['answerCount']==0 and inspection is None
    exact={'version','status','code','answers','helperID','counts','inspection','unexpectedInherited','threads'}
    identity=(set(value)==exact and type(value.get('version')) is int and value['version']==3 and
      type(value.get('unexpectedInherited')) is int and value['unexpectedInherited']==0 and
      type(value.get('threads')) is int and value['threads']==1 and ident(row['helperID']))
    if relation and identity:row['evidence']='COMPLETE'
    return row
def valid(row):
    if type(row) is not dict:return False
    expected=dict(version=3,responseStatus='OK',responseCode='OK',responseType='OBJECT',countsState='VALID',inspectionState='VALID',
      evidence='COMPLETE',resolution='PASS',nativeExit=0,reaped=True,pipesClosed=True,groupsLeft=0)
    counts=row.get('counts')
    return (set(row)==set(expected)|{'helperID','counts','inspection','answerCount','elapsed'} and ident(row.get('helperID'))
      and all(type(row.get(k)) is type(v) and row[k]==v for k,v in expected.items()) and bundle_valid(counts,row.get('inspection'))
      and counts['reason']=='OK' and row['inspection'] is None and type(row.get('answerCount')) is int
      and 1<=row['answerCount']<=64 and counts['rawCount']==row['answerCount'] and
      type(row.get('elapsed')) in (int,float) and math.isfinite(row['elapsed']) and row['elapsed']>=0)
def validate_receipt(receipt,trace=None):
    diagnostic=receipt.get('dnsDiagnostic') if type(receipt) is dict else None
    accepted=valid(diagnostic);reasons=[] if accepted else ['DIAGNOSTIC_NOT_COMPLETE']
    if accepted:
        pairs={'dnsExit':'nativeExit','dnsChildReaped':'reaped','dnsPipesClosed':'pipesClosed','dnsGroupLeft':'groupsLeft',
          'dnsHelperID':'helperID','dnsCounts':'counts','dnsInspection':'inspection'}
        for outer,inner in pairs.items():
            value=diagnostic[inner]
            if outer not in receipt or type(receipt[outer]) is not type(value) or receipt[outer]!=value:
                accepted=False;reasons.append('HELPER_RECEIPT_CONFLICT_OR_MISSING')
        if type(receipt.get('answerCap')) is not int or receipt['answerCap']!=64:accepted=False;reasons.append('HELPER_CAP_CONFLICT')
        if (not byte_count(receipt.get('inputBytes'),16384) or not byte_count(receipt.get('responseBytes'),32768)
          or type(receipt.get('inputCap')) is not int or receipt['inputCap']!=16384
          or type(receipt.get('responseCap')) is not int or receipt['responseCap']!=32768):
            accepted=False;reasons.append('HELPER_BYTE_CONTRACT')
        if trace is not None:
            rows=[(i,r) for i,r in enumerate(trace) if r.get('ownerID')==diagnostic['helperID']]
            if (len(rows)!=2 or rows[0][1].get('phase')!='DNS_HELPER' or rows[0][1].get('event')!='BEGIN'
              or rows[1][1].get('phase')!='DNS_HELPER' or rows[1][1].get('event')!='END'
              or not byte_count(rows[0][1].get('inputBytes'),16384)
              or not byte_count(rows[1][1].get('responseBytes'),32768)
              or rows[0][1].get('inputBytes')!=receipt.get('inputBytes')
              or rows[1][1].get('responseBytes')!=receipt.get('responseBytes')
              or type(rows[1][1].get('nativeExit')) is not int or rows[1][1]['nativeExit']!=diagnostic['nativeExit']
              or rows[1][1].get('childReaped') is not True):
                accepted=False;reasons.append('HELPER_TRACE_ORDER_OR_LINK_CONFLICT')
    return dict(version=3,status='COMPLETE' if accepted else 'PARTIAL',accepted=accepted,reasonCodes=sorted(set(reasons)))
