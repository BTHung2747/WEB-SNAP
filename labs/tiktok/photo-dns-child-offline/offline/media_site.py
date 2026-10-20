"""Loaded by sitecustomize ONLY in a separate media lab; public Requests APIs."""
from tiktok.connection_boundaries import ObservedAdapter
build=ObservedAdapter.build_connection_pool_key_attributes
certify=ObservedAdapter.cert_verify
def build_lab(self,request,verify,cert=None):
    assert verify is True
    return build(self,request,'/control/fixture-cert.pem',cert)
def certify_lab(self,conn,url,verify,cert):
    assert verify is True
    return certify(self,conn,url,'/control/fixture-cert.pem',cert)
ObservedAdapter.build_connection_pool_key_attributes=build_lab
ObservedAdapter.cert_verify=certify_lab
