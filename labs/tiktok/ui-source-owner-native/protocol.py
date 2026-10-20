"""Owner-side host I/O over the accepted atomic/source handshake, not an issuer."""
import argparse,importlib.util,json,pathlib,sys,time,datetime
_p=pathlib.Path(__file__).resolve().parent.parent/'ui-source-glue'/'handshake.py'
_s=importlib.util.spec_from_file_location('owner_source_protocol',_p);h=importlib.util.module_from_spec(_s);_s.loader.exec_module(h)
def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['clock','install','wait','complete']);p.add_argument('--root');p.add_argument('--bundle');p.add_argument('--cleanup',choices=['CLOSED','UNKNOWN']);p.add_argument('--execution',choices=['PASS','FAIL']);a=p.parse_args()
    if a.command=='clock':print(json.dumps(dict(monotonicNS=str(time.monotonic_ns()),utc=datetime.datetime.now(datetime.timezone.utc).isoformat())));return 0
    root=pathlib.Path(a.root).resolve()
    if a.command=='install':
        bundle=h.io.load(pathlib.Path(a.bundle));c=bundle['contract'];d=bundle['decision']
        # Runtime compatibility documents are NOT a human approval or claim.
        # Native owner admits only after the separately signed approval consumer.
        for name,value in [('source-decision.json',d),('source-budget.json',bundle['budget'])]:
            with (root/name).open('x',encoding='utf-8') as f:json.dump(value,f,separators=(',',':'))
        h.require(h.io.digest(h.io.read_raw(root/'source-decision.json'))==c['decisionSHA256'] and h.io.digest(h.io.read_raw(root/'source-budget.json'))==c['budgetSHA256'],'BUNDLE_HASH')
        h.io.publish_atomic(root,h.io.CONTRACT,c);h.contract(root);print('{"status":"RUNTIME_INPUTS_INSTALLED_NOT_PERMISSION"}');return 0
    if a.command=='wait':
        result=h.wait_decision(root,role='owner');print(json.dumps(dict(status=result['status'],code=result['code'])));return 0 if result['status']=='ACCEPTED' else 21
    if not (root/h.io.DECISION).exists():
        c=h.contract(root);h.io.publish_atomic(root,h.io.DECISION,dict(schema='wed-ui-photo-source-browser-decision-v1',**h.binding(c),decisionMonoNs=str(time.monotonic_ns()),status='NOT_OBSERVED',code='DEADLINE',observationSHA256=None))
    result=h.complete(root,a.cleanup,a.execution,role='owner');print(json.dumps(dict(status=result['status'],code=result['code'])));return 0 if result['status']=='PASS_UI_SOURCE' else 22
if __name__=='__main__':
    try:code=main()
    except Exception:print('{"status":"FAIL_OWNER_PROTOCOL"}');code=20
    raise SystemExit(code)
