'use strict';
const assert=require('node:assert/strict');
const {assertValidated}=require('./contract.cjs');
const {setTimeout:delay}=require('node:timers/promises');
function createSelectionGuard(c,photos,options){
 assertValidated(c,options);
 let locked;
 function selectable(job){
  assert.equal(job.state,'selectable');assert.ok(Array.isArray(job.items)&&job.items.length===1);
  const item=job.items[0];assert.equal(item.kind,'photo');assert.match(item.id,/^[a-f0-9-]{36}$/);
  const formats=photos.checkedPhotoFormats(item.formats,c.expectedPostID);
  const chosen=formats.find(f=>f.index===c.selectedIndex);assert.ok(chosen,'APPROVED_INDEX_MISSING');
  assert.equal(chosen.contentId,c.expectedPostID);
  const next={jobID:job.id,itemId:item.id,formatId:chosen.id,index:chosen.index,itemKey:chosen.itemKey,snapshotKey:chosen.snapshotKey};
  assert.match(next.jobID,/^[a-f0-9-]{36}$/);
  if(locked)assert.deepEqual(next,locked);else locked=Object.freeze(next);
  return locked;
 }
 function prepare(jobID,body,forward){
  assert.ok(locked,'SELECTABLE_NOT_OBSERVED');assert.equal(jobID,locked.jobID);
  assert.deepEqual(Object.keys(body).sort(),['formatId','idempotencyKey','itemId']);
  assert.match(body.idempotencyKey,/^[a-f0-9-]{36}$/);
  assert.equal(body.itemId,locked.itemId);assert.equal(body.formatId,locked.formatId);
  // This callback is the actual upstream creation, not a post-send observation.
  assertValidated(c,options);
  return forward();
 }
 function verify(items,formatId){
  assert.ok(locked);const chosen=photos.selectedPhoto(items,formatId,c.expectedPostID);
  assert.equal(chosen.index,c.selectedIndex);assert.equal(chosen.itemKey,locked.itemKey);assert.equal(chosen.snapshotKey,locked.snapshotKey);assert.equal(chosen.id,locked.formatId);
  return chosen;
 }
 return {selectable,prepare,verify,get selection(){return locked;}};
}
function phaseAccounting(analyze,prepare){
 for(const [phase,d] of [['analyze',analyze],['prepare',prepare]]){
  assert.equal(d.phase,phase);assert.equal(d.complete,true);
  assert.ok(Number.isInteger(d.metadataAttempts)&&d.metadataAttempts>=1&&d.metadataAttempts<=2);
  assert.equal(d.imageAttempts,phase==='prepare'?1:0);assert.equal(d.attempts,d.metadataAttempts+d.imageAttempts);
  assert.equal(d.observedResponses,d.attempts); // complete cannot contradict observed responses
 }
 return {metadataAttempts:analyze.metadataAttempts+prepare.metadataAttempts,imageAttempts:prepare.imageAttempts,attempts:analyze.attempts+prepare.attempts,observedResponses:analyze.observedResponses+prepare.observedResponses,wireGET:'UNKNOWN',attemptIsNotWireGET:true};
}
async function finalizeSource(primary,cleanup,writer){
 // Reuse the accepted writer; source success has its own final guards.
 try{await writer.seal();}catch{}
 const eventWriter=writer.snapshot();
 return {...primary,cleanup,eventWriter,status:primary.status==='PASS_GATEWAY_SOURCE'&&(!cleanup.cleanupOK||!eventWriter.complete)?'FAIL_FINAL_GUARDS':primary.status};
}
function selectionRecord(c,selection){
 return {...selection,runID:c.runID,expectedPostID:c.expectedPostID,selectedIndex:c.selectedIndex,decisionSHA256:c.decisionSHA256,budgetSHA256:c.budgetSHA256};
}
function publishedGuard(c,value,options){
 assertValidated(c,options);const p=Object.freeze({...value});
 for(const k of ['runID','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256'])assert.equal(p[k],c[k]);
 assert.equal(p.index,c.selectedIndex);assert.match(p.itemKey,/^[a-f0-9]{64}$/);assert.match(p.snapshotKey,/^[a-f0-9]{64}$/);
 assert.equal(p.formatId,`ttp1_${String(c.selectedIndex).padStart(2,'0')}_${p.snapshotKey}`);
 assert.match(p.jobID,/^[a-f0-9-]{36}$/);assert.match(p.itemId,/^[a-f0-9-]{36}$/);
 return {prepare(jobID,body,forward){assert.equal(jobID,p.jobID);assert.deepEqual(Object.keys(body).sort(),['formatId','idempotencyKey','itemId']);assert.match(body.idempotencyKey,/^[a-f0-9-]{36}$/);assert.equal(body.itemId,p.itemId);assert.equal(body.formatId,p.formatId);assertValidated(c,options);return forward();}};
}
async function startPassive(c,ops,options){
 assertValidated(c,options);
 await ops.seed();await ops.startConsumer();await ops.ready();
 return {mode:c.mode,workflowOwner:'FRONTEND_BROWSER',workflowAPICalls:0};
}
async function closePassive(ops,{limitMs=15000}={}){
 assert.ok(Number.isFinite(limitMs)&&limitMs>=0&&limitMs<=15000);
 const begin=performance.now(),deadline=begin+limitMs,stages=['job','consumer','queue','redis','db'],errors=[],outcomes=[];
 for(const [i,stage] of stages.entries()){
  const start=performance.now(),left=deadline-start;
  if(left<=0){errors.push(stage.toUpperCase()+'_NOT_STARTED_UNKNOWN');outcomes.push({stage,outcome:'NOT_STARTED_UNKNOWN',attempted:false,operationCancelled:'UNKNOWN'});continue;}
  // Fair slices reserve an opportunity for every independent later stage.
  const end=Math.min(deadline,start+left/(stages.length-i)),abort=new AbortController();
  let timer,attempted=false,settled=false,timedOut=false;
  const check=()=>{if(abort.signal.aborted||performance.now()>=end)throw Object.assign(new Error(),{code:'CLEANUP_STAGE_EXPIRED'});};
  const context={signal:abort.signal,check,remainingMs:()=>Math.max(0,end-performance.now()),sleep:ms=>{check();return delay(Math.min(ms,Math.max(1,end-performance.now())),undefined,{signal:abort.signal});}};
  // Both handlers stay attached after a timeout: late rejection is observed,
  // but it cannot upgrade this immutable timeout receipt into cleanup success.
  const operation=Promise.resolve().then(()=>{check();attempted=true;return ops[stage](context);}).then(
   ()=>{settled=true;return performance.now()<end?'SETTLED_OK':'TIMEOUT_UNKNOWN';},
   ()=>{settled=true;return abort.signal.aborted||performance.now()>=end?'TIMEOUT_UNKNOWN':'ERROR_UNKNOWN';});
  let outcome;
  try{
   outcome=await Promise.race([operation,new Promise(resolve=>{timer=setTimeout(()=>{timedOut=true;resolve('TIMEOUT_UNKNOWN');abort.abort();},Math.max(1,end-performance.now()));})]);
   if(timedOut)outcome='TIMEOUT_UNKNOWN';
  }finally{clearTimeout(timer);abort.abort();}
  if(outcome!=='SETTLED_OK')errors.push(stage.toUpperCase()+(outcome==='ERROR_UNKNOWN'?'_CLOSE_UNKNOWN':'_TIMEOUT_UNKNOWN'));
  outcomes.push({stage,outcome,attempted,operationSettledAtReturn:settled,operationCancelled:outcome==='SETTLED_OK'?'NOT_REQUIRED':'UNKNOWN',allowedMs:end-start,elapsedMs:performance.now()-start,ownedWatchdogCleared:true});
 }
 const elapsedMs=performance.now()-begin,deadlineExpired=performance.now()>=deadline;
 if(deadlineExpired&&!errors.length)errors.push('CLEANUP_DEADLINE');
 return {cleanupOK:errors.length===0,errors,outcomes,elapsedMs,limitMs,deadlineExpired};
}
async function stopConsumer(child,context){
 context.check();
 if(child.exitCode!==null||child.signalCode!==null)return;
 await new Promise((resolve,reject)=>{
  const detach=()=>{child.removeListener('close',closed);context.signal.removeEventListener('abort',aborted);};
  const closed=()=>{detach();resolve();};
  const aborted=()=>{detach();try{child.kill('SIGKILL');}catch{}reject(Object.assign(new Error(),{code:'CONSUMER_CLOSE_UNKNOWN'}));};
  child.once('close',closed);context.signal.addEventListener('abort',aborted,{once:true});
  try{context.check();child.kill('SIGTERM');}catch{detach();reject(Object.assign(new Error(),{code:'CONSUMER_CLOSE_UNKNOWN'}));}
 });
 context.check();
}
function forwardWorkflow(c,kind,create,options){
 if(kind==='ANALYZE'||kind==='PREPARE')assertValidated(c,options);
 return create(); // Synchronous: no await between the check and HTTP creation.
}
function checkedBrowserTransfer(rows,expected){
 assert.equal(rows.length,1);const r=rows[0];assert.equal(r.method,'GET');assert.equal(r.status,200);assert.equal(r.size,expected.size);assert.equal(r.sha256,expected.sha256);assert.match(r.sha256,/^[a-f0-9]{64}$/);return {...r};
}
module.exports={createSelectionGuard,phaseAccounting,finalizeSource,selectionRecord,publishedGuard,startPassive,closePassive,stopConsumer,forwardWorkflow,checkedBrowserTransfer};
