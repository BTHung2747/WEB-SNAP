def main():
    import hashlib,json,pathlib,sys,subprocess,time,os,signal
    out=pathlib.Path('/control')
    def verify():
        for r in json.loads((out/'expected-source.json').read_text()):assert hashlib.sha256((pathlib.Path('/repo')/r['path']).read_bytes()).hexdigest()==r['sha256']
    verify()
    start=time.monotonic()
    from collector_test import suite
    (out/'collector-result.json').write_text(json.dumps(suite()))
    p=subprocess.Popen(['bash','/fixture/start.sh'],start_new_session=True)
    exitcode=None
    expired=set()
    def stop_owned_case(cfg):
        case=out/'cases'/cfg['case']
        (case/'stopped').write_text('ABSOLUTE_WORKFLOW_DEADLINE')
        records=[]
        for name in ('analyze','prepare'):
            f=case/(name+'.child-once')
            if not f.exists():continue
            r=json.loads(f.read_text());pid=r['pid']
            try:
                tail=pathlib.Path('/proc',str(pid),'stat').read_text().rsplit(')',1)[1].split()
                if int(tail[2])!=r['pgid'] or int(tail[19])!=r['startTicks']:raise ValueError('GROUP_IDENTITY_UNKNOWN')
                os.killpg(r['pgid'],signal.SIGTERM);records.append(dict(phase=name,pid=pid,signal='SIGTERM',identityChecked=True))
            except ProcessLookupError:pass
            except FileNotFoundError:pass
        (case/'independent-deadline.json').write_text(json.dumps(dict(expired=True,clock='monotonic',successAllowed=False,groups=records)))
        return case,records,time.monotonic()
    terminating=[]
    try:
        while p.poll() is None:
            if not (out/'startup.ready').exists() and time.monotonic()-start>60:raise TimeoutError('STARTUP_60')
            if (out/'active.json').exists():
                cfg=json.loads((out/'active.json').read_text())
                if time.monotonic()>=cfg['end'] and cfg['case'] not in expired:
                    expired.add(cfg['case']);terminating.append(stop_owned_case(cfg))
            for case,records,at in list(terminating):
                if time.monotonic()-at>2:
                    for r in records:
                        try:
                            original=json.loads((case/(r['phase']+'.child-once')).read_text())
                            tail=pathlib.Path('/proc',str(r['pid']),'stat').read_text().rsplit(')',1)[1].split()
                            if int(tail[2])==original['pgid'] and int(tail[19])==original['startTicks']:os.killpg(original['pgid'],signal.SIGKILL)
                        except (FileNotFoundError,ProcessLookupError):pass
                    terminating.remove((case,records,at))
            if time.monotonic()-start>320:raise TimeoutError('OUTER_EXECUTION')
            time.sleep(.05)
        exitcode=p.returncode
    finally:
        # All source requests originate detached media groups; client cancels before normal shutdown.
        if p.poll() is None:
            os.killpg(p.pid,signal.SIGTERM)
            try:p.wait(timeout=2)
            except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=4)
    verify();sys.exit(exitcode if exitcode is not None else 90)

if __name__=='__main__':
    import sys,json
    try:main()
    except SystemExit:raise
    except BaseException:
        print(json.dumps(dict(error='LAB_ENTRY_FAILED',sourceCalls=0)))
        sys.exit(1)
