"""Source CLI delegate: no test imports or environment search path."""
import os,sys
if __name__=='__main__':
    if not sys.flags.isolated:
        os.execv(sys.executable,[sys.executable,'-I',__file__,*sys.argv[1:]])
    sys.path[:0]=['/lab','/app/apps/media/src']
    from media import main
    try:code=main()
    except BaseException:print('{"error":"CONTENT_UNAVAILABLE"}');code=26
    sys.exit(code)
