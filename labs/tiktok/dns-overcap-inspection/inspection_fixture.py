"""Explicit offline DNS rows only. Never imported by source/main."""
import json,pathlib,socket,time
from unittest.mock import patch
def rows(mode):
    base=(socket.AF_INET,socket.SOCK_STREAM,6,'',('1.1.1.1',443))
    if mode=='overcap-unique':return [(socket.AF_INET,socket.SOCK_STREAM,6,'',('8.8.0.'+str(i),443)) for i in range(1,66)]
    if mode=='overbound':return [base]*257
    if mode=='inspection-invalid':return [base]*64+[(socket.AF_INET,socket.SOCK_STREAM,6,'',('INVALID',443))]
    return [base]*65
def main():
    import dns_helper
    settings=json.loads(pathlib.Path('/control/control.json').read_text());mode=settings['mode']
    def expired_scan(*args,**kwargs):
        from dns_inspection import partial
        return partial('DEADLINE')
    with patch('dns_helper.socket.getaddrinfo',return_value=rows(mode)):
        if mode=='inspection-deadline':
            # Public owned observer injection, same producer encoder/IPC. Not timing guarantee.
            original=dns_helper.packet_rows
            def denied(values,end,**kwargs):return original(values,end,inspector=expired_scan,**kwargs)
            with patch('dns_helper.packet_rows',side_effect=denied):return dns_helper.main()
        return dns_helper.main()
if __name__=='__main__':
    import sys
    try:sys.exit(main())
    except SystemExit:raise
    except BaseException:sys.exit(20)
