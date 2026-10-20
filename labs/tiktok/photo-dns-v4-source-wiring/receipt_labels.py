"""Owned receipt semantics; invocation counts are not network request counts."""
def labels(stage, analyze_started):
    if stage not in ('offline', 'source') or type(analyze_started) is not bool:
        raise ValueError('RECEIPT_STAGE')
    return dict(source=stage == 'source', fixture=stage == 'offline',
                analyzeInvocations=int(analyze_started),
                sourceAnalyzeAttempts=int(stage == 'source' and analyze_started),
                sourceCalls=0 if stage == 'offline' else 'UNKNOWN_USE_REQUEST_ACCOUNTING')

def valid(row, stage, *, file_accepted=False):
    if type(row) is not dict or stage not in ('offline', 'source') or type(file_accepted) is not bool:
        return False
    count = row.get('analyzeInvocations')
    if type(count) is not int or count not in (0, 1):
        return False
    # A packet (including failure) or accepted file proves invocation began.
    # GET/send counters do not establish a workflow invocation.
    started_evidence = file_accepted or any(row.get(key) is not None
                                           for key in ('metadataPacket', 'preparePacket'))
    if started_evidence and count != 1:
        return False
    expected = labels(stage, bool(count))
    return all(type(row.get(key)) is type(value) and row.get(key) == value
               for key, value in expected.items())
