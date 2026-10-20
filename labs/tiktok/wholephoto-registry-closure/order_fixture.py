"""Offline faults only: change BEGIN positions, preserve packet and terminal order."""
import copy

def mutate(events,mode):
    out=copy.deepcopy(events)
    rid=next(e['requestID'] for e in out if e['phase']=='metadata' and e['boundary']=='CONNECTION_SETUP')
    def pos(boundary,event):
        return next(i for i,e in enumerate(out) if e['requestID']==rid and e['phase']=='metadata' and e['boundary']==boundary and e['event']==event)
    if mode in ('observer-order-send','observer-order-setup'):
        boundary='REQUEST_SEND' if mode=='observer-order-send' else 'CONNECTION_SETUP'
        begin=out.pop(pos(boundary,'BEGIN'));out.insert(pos(boundary,'END')+1,begin)
    elif mode in ('observer-order-header','observer-order-header-preexisting'):
        begin=out.pop(pos('RESPONSE_HEADERS','BEGIN'));out.insert(pos('REQUEST_SEND','END'),begin)
    elif mode=='observer-order-reopen':
        begin=copy.deepcopy(out[pos('REQUEST_SEND','BEGIN')]);out.insert(pos('REQUEST_SEND','END')+1,begin)
    else:raise ValueError('OFFLINE_ORDER_MODE')
    before=[e for e in events if e['event']!='BEGIN'];after=[e for e in out if e['event']!='BEGIN']
    assert before==after # audit's terminal summary stays byte-for-byte equivalent
    return out
