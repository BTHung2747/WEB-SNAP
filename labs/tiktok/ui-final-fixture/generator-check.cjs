'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
assert.equal(process.versions.node,'22.22.3');const paths=['/observationfix/gateway.cjs','/observationfix/failure-path.cjs','/observationfix/event-writer.cjs','/observationfix/reasons.cjs','/finalfixture/final-gate.cjs'];
const syntax=[];for(const p of paths){const r=spawnSync(process.execPath,['--check',p],{timeout:3000,maxBuffer:4096});syntax.push({path:p,actualExit:r.status,actualSignal:r.signal,timedOut:r.error?.code==='ETIMEDOUT'});assert.equal(r.status,0);}
const exportsExpected={'failure-path.cjs':['observeJob','createClosure','cancelContract'],'event-writer.cjs':['createEventWriter','finalizeObserved'],'reasons.cjs':['waitReason','reasonRow']};
for(const[file,names]of Object.entries(exportsExpected)){const mod=require('/observationfix/'+file);for(const name of names)assert.equal(typeof mod[name],'function');}
const pins=[...paths,'/newlab/controller.ts'].map(p=>({path:p,sha256:crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')}));
fs.writeFileSync('/control/observation-imports.json',JSON.stringify({node:process.versions.node,syntax,imports:exportsExpected,pins,status:'PASS_SYNTAX_IMPORT_ONLY',sourceCalls:0}),{flag:'wx'});
