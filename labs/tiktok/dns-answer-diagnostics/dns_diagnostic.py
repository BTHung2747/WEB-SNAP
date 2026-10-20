"""Strict v2 same-helper observation. Frozen v1 raw/validator remains untouched."""
import copy,math,re
from dns_counts import counts_valid
def ident(v):return type(v) is str and re.fullmatch('[a-f0-9]{16}',v) is not None
def missing():
    return dict(version=2,helperID=None,responseStatus='MISSING',responseCode='UNKNOWN',responseType='MISSING',
                answerCount=None,counts=None,countsState='MISSING',evidence='PARTIAL',resolution='FAIL')
def observe(value):
    row=missing();row['responseType']={dict:'OBJECT',list:'ARRAY',str:'STRING',int:'NUMBER',float:'NUMBER',bool:'BOOLEAN',type(None):'NULL'}.get(type(value),'UNKNOWN')
    if type(value) is not dict:return row
    status=value.get('status');code=value.get('code','OK' if status=='OK' else None)
    row['responseStatus']=status if type(status) is str and status in ('OK','ERROR') else 'UNKNOWN'
    row['responseCode']=code if type(code) is str and code in ('OK','DNS_ERROR','ANSWER_CAP','DEADLINE') else 'UNKNOWN'
    if ident(value.get('helperID')):row['helperID']=value['helperID']
    answers=value.get('answers')
    if type(answers) is list and len(answers)<=32768:row['answerCount']=len(answers)
    counts=value.get('counts');row['countsState']='MISSING' if 'counts' not in value else 'INVALID'
    if counts_valid(counts):row.update(counts=copy.deepcopy(counts),countsState='VALID')
    recognized=((status=='OK' and code=='OK') or (status=='ERROR' and code in ('DNS_ERROR','ANSWER_CAP','DEADLINE')))
    relation=False
    if row['countsState']=='VALID':
        if status=='OK':relation=counts['evidence']=='COMPLETE' and counts['reason']=='OK' and counts['rawCount']==row['answerCount']
        elif code=='ANSWER_CAP':relation=counts['reason']=='RAW_CAP' and row['answerCount']==0
        elif code=='DEADLINE':relation=counts['reason']=='DEADLINE' and row['answerCount']==0
        elif code=='DNS_ERROR':relation=counts['reason']=='MISSING' and counts['rawCountMode']=='UNKNOWN' and row['answerCount']==0
    identity=(type(value.get('unexpectedInherited')) is int and value['unexpectedInherited']==0
      and type(value.get('threads')) is int and value['threads']==1 and ident(row['helperID']))
    if recognized and relation and identity:row['evidence']='COMPLETE'
    return row
def valid(row):
    if type(row) is not dict:return False
    expected=dict(version=2,responseStatus='OK',responseCode='OK',responseType='OBJECT',countsState='VALID',
      evidence='COMPLETE',resolution='PASS',nativeExit=0,reaped=True,pipesClosed=True,groupsLeft=0)
    counts=row.get('counts')
    return (set(row)==set(expected)|{'helperID','counts','answerCount','elapsed'} and ident(row.get('helperID'))
      and all(type(row.get(k)) is type(v) and row[k]==v for k,v in expected.items()) and counts_valid(counts)
      and counts['evidence']=='COMPLETE' and counts['reason']=='OK'
      and type(row.get('answerCount')) is int and 1<=row['answerCount']<=64 and counts['rawCount']==row['answerCount']
      and type(row.get('elapsed')) in (int,float) and math.isfinite(row['elapsed']) and row['elapsed']>=0)
def validate_receipt(receipt):
    diagnostic=receipt.get('dnsDiagnostic') if type(receipt) is dict else None
    accepted=valid(diagnostic);reasons=[] if accepted else ['DIAGNOSTIC_NOT_COMPLETE']
    if accepted:
        pairs={'dnsExit':'nativeExit','dnsChildReaped':'reaped','dnsPipesClosed':'pipesClosed','dnsGroupLeft':'groupsLeft','dnsHelperID':'helperID','dnsCounts':'counts'}
        for outer,inner in pairs.items():
            value=diagnostic[inner]
            if type(receipt.get(outer)) is not type(value) or receipt[outer]!=value:accepted=False;reasons.append('HELPER_RECEIPT_CONFLICT_OR_MISSING')
        if type(receipt.get('answerCap')) is not int or receipt['answerCap']!=64:accepted=False;reasons.append('HELPER_CAP_CONFLICT')
    return dict(version=2,status='COMPLETE' if accepted else 'PARTIAL',accepted=accepted,reasonCodes=sorted(set(reasons)))
