"""Offline-only receipt/trace contradictions; retain source packet and original evidence."""
import copy
def mutate(receipts,trace,mode):
    r=copy.deepcopy(receipts);t=copy.deepcopy(trace)
    if mode in ('batchval-groups0','batchval-preexisting'):r[0]['batch']['groups']=0
    elif mode=='batchval-records-empty':r[0]['batch']['groupRecords']=[]
    elif mode=='batchval-owner-disjoint':r[0]['ownerID']='f'*16
    elif mode=='batchval-registry-disjoint':r[0]['registryOwnerID']='e'*16
    elif mode=='batchval-duplicate-owner':r.append(copy.deepcopy(r[0]))
    elif mode=='batchval-missing-operation':
        owner=r[0]['registryOwnerID'];t=[x for x in t if not(x['ownerID']==owner and x['phase']=='LIBRARY_SELECT' and x['groupIndex']==1)]
    elif mode=='batchval-record-mismatch':r[0]['batch']['groupRecords'][0]['pending']=1
    else:raise ValueError('FIXTURE_MODE')
    return r,t
