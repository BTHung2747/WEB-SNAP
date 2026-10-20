"""Small native offline gate; this is not metadata/source/file acceptance."""
import json,sys
def main():
    data=sys.stdin.buffer.read(4097)
    if len(data)>4096:return 20
    try:
        row=json.loads(data)
        ok=(row.get('coverage')=='COMPLETE' and row.get('incomplete') is False and row.get('socketsLeft')==0)
    except (ValueError,TypeError):ok=False
    print(json.dumps({'accepted':ok,'scope':'NUMERIC_DIAGNOSTIC_GATE'}),flush=True)
    return 0 if ok else 20
if __name__=='__main__':sys.exit(main())
