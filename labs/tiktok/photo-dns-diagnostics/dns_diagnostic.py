"""Whitelist-only observation of the existing bounded helper IPC object."""
import math
def missing():
    return dict(responseStatus='MISSING', responseCode='UNKNOWN', responseType='MISSING',
                answerCount=None, evidence='PARTIAL', resolution='FAIL')

def observe(value):
    row = missing()
    row['responseType'] = {dict:'OBJECT', list:'ARRAY', str:'STRING', int:'NUMBER',
                           float:'NUMBER', bool:'BOOLEAN', type(None):'NULL'}.get(type(value), 'UNKNOWN')
    if type(value) is not dict:
        return row
    status = value.get('status')
    row['responseStatus'] = status if type(status) is str and status in ('OK', 'ERROR') else 'UNKNOWN'
    code = value.get('code', 'OK' if status == 'OK' else None)
    row['responseCode'] = code if type(code) is str and code in ('OK', 'DNS_ERROR', 'ANSWER_CAP', 'DEADLINE') else 'UNKNOWN'
    answers = value.get('answers')
    if type(answers) is list and len(answers) <= 32768:
        row['answerCount'] = len(answers)
    recognized = ((row['responseStatus'] == 'OK' and row['responseCode'] == 'OK') or
                  (row['responseStatus'] == 'ERROR' and row['responseCode'] in ('DNS_ERROR', 'ANSWER_CAP', 'DEADLINE')))
    typed_identity=(type(value.get('unexpectedInherited')) is int and value['unexpectedInherited']==0
                    and type(value.get('threads')) is int and value['threads']==1)
    if recognized and row['answerCount'] is not None and typed_identity:
        row['evidence'] = 'COMPLETE'
    return row

def valid(row):
    if type(row) is not dict:
        return False
    expected = {'responseStatus':'OK','responseCode':'OK','responseType':'OBJECT',
                'evidence':'COMPLETE','resolution':'PASS','nativeExit':0,
                'reaped':True,'pipesClosed':True,'groupsLeft':0}
    return (set(row) == set(expected) | {'answerCount','elapsed'} and
            all(type(row.get(k)) is type(v) and row[k] == v for k,v in expected.items()) and
            type(row.get('answerCount')) is int and 1 <= row['answerCount'] <= 64 and
            type(row.get('elapsed')) in (int,float) and math.isfinite(row['elapsed']) and row['elapsed'] >= 0)
