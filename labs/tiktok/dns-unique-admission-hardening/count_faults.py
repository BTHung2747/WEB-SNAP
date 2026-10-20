"""Explicit offline receipt corruption; raw producer receipts saved before mutation."""
import copy
def mutate(receipts,mode):
    rows=copy.deepcopy(receipts);outer=rows[0]['dns'];d=outer['dnsDiagnostic'];c=d['counts']
    if mode=='counts-family':
        c.update(rawCount=2,endpointCount=1,duplicateCount=1,ipv4Rows=1,ipv6Rows=1);d['answerCount']=2
        outer['dnsCounts']=copy.deepcopy(c)
    elif mode=='counts-raw-exact':
        c.update(evidence='PARTIAL',reason='RAW_CAP',rawCountMode='EXACT',rawCount=64,endpointCount=None,duplicateCount=None,ipv4Rows=None,ipv6Rows=None);outer['dnsCounts']=copy.deepcopy(c)
    elif mode=='counts-raw-unknown':
        c.update(evidence='PARTIAL',reason='RAW_CAP',rawCountMode='UNKNOWN',rawCount=None,endpointCount=None,duplicateCount=None,ipv4Rows=None,ipv6Rows=None);outer['dnsCounts']=copy.deepcopy(c)
    elif mode=='counts-missing':d.pop('counts')
    elif mode=='counts-conflict':outer['dnsCounts']=dict(c,endpointCount=0)
    elif mode=='counts-helper-disjoint':outer['dnsHelperID']='e'*16
    elif mode=='counts-unknown':c['reason']='UNKNOWN';outer['dnsCounts']=copy.deepcopy(c)
    else:raise ValueError('UNKNOWN_OFFLINE_COUNT_FAULT')
    return rows
