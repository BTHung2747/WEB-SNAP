"""Use existing body builder only; no import of server, transport or source."""
import ast,pathlib,sys
path=pathlib.Path('/fixtures/proxy.py');tree=ast.parse(path.read_text())
node=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='body')
namespace={'__builtins__':__builtins__,'json':__import__('json'),'mode':lambda:'happy'}
exec(compile(ast.Module(body=[node],type_ignores=[]),str(path),'exec'),namespace)
body=namespace['body']();assert len(body)<=8192
sys.stdout.buffer.write(body)
