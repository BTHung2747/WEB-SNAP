// Cached compiler, syntax and available public builtins; no browser/backend run.
const fs=require('node:fs'),ts=require('/app/node_modules/typescript');
if(process.versions.node!=='22.22.3')throw Error('NODE_VERSION');
const result=ts.transpileModule(fs.readFileSync('/newlab/controller.ts','utf8'),{fileName:'controller.ts',compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext},reportDiagnostics:true});
if((result.diagnostics||[]).some(d=>d.category===ts.DiagnosticCategory.Error))throw Error('TS_SYNTAX');
for(const [mod,names] of [['node:http',['createServer','request']],['node:child_process',['spawn']]])for(const name of names)if(typeof require(mod)[name]!=='function')throw Error('BUILTIN_API');
fs.writeFileSync('/control/compiler.json',JSON.stringify({node:process.versions.node,typescript:ts.version,syntax:true,builtinAPI:true,sourceCalls:0}));
