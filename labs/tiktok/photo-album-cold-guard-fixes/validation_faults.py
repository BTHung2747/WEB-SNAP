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
    elif mode.startswith('closure-'):
        owner=r[0]['registryOwnerID'];context=r[0]['ownerID']
        selected=[x for x in t if x['ownerID']==owner and x['phase']=='REGISTRY_CLOSE']
        if mode in ('closure-live','closure-preexisting'):selected[-1]['live']=1
        elif mode=='closure-missing':t=[x for x in t if x not in selected]
        elif mode=='closure-terminal':t.remove(selected[0])
        elif mode=='closure-error':selected[-1].update(event='ERROR',code='ERROR')
        elif mode=='closure-owner':
            for x in selected:x['ownerID']='f'*16
        elif mode in ('closure-before-winner','closure-before-handoff','closure-late'):
            t=[x for x in t if x not in selected]
            phase='LIBRARY_SELECT' if mode=='closure-before-winner' else 'CONNECT_200' if mode=='closure-before-handoff' else 'WORKER_RETURN'
            who=owner if phase=='LIBRARY_SELECT' else context
            at=next(i for i,x in enumerate(t) if x['ownerID']==who and x['phase']==phase)
            if mode=='closure-late':at+=1
            t[at:at]=selected
        elif mode=='closure-extra':
            at=t.index(selected[-1])+1;extras=[]
            for index in (2,3):
                pair=copy.deepcopy(selected)
                for x in pair:x['operationIndex']=index
                extras.extend(pair)
            t[at:at]=extras
        else:raise ValueError('FIXTURE_MODE')
    else:raise ValueError('FIXTURE_MODE')
    return r,t
