'use strict';
// Two reviewed findings only; no HTTP, service, DB or live authority.
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path');
const fsSync=require('node:fs');
const {EventEmitter,getEventListeners}=require('node:events');
const api=require('./contract.cjs'),p=require('./policy.cjs');
const {createEventWriter}=require('../ui-observation-fix/event-writer.cjs');
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),rows=[];
const ev=path.resolve(process.argv[2]),base=path.resolve('docs/evidence');
assert.ok(ev.startsWith(base+path.sep)&&path.relative(base,ev).split(path.sep)[0].startsWith('ui-source-glue-'));
const out=path.join(ev,process.argv[3]||'guard-tests.json');assert.equal(path.dirname(out),ev);
const stages=['job','consumer','queue','redis','db'],options={offline:true};
const ID='7000000000000000007',job='10000000-0000-4000-8000-000000000001',item='20000000-0000-4000-8000-000000000002';
async function test(name,fn){const result=await fn();rows.push({case:name,status:'PASS',...result});}
function makeWindow(ms=200){
 const now=process.hrtime.bigint(),budget=Buffer.from(JSON.stringify(api.BUDGET));
 const c={schema:'wed-ui-photo-source-contract-v1',mode:'OFFLINE_TEST_ONLY',runID:'OFFLINE_TEST_ONLY_GUARD_FIX',origin:api.ORIGIN,path:'/',approvedURL:'https://www.tiktok.com/@offline_vector/photo/'+ID,expectedPostID:ID,selectedIndex:2,decisionSHA256:'',budgetSHA256:api.hash(budget),startMonoNs:String(now-1000000n),observationDeadlineMonoNs:String(now+100000000000n),cleanupDeadlineMonoNs:String(now+120000000000n),runDeadlineMonoNs:String(now+121000000000n)};
 const d={schema:'wed-ui-photo-source-decision-v1',mode:c.mode,state:'OFFLINE_TEST_ONLY',runID:c.runID,approvedURL:c.approvedURL,expectedPostID:ID,selectedIndex:2,budgetSHA256:c.budgetSHA256,expiresAt:new Date(Date.now()+21000+ms).toISOString()};
 const raw=Buffer.from(JSON.stringify(d));c.decisionSHA256=api.hash(raw);
 const checked=api.validateInputs(c,raw,budget,undefined,{offline:true,checkOwnerClock:false});
 const snapshotKey='a'.repeat(64),format={index:2,id:'ttp1_02_'+snapshotKey,contentId:ID,itemKey:'2'.repeat(64),snapshotKey};
 const selection=p.createSelectionGuard(checked,{checkedPhotoFormats:f=>f},options);
 const locked=selection.selectable({id:job,state:'selectable',items:[{id:item,kind:'photo',formats:[format]}]});
 return {c:checked,selection,published:p.publishedGuard(checked,p.selectionRecord(checked,locked),options),body:{itemId:item,formatId:format.id,idempotencyKey:'30000000-0000-4000-8000-000000000003'}};
}
async function expire(c){const left=api.remainingSeconds(c);await sleep(Math.max(0,Math.ceil(left*1000))+20);assert.ok(api.remainingSeconds(c)<0);}
async function main(){
 const temp=await fs.mkdtemp(path.join(ev,'OFFLINE_TEST_ONLY-'));
 let result;
 try{
  for(const hanging of ['job','consumer','queue','db'])await test('CLEANUP_HANG_'+hanging.toUpperCase(),async()=>{
   const visited=[],ops=Object.fromEntries(stages.map(stage=>[stage,()=>{visited.push(stage);if(stage===hanging)return new Promise(()=>{});}]));
   const r=await p.closePassive(ops,{limitMs:100});assert.deepEqual(visited,stages);assert.equal(r.cleanupOK,false);
   const stage=r.outcomes.find(s=>s.stage===hanging);assert.equal(stage.outcome,'TIMEOUT_UNKNOWN');assert.equal(stage.operationCancelled,'UNKNOWN');assert.ok(r.elapsedMs<200);
   const writer=createEventWriter(path.join(temp,hanging+'.jsonl'));writer.enqueue({event:'OFFLINE_TEST_ONLY'});
   assert.equal((await p.finalizeSource({status:'PASS_GATEWAY_SOURCE'},r,writer)).status,'FAIL_FINAL_GUARDS');
   return {visited,elapsedMs:r.elapsedMs,limitMs:r.limitMs,timeoutOutcome:stage.outcome,operationCancelled:stage.operationCancelled};
  });
  await test('CLEANUP_ALL_SETTLED_OK',async()=>{const visited=[],r=await p.closePassive(Object.fromEntries(stages.map(s=>[s,()=>visited.push(s)])),{limitMs:100});assert.deepEqual(visited,stages);assert.equal(r.cleanupOK,true);assert.ok(r.outcomes.every(o=>o.outcome==='SETTLED_OK'&&o.ownedWatchdogCleared));return {elapsedMs:r.elapsedMs};});
  await test('CLEANUP_EXHAUSTED_NO_OPERATION_STARTED',async()=>{let n=0;const r=await p.closePassive(Object.fromEntries(stages.map(s=>[s,()=>n++])),{limitMs:0});assert.equal(n,0);assert.equal(r.cleanupOK,false);assert.ok(r.outcomes.every(o=>o.outcome==='NOT_STARTED_UNKNOWN'&&!o.attempted));});
  await test('CLEANUP_REJECT_INDEPENDENCE',async()=>{const visited=[],r=await p.closePassive(Object.fromEntries(stages.map(s=>[s,()=>{visited.push(s);throw Error('OFFLINE_TEST_ONLY');}])),{limitMs:100});assert.deepEqual(visited,stages);assert.equal(r.errors.length,5);assert.equal(r.cleanupOK,false);});
  await test('CLEANUP_LATE_REJECTION_OBSERVED_NOT_UPGRADED',async()=>{const visited=[];let rejected=false;const ops=Object.fromEntries(stages.map(s=>[s,()=>{visited.push(s);} ]));ops.queue=()=>{visited.push('queue');return new Promise((_,reject)=>setTimeout(()=>{rejected=true;reject(Error('OFFLINE_TEST_ONLY'));},80));};
   const r=await p.closePassive(ops,{limitMs:100});assert.deepEqual(visited,stages);assert.equal(r.cleanupOK,false);assert.equal(r.outcomes.find(o=>o.stage==='queue').outcome,'TIMEOUT_UNKNOWN');await sleep(100);assert.equal(rejected,true);assert.equal(r.cleanupOK,false);});
  await test('CLEANUP_ABORTABLE_DELAY_OWN_TIMERS_LISTENERS_CLEARED',async()=>{const before=process.getActiveResourcesInfo().filter(t=>t==='Timeout').length;let signal;const ops=Object.fromEntries(stages.map(s=>[s,()=>{}]));ops.job=async ctx=>{signal=ctx.signal;await ctx.sleep(10000);};const r=await p.closePassive(ops,{limitMs:100});await new Promise(setImmediate);assert.equal(r.cleanupOK,false);assert.equal(getEventListeners(signal,'abort').length,0);assert.ok(process.getActiveResourcesInfo().filter(t=>t==='Timeout').length<=before);assert.ok(r.outcomes.every(o=>o.ownedWatchdogCleared));});
  for(const graceful of [true,false])await test('CONSUMER_'+(graceful?'CLOSE':'TIMEOUT_DETACH_UNKNOWN'),async()=>{
   const child=new EventEmitter();child.exitCode=null;child.signalCode=null;const kills=[];let signal;
   child.kill=s=>{kills.push(s);if(graceful&&s==='SIGTERM')queueMicrotask(()=>{child.exitCode=0;child.emit('close',0,null);});return true;};
   const ops=Object.fromEntries(stages.map(s=>[s,()=>{}]));ops.consumer=ctx=>{signal=ctx.signal;return p.stopConsumer(child,ctx);};
   const r=await p.closePassive(ops,{limitMs:100});assert.equal(r.cleanupOK,graceful);assert.equal(child.listenerCount('close'),0);assert.equal(getEventListeners(signal,'abort').length,0);assert.deepEqual(kills,graceful?['SIGTERM']:['SIGTERM','SIGKILL']);
   if(!graceful)assert.equal(r.outcomes.find(o=>o.stage==='consumer').operationCancelled,'UNKNOWN');return {kills,cleanupOK:r.cleanupOK};
  });
  await test('CLEANUP_CAP_NOT_EXPANDED',async()=>{let n=0;await assert.rejects(()=>p.closePassive({job:()=>n++},{limitMs:15001}));assert.equal(n,0);});
  await test('VALID_BEFORE_EXPIRY_BOTH_GUARDS_AND_WORKFLOW',async()=>{const x=makeWindow(500);let n=0;x.selection.prepare(job,x.body,()=>++n);x.published.prepare(job,x.body,()=>++n);p.forwardWorkflow(x.c,'ANALYZE',()=>++n,options);p.forwardWorkflow(x.c,'PREPARE',()=>++n,options);assert.equal(n,4);});
  await test('CONSTRUCT_VALID_EXPIRE_BOTH_PREPARE_CALLBACKS_ZERO',async()=>{const x=makeWindow();assert.ok(api.remainingSeconds(x.c)>0);await expire(x.c);let a=0,b=0;assert.throws(()=>x.selection.prepare(job,x.body,()=>++a));assert.throws(()=>x.published.prepare(job,x.body,()=>++b));assert.equal(a,0);assert.equal(b,0);return {remainingSeconds:api.remainingSeconds(x.c),selectionCallbacks:a,publishedCallbacks:b};});
  await test('AWAIT_FILE_IO_THEN_EXPIRE_BEFORE_REAL_CREATION_ZERO',async()=>{const x=makeWindow();x.published.prepare(job,x.body,()=>{});await fs.writeFile(path.join(temp,'selection.json'),JSON.stringify({itemId:item,formatId:x.body.formatId}),{flag:'wx'});await expire(x.c);let n=0;const create=()=>p.forwardWorkflow(x.c,'PREPARE',()=>++n,options);assert.throws(()=>x.published.prepare(job,x.body,create));assert.equal(n,0);});
  await test('ANALYZE_FINAL_CREATE_GUARD_AFTER_AWAIT_ZERO',async()=>{const x=makeWindow();api.assertValidated(x.c,options);await fs.writeFile(path.join(temp,'analyze.json'),'OFFLINE_TEST_ONLY',{flag:'wx'});await expire(x.c);let n=0;assert.throws(()=>p.forwardWorkflow(x.c,'ANALYZE',()=>++n,options));assert.equal(n,0);});
  await test('WRONG_BODY_BINDING_ZERO',async()=>{const x=makeWindow(500);let n=0;assert.throws(()=>x.published.prepare(job,{...x.body,itemId:job},()=>++n));assert.throws(()=>x.selection.prepare(item,x.body,()=>++n));assert.equal(n,0);});
  await test('OFFLINE_VECTOR_NEVER_SOURCE_MODE',async()=>{const x=makeWindow(500);let n=0;assert.throws(()=>p.forwardWorkflow(x.c,'ANALYZE',()=>++n));assert.throws(()=>p.forwardWorkflow(x.c,'PREPARE',()=>++n));assert.equal(n,0);});
  await test('CANCEL_CLEANUP_AFTER_OBSERVATION_CUTOFF_ALLOWED',async()=>{const x=makeWindow();await expire(x.c);let n=0;p.forwardWorkflow(x.c,'CANCEL',()=>++n);p.forwardWorkflow(x.c,'RELEASE',()=>++n);assert.equal(n,2);const r=await p.closePassive(Object.fromEntries(stages.map(s=>[s,()=>{}])),{limitMs:100});assert.equal(r.cleanupOK,true);});
  const source=await fs.readFile(path.join(__dirname,'gateway.cjs'),'utf8');assert.ok(source.includes('const createUpstream=()=>forwardWorkflow(contract,kind,()=>closure.trackRequest(http.request('));
  assert.ok(source.includes("await write('browser-selection.json'"));assert.ok(source.includes('prepareGuard.prepare(jobID,prepareBody,createUpstream)'));
  result={status:'PASS_GUARD_FIX_OFFLINE_DELTA',runtime:process.versions.node,caseCount:rows.length,cases:rows,libraryClosures:'NOT_RUN_SPIES_ONLY',sourceCalls:0,claims:0,utc:new Date().toISOString()};
 }finally{assert.equal(fsSync.realpathSync(temp),path.resolve(temp));assert.equal(path.dirname(temp),ev);fsSync.rmSync(temp,{recursive:true});}
 await fs.writeFile(out,JSON.stringify({...result,ownTempRemoved:true},null,2),{flag:'wx'});
 console.log(JSON.stringify({status:'PASS_GUARD_FIX_OFFLINE_DELTA',cases:rows.length}));
}
main().catch(()=>{console.error('GUARD_FIX_TEST_FAILED');process.exitCode=1;});
