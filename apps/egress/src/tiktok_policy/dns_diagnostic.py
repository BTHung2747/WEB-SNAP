"""Strict v4 observer/receipt contract. No downgrade or historical migration."""
import copy,math
from .dns_admission import ident,integer,stats_valid,packet_valid,REASONS
def byte_count(value,cap):return type(value) is int and 0<value<=cap
def missing():
    return dict(version=4,helperID=None,responseStatus='MISSING',responseCode='UNKNOWN',responseType='MISSING',answerCount=None,
      admission=None,uniqueIPv4=None,uniqueIPv6=None,evidence='PARTIAL',resolution='FAIL')
def observe(value):
    out=missing();out['responseType']='OBJECT' if type(value) is dict else 'INVALID'
    if type(value) is not dict:return out
    if ident(value.get('helperID')):out['helperID']=value['helperID']
    if type(value.get('status')) is str and value['status'] in ('OK','ERROR'):out['responseStatus']=value['status']
    if type(value.get('code')) is str and value['code'] in REASONS:out['responseCode']=value['code']
    if type(value.get('answers')) is list and len(value['answers'])<=64:out['answerCount']=len(value['answers'])
    if stats_valid(value.get('admission')):out['admission']=copy.deepcopy(value['admission'])
    if packet_valid(value):out.update(evidence='COMPLETE',uniqueIPv4=sum(r[0]==2 for r in value['answers']),uniqueIPv6=sum(r[0]==10 for r in value['answers']))
    return out
def valid(row):
    if type(row) is not dict:return False
    expected=dict(version=4,responseStatus='OK',responseCode='OK',responseType='OBJECT',evidence='COMPLETE',resolution='PASS',nativeExit=0,reaped=True,pipesClosed=True,groupsLeft=0)
    if set(row)!=set(expected)|{'helperID','admission','answerCount','uniqueIPv4','uniqueIPv6','elapsed'} or not ident(row.get('helperID')) or not all(type(row.get(k)) is type(v) and row[k]==v for k,v in expected.items()):return False
    s=row['admission'];v4=row['uniqueIPv4'];v6=row['uniqueIPv6'];n=row['answerCount']
    return (stats_valid(s) and s['decision']=='ALLOW' and integer(n,1,64) and n==s['admittedCount'] and integer(v4,0,64) and integer(v6,0,64) and v4+v6==n and
      v4<=s['ipv4Rows'] and v6<=s['ipv6Rows'] and (v4>0)==(s['ipv4Rows']>0) and (v6>0)==(s['ipv6Rows']>0) and
      type(row['elapsed']) in (int,float) and math.isfinite(row['elapsed']) and row['elapsed']>=0)
def validate_receipt(receipt,trace=None):
    d=receipt.get('dnsDiagnostic') if type(receipt) is dict else None
    accepted=valid(d);reasons=[] if accepted else ['DIAGNOSTIC_NOT_COMPLETE']
    # Validate the untrusted outer object before Python dict equality/linking.
    if accepted and not stats_valid(receipt.get('dnsAdmission')):
        accepted=False;reasons.append('HELPER_ADMISSION_SCHEMA')
    if accepted:
        pairs={'dnsExit':'nativeExit','dnsChildReaped':'reaped','dnsPipesClosed':'pipesClosed','dnsGroupLeft':'groupsLeft','dnsHelperID':'helperID','dnsAdmission':'admission'}
        for outer,inner in pairs.items():
            if outer not in receipt or type(receipt[outer]) is not type(d[inner]) or receipt[outer]!=d[inner]:accepted=False;reasons.append('HELPER_RECEIPT_CONFLICT_OR_MISSING')
        if type(receipt.get('answerCap')) is not int or receipt['answerCap']!=64 or type(receipt.get('rawCap')) is not int or receipt['rawCap']!=256:accepted=False;reasons.append('HELPER_CAP_CONFLICT')
        if not byte_count(receipt.get('inputBytes'),16384) or not byte_count(receipt.get('responseBytes'),32768) or type(receipt.get('inputCap')) is not int or receipt['inputCap']!=16384 or type(receipt.get('responseCap')) is not int or receipt['responseCap']!=32768:accepted=False;reasons.append('HELPER_BYTE_CONTRACT')
        if trace is not None:
            rows=[r for r in trace if r.get('ownerID')==d['helperID']]
            if len(rows)!=2 or rows[0].get('phase')!='DNS_HELPER' or rows[1].get('phase')!='DNS_HELPER' or rows[0].get('event')!='BEGIN' or rows[1].get('event')!='END' or not byte_count(rows[0].get('inputBytes'),16384) or not byte_count(rows[1].get('responseBytes'),32768) or rows[0].get('inputBytes')!=receipt.get('inputBytes') or rows[1].get('responseBytes')!=receipt.get('responseBytes') or type(rows[1].get('nativeExit')) is not int or rows[1]['nativeExit']!=0 or rows[1].get('childReaped') is not True:accepted=False;reasons.append('HELPER_TRACE_ORDER_OR_LINK_CONFLICT')
    return dict(version=4,status='COMPLETE' if accepted else 'PARTIAL',accepted=accepted,reasonCodes=sorted(set(reasons)))
