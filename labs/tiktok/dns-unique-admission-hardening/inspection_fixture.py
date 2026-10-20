"""Owned fake resolver responses, before actual helper producer/IPC/deadline."""
import json,pathlib,socket,sys
from unittest.mock import patch
def rows(mode):
    base=(2,1,6,'',('1.1.1.1',443))
    if mode=='mock129':return [(2,1,6,'',('1.1.1.'+str(i%40+1),443)) for i in range(129)]
    if mode=='unique65':return [(2,1,6,'',('1.1.1.'+str(i+1),443)) for i in range(65)]
    if mode=='bound257':return [base]*257
    if mode=='private-tail':return [base]*128+[(2,1,6,'',('10.0.0.1',443))]
    if mode=='unicode-cap':return [(2,1,6,'漢'*255,('1.1.1.'+str(i+1),443)) for i in range(64)]
    return [base]*65
def main():
    import dns_helper
    mode=json.loads(pathlib.Path('/control/control.json').read_text())['mode']
    with patch('dns_helper.socket.getaddrinfo',return_value=rows(mode)):return dns_helper.main()
if __name__=='__main__':
    try:sys.exit(main())
    except SystemExit:raise
    except BaseException:sys.exit(20)
