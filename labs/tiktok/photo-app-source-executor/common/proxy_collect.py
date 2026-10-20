"""Collect WED owned-context completion; never replace the production broker decision."""
import json,pathlib
def install(server,root):
    root=pathlib.Path(root);broker=server.phase_broker;delegate=broker.finish;count=0
    def finish(ctx,result):
        nonlocal count
        count+=1
        if count>64:ctx.trace.mark_incomplete();raise ValueError('COLLECTOR_CAP')
        entry=broker.entries.get(getattr(ctx,'_phase_key',None),{})
        row=dict(phase=entry.get('phase','UNKNOWN'),ownerID=ctx.cid,accepted=result.get('accepted') is True,
                 threadClosed=result.get('workerThreadClosed') is True,clientClosed=result.get('clientClosed') is True,
                 traceIncomplete=result.get('traceIncomplete') is not False)
        # Only booleans/opaque ID/phase. No host/path/header/cookie/private phase credential.
        data=json.dumps(row,separators=(',',':'))+'\n'
        with (root/'completions.jsonl').open('a') as f:f.write(data)
        return delegate(ctx,result)
    broker.finish=finish
