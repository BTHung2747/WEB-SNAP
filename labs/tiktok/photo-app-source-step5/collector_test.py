import json,pathlib,sys
from collector import diagnostics,clean
def suite():
    # Fake token in pathname and query must not survive projection; no actual source URL.
    row={'phase':'metadata','method':'GET','url':'https://example.invalid/PATH_TOKEN?token=QUERY_TOKEN',
         'status':200,'decodedBytes':1,'sendDiagnostic':{'code':'HTTP_RESPONSE','status':200},'boundaries':{'incomplete':False}}
    value=diagnostics({'requests':[row],'inputBytes':1},'analyze')
    assert value['complete'] and 'TOKEN' not in json.dumps(value) and value['wireGET']=='UNKNOWN'
    for bad in ({},{'requests':[]},{'requests':[row]*3}):
        try:diagnostics(bad,'analyze')
        except ValueError:pass
        else:raise AssertionError('ACCEPTED_INVALID')
    unknown=diagnostics({'requests':[{'phase':'metadata','method':'GET'}]},'analyze')
    assert not unknown['complete'] and unknown['observedResponses']==0
    try:clean({'code':'https://example.invalid/PATH_TOKEN?token=QUERY_TOKEN'})
    except ValueError:pass
    else:raise AssertionError('UNSAFE_ENUM')
    return dict(status='PASS_BOUNDED_COLLECTOR',cases=6,urlFakeOnly=True,sourceCalls=0)
if __name__=='__main__':pathlib.Path('/control/collector-result.json').write_text(json.dumps(suite()))
