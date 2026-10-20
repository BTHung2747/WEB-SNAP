import json,sys,time
mode=sys.argv[1] if len(sys.argv)>1 else 'malformed'
if mode=='hang':time.sleep(30)
elif mode=='oversize':sys.stdout.write('x'*32769)
elif mode=='pass-exit20':sys.stdout.write('{}');sys.stdout.flush();sys.exit(20)
elif mode=='duplicate':sys.stdout.write('{"version":4,"version":4}')
else:sys.stdout.write('not-json')
