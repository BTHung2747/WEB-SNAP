import socket
for target in ['127.0.0.1:443','169.254.169.254:443','youtube.com.evil.invalid:443','[::1]:443']:
    with socket.create_connection(('egress',8888),timeout=3) as conn:
        conn.sendall(('CONNECT '+target+' HTTP/1.1\r\nHost: '+target+'\r\n\r\n').encode())
        assert conn.recv(256).startswith(b'HTTP/1.1 403'), target
print('PASS live CONNECT proxy rejects private IPs and host lookalikes')
try:
    socket.create_connection(('8.8.8.8',443),timeout=2).close()
    raise AssertionError('Worker can bypass proxy: external route unexpectedly available')
except (OSError,TimeoutError):
    print('PASS worker internal network cannot bypass proxy for external connection')
