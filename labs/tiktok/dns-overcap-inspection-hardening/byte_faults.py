"""Explicit offline tamper; no runtime transport or source hook."""
import copy
def mutate(receipts,trace):
    rows=copy.deepcopy(receipts);events=copy.deepcopy(trace)
    for row in rows:
        row['dns'].pop('inputBytes',None);row['dns'].pop('responseBytes',None)
    for row in events:
        if row['phase']=='DNS_HELPER':
            row.pop('inputBytes',None);row.pop('responseBytes',None)
    return rows,events
