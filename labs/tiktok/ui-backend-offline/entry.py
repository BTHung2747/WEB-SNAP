import sys
sys.path.insert(0,'/lab')
from supervisor import run
try:code=run(['bash','/newlab/start.sh'])
except BaseException:print('{"error":"OFFLINE_ENTRY_FAILED"}');code=1
sys.exit(code)
