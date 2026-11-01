"""AGPL-3.0: internal CONNECT capability, never an upstream request header."""
import base64,os,re
from .connection_boundaries import ObservedAdapter
def phase_credentials():
    a=os.environ.get('WED_EGRESS_PHASE','');b=os.environ.get('WED_EGRESS_CAP','')
    if not re.fullmatch('[a-f0-9]{64}',a) or not re.fullmatch('[a-f0-9]{64}',b):raise ValueError('PROXY_PHASE_REQUIRED')
    return a,b
class PhotoProxyAdapter(ObservedAdapter):
    def __init__(self,*args,credentials=None,**kwargs):
        self.phase_credentials=phase_credentials() if credentials is None else credentials
        if not isinstance(self.phase_credentials,tuple) or len(self.phase_credentials)!=2 or not all(type(v) is str and re.fullmatch('[a-f0-9]{64}',v) for v in self.phase_credentials):raise ValueError('PROXY_PHASE_REQUIRED')
        super().__init__(*args,**kwargs)
    def proxy_headers(self,proxy):
        headers=super().proxy_headers(proxy)
        headers['Proxy-Authorization']='Basic '+base64.b64encode(':'.join(self.phase_credentials).encode('ascii')).decode('ascii')
        return headers
