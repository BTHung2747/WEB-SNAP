"""Native offline accounting validation gate. Not TCP, file or source acceptance."""
import json,sys
from accounting import receipt
def main():
    data=sys.stdin.buffer.read(128*1024+1)
    if len(data)>128*1024:return 20
    try:
        args=json.loads(data)
        r=receipt(args['result'],args['events'],observer_present=args['observerPresent'],observer_incomplete=args.get('observerIncomplete',False))
        accepted=r['version']==3 and r['exact'] and r['withinBudget']
    except (KeyError,ValueError,TypeError,AttributeError):accepted=False
    print(json.dumps({'accepted':bool(accepted),'scope':'ACCOUNTING_LINKAGE_GATE'}),flush=True)
    return 0 if accepted else 20
if __name__=='__main__':sys.exit(main())
