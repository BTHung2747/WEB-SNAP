import json,os,sys
print(json.dumps(dict(args=sys.argv[1:],cwd=os.getcwd(),env=os.environ.get('WED_NATIVE_OFFLINE_TEST')),ensure_ascii=True))
