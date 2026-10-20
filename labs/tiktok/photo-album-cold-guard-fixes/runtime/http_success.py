"""AGPL-3.0 final content policy only; no HTTP implementation or accounting rewrite."""
POLICY='FULL_GET_200_ONLY'
def success(result,rebuilt,n):
    failures=[];observed=[]
    for name in ('metadataPacket','preparePacket'):
        for row in result[name]['rows']:
            status=row.get('status');diagnostic=row.get('sendDiagnostic',{}).get('status')
            item=dict(packet=name,phase=row['phase'],index=row['index'],status=status,diagnosticStatus=diagnostic)
            observed.append(item)
            if type(status) is not int or type(diagnostic) is not int or status!=200 or diagnostic!=200:failures.append(item)
    statuses=rebuilt.get('httpStatusesObserved',{})
    metadata=statuses.get('metadata');prepare=statuses.get('prepare')
    count_ok=(type(n) is int and 1<=n<=5 and type(metadata) is list and 1<=len(metadata)<=2 and type(prepare) is list and len(prepare)==n)
    report_ok=count_ok and all(type(s) is int and s==200 for s in metadata+prepare)
    return dict(policy=POLICY,accepted=not failures and bool(report_ok),observed=observed,
                failedResponses=failures,reportStatusGate=bool(report_ok),originReceipt='UNKNOWN')
