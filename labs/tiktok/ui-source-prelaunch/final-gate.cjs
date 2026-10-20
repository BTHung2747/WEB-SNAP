'use strict';
// Source adapter over the accepted event validator. No network or native spawn.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {validateRecords}=require('../ui-final-fixture/final-gate.cjs');
const {phaseAccounting}=require('../ui-source-glue/policy.cjs');
const {binding}=require('../ui-source-glue/contract.cjs');
function validateSourceProof(c,p,{offlineTestOnly=false}={}){
 assert.equal(c.mode,offlineTestOnly?'OFFLINE_TEST_ONLY':'UI_SINGLE_PHOTO_SOURCE');
 assert.equal(p.nativeProof.mode,offlineTestOnly?'OFFLINE_TEST_ONLY':'OWNER_NATIVE_PROOF');
 for(const role of ['app','gateway','proxy']){const n=p.nativeProof[role];assert.equal(n.actualExit,0);assert.equal(n.actualSignal,null);assert.equal(n.oomKilled,false);}
 assert.equal(p.apiExit.apiStopRequested,true);assert.ok([0,143].includes(p.apiExit.apiActualExit));
 assert.equal(p.result.status,'PASS_UI_BACKEND_SOURCE');assert.equal(p.gateway.status,'PASS_GATEWAY_SOURCE');
 assert.ok(p.file.size>0&&p.file.size<=16*1024*1024&&p.file.magicJPEG);assert.match(p.file.sha256,/^[a-f0-9]{64}$/);
 assert.equal(p.native.prepare.coreExit,0);assert.equal(p.native.prepare.fileExists,true);assert.equal(p.native.prepare.sha256,p.file.sha256);assert.equal(p.native.analyze.coreExit,0);
 for(const phase of ['analyze','prepare']){
  assert.ok(p.worker.some(r=>r.event==='adapter_parent_closed'&&r.phase===phase&&r.actualExit===0&&r.actualSignal===null&&r.groupLive===0));
  assert.ok(p.worker.some(r=>r.event==='proxy_phase_gate'&&r.phase===phase&&r.accepted===true));
 }
 const account=phaseAccounting(p.analyze,p.prepare);assert.deepEqual(p.account,account);assert.deepEqual(p.gateway.sourceAccounting,account);assert.deepEqual(p.result.sourceAccounting,account);
 for(const [name,count] of [['FFPROBE',2],['DECODE',1]])assert.equal(p.prepare.operations.filter(r=>r.operation===name&&r.event==='END'&&r.returncode===0).length,count);
 assert.equal(p.result.selectedIndex,c.selectedIndex);assert.equal(p.selection.selectedIndex,c.selectedIndex);assert.equal(p.selection.expectedPostID,c.expectedPostID);
 for(const k of ['mode','runID','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256']){const actual=k==='mode'?c.mode:p.selection[k];assert.equal(actual,c[k]);}
 assert.equal(p.result.size,p.file.size);assert.equal(p.result.sha256,p.file.sha256);assert.equal(p.gateway.size,p.file.size);assert.equal(p.gateway.sha256,p.file.sha256);
 const closure=p.cleanup;for(const k of ['cleanupOK','closureOK','listenerClosed','secretsCleared'])assert.equal(closure[k],true);assert.equal(closure.incomingSockets+closure.outgoingSockets+closure.outgoingRequests,0);assert.equal(closure.cancel.status,201);assert.equal(closure.cancel.bodyValid,true);
 assert.deepEqual(closure.eventWriter,p.gateway.eventWriter);
 const coverage=validateRecords(p.events,p.gateway.eventWriter,p.file);
 assert.equal(p.headBefore.count,p.headAfter.count);assert.equal(p.headAfter.headLeaseUnchanged,true);
 const closed=p.controller.filter(r=>r.event==='CLEANUP_COMPLETE');assert.equal(closed.length,1);assert.ok(closed[0].cleanupOK&&closed[0].hadJob);assert.equal(closed[0].consumerExit,0);assert.equal(closed[0].consumerSignal,null);assert.deepEqual(closed[0].errors,[]);assert.equal(closed[0].outcomes.length,5);assert.ok(closed[0].outcomes.every(r=>r.outcome==='SETTLED_OK'));
 assert.equal(p.controller.filter(r=>r.event==='BROWSER_SELECTION_CONFIRMED'&&r.index===c.selectedIndex).length,1);
 assert.equal(p.proxy.mode,'source');assert.equal(p.proxy.listenerClosed,true);assert.equal(p.proxy.serveThreadClosed,true);assert.equal(p.proxy.serveFailed,false);assert.equal(p.proxy.completedConnectionCount,p.completions.length);
 assert.ok(p.completions.length>=1&&p.completions.length<=5);
 assert.deepEqual([...new Set(p.completions.map(r=>r.phase))].sort(),['analyze','prepare']);
 for(const r of p.completions){for(const k of ['accepted','diagnosticComplete','threadClosed','clientClosed','loopClosed'])assert.equal(r[k],true);assert.equal(r.traceIncomplete,false);assert.deepEqual(r.reasonCodes,[]);assert.equal(r.dns.nativeExit,0);assert.equal(r.dns.groupsLeft,0);assert.equal(r.dns.reaped,true);assert.equal(r.dns.pipesClosed,true);}
 return {status:offlineTestOnly?'PASS_UNIT_VECTOR_ONLY':'PASS_SOURCE_RUNTIME_GATES_PENDING_OWNER_CLEANUP',coverage,sourceAccounting:account,size:p.file.size,sha256:p.file.sha256,selectedIndex:c.selectedIndex,expectedPostID:c.expectedPostID,browserSave:'UNKNOWN',ownerCleanup:'PENDING',decodeProof:'PINNED_CORE_OPERATIONS_BOUND_BY_NATIVE_SHA'};
}
function main(root,ownerProofPath){
 const read=(n,cap=1048576)=>{const f=path.join(root,n),s=fs.statSync(f);assert.ok(s.isFile()&&s.size<=cap);return fs.readFileSync(f,'utf8').replace(/^\uFEFF/,'');};
 const json=n=>JSON.parse(read(n)),jsonl=n=>read(n).trim().split('\n').map(JSON.parse),c=json('browser-contract.json');
 const proof=path.resolve(ownerProofPath),control=path.resolve(root);assert.ok(!proof.startsWith(control+path.sep));assert.ok(fs.statSync(proof).size<=16384);
 const nativeProof=JSON.parse(fs.readFileSync(proof,'utf8').replace(/^\uFEFF/,''));assert.deepEqual(nativeProof.binding,binding(c));
 const imagePath=path.join(root,'native-image.jpg'),stat=fs.statSync(imagePath);assert.ok(stat.isFile()&&stat.size>0&&stat.size<=16*1024*1024);const bytes=fs.readFileSync(imagePath);
 const p={nativeProof,apiExit:json('api-exit.json'),result:json('result.json'),gateway:json('gateway-result.json'),cleanup:json('gateway-cleanup.json'),file:{size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),magicJPEG:bytes[0]===255&&bytes[1]===216},native:{analyze:json('cases/source/analyze.native.json'),prepare:json('cases/source/prepare.native.json')},analyze:json('cases/source/analyze.diagnostics.json'),prepare:json('cases/source/prepare.diagnostics.json'),account:json('source-accounting.json'),selection:json('source-selection.json'),worker:jsonl('worker.jsonl'),controller:jsonl('controller.jsonl'),events:jsonl('gateway-events.jsonl'),headBefore:json('head-before-ack.json'),headAfter:json('head-after-ack.json'),proxy:json('proxy-result.json'),completions:jsonl('completions.jsonl')};
 const result=validateSourceProof(c,p);fs.writeFileSync(path.join(root,'source-final-gate.json'),JSON.stringify(result),{flag:'wx'});console.log('{"status":"PASS_SOURCE_RUNTIME_GATES_PENDING_OWNER_CLEANUP"}');
}
module.exports={validateSourceProof};
if(require.main===module){try{main(process.argv[2],process.argv[3]);}catch{console.log('{"status":"FAIL_SOURCE_RUNTIME_GATES"}');process.exitCode=1;}}
