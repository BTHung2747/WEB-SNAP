// Compile source entry modules without evaluating DB/network constructors.
const ts=require('/app/node_modules/typescript'),fs=require('node:fs'),cp=require('node:child_process');
const files=['driver.ts','workflow.ts','worker.ts','selection.ts'];
for(const f of files){const r=ts.transpileModule(fs.readFileSync('/lab/'+f,'utf8'),{fileName:f,compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext},reportDiagnostics:true});if((r.diagnostics||[]).some(d=>d.category===ts.DiagnosticCategory.Error))throw Error('TS_SYNTAX');}
for(const f of ['driver.ts','worker.ts']){const p=cp.spawnSync('/app/node_modules/.bin/tsx',['/lab/'+f],{env:{...process.env,STEP5_EXECUTE_SOURCE:'',STEP5_OFFLINE_TEST:''},timeout:10000,encoding:'utf8'});if(p.status!==78||!p.stdout.includes('SOURCE_DISABLED'))throw Error('TS_DEFAULT_DENY');}
fs.writeFileSync('/control/ts-probe.json',JSON.stringify({status:'PASS_TS_ENTRY_COMPILE_AND_DEFAULT_DENY',files,deniedEntries:2,sourceGrant:false,sourceExecutionStarted:false,sourceCalls:0}));
