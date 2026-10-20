"""Fixture-only receipt tampering AFTER real helper/HTTP/file producer completion."""
import copy
def mutate(receipts,mode):
    rows=copy.deepcopy(receipts);outer=rows[0]['dns'];d=outer['dnsDiagnostic']
    if mode=='inspection-conflict':outer['dnsInspection']={'version':1}
    elif mode=='inspection-count':outer['dnsCounts']=dict(d['counts'],rawCount=0)
    elif mode=='inspection-native':outer['dnsExit']=20
    elif mode=='inspection-id':outer['dnsHelperID']='e'*16
    elif mode=='inspection-closure':outer['dnsChildReaped']=False
    elif mode=='inspection-missing':d.pop('inspection')
    else:raise ValueError('UNKNOWN_OFFLINE_INSPECTION_FAULT')
    return rows
