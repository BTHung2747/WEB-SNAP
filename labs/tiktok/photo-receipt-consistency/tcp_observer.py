"""Only diagnostic identities/coverage; networking remains delegated to the public loop."""
PHASES=('TCP_CONNECT','FIXTURE_TCP')
def next_index(loop):
    loop.calls+=1
    return loop.calls

def coverage(rows):
    pairs={};bad=False
    for row in rows:
        if row.get('phase') not in PHASES:continue
        index=row.get('index');owner=row.get('ownerID');event=row.get('event')
        if type(index) is not int or not 1<=index<=64 or not isinstance(owner,str) or len(owner)!=16 or event not in ('BEGIN','END','ERROR'):bad=True;continue
        pairs.setdefault((owner,row['phase'],index),[]).append(event)
    missing=sum(v.count('BEGIN')!=1 or sum(v.count(e) for e in ('END','ERROR'))!=1 for v in pairs.values())
    return {'version':2,'status':'INCOMPLETE' if bad or missing else 'COMPLETE','attempts':len(pairs),
        'missingOrDuplicateTerminals':missing,'invalidIdentity':bad,'perSocketNetworkCause':'UNKNOWN'}
