import os,sys
def main():
    if os.environ.get('STEP5_EXECUTE_SOURCE')!='1':return 78
    sys.path[:0]=['/lab','/repo/apps/egress/src','/repo/apps/egress/vendor']
    from dns_child_environment import configure
    configure() # -I isolates this parent; the production Popen child inherits this explicit pinned path.
    import egress,json,pathlib,threading,time
    from proxy_collect import install
    root=pathlib.Path('/control');server=egress.Server(('0.0.0.0',8888),egress.Handler)
    failed=[]
    def serve():
        try:server.serve_forever(poll_interval=.02)
        except BaseException:failed.append(True)
    install(server,root);thread=threading.Thread(target=serve);thread.start()
    (root/'ready').write_text('ready');end=time.monotonic()+340
    try:
        while not (root/'stop').exists() and time.monotonic()<end and not failed:time.sleep(.05)
    finally:
        server.shutdown();server.server_close();thread.join(2)
        (root/'proxy-result.json').write_text(json.dumps(dict(listenerClosed=server.socket.fileno()==-1,serveThreadClosed=not thread.is_alive(),serveFailed=bool(failed),completedConnectionCount=len(server.completed),mode='source'),separators=(',',':')))
    return 0 if server.socket.fileno()==-1 and not thread.is_alive() and not failed else 1
if __name__=='__main__':
    try:code=main()
    except BaseException:print('{"error":"PROXY_ENTRY_FAILED"}');code=1
    sys.exit(code)
