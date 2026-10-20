import sys,unittest,socket
from unittest.mock import patch
sys.path.insert(0,'/app/infra')
import egress
class Policy(unittest.TestCase):
    def test_domain_boundaries(self):
        self.assertTrue(egress.allowed('rr1.googlevideo.com'))
        for h in ['youtube.com.evil.example','localhost','127.0.0.1','metadata.google.internal','youtube.com@127.0.0.1']:self.assertFalse(egress.allowed(h))
    def test_rebinding_and_mixed_private_dns(self):
        for ip in ['127.0.0.1','10.0.0.1','169.254.169.254','::1','fc00::1','100.64.0.1']:
            with patch('socket.getaddrinfo',return_value=[(socket.AF_INET,socket.SOCK_STREAM,6,'',(ip,443))]):
                self.assertRaises(ValueError,egress.public_addresses,'www.youtube.com')
        with patch('socket.getaddrinfo',return_value=[(2,1,6,'',('8.8.8.8',443)),(2,1,6,'',('192.168.1.1',443))]):self.assertRaises(ValueError,egress.public_addresses,'www.youtube.com')
if __name__=='__main__':unittest.main()
