'use strict';
// Delta units only. No listener, database, browser, child workflow or HTTP.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {stripTypeScriptTypes}=require('node:module');
const api=require('./contract.cjs'),policy=require('./policy.cjs');
const {createEventWriter}=require('../ui-observation-fix/event-writer.cjs');
const ev=path.resolve(process.argv[2]),evidence=path.resolve('docs/evidence');
assert.ok(ev.startsWith(evidence+path.sep));assert.ok(path.relative(evidence,ev).split(path.sep)[0].startsWith('ui-source-glue-'));assert.equal(fs.realpathSync(ev),ev);
const receipt=path.join(ev,process.argv[3]||'node-tests.json');assert.equal(path.dirname(receipt),ev);assert.ok(!fs.existsSync(receipt));
const temp=fs.mkdtempSync(path.join(ev,'OFFLINE_TEST_ONLY-'));const rows=[];
const options={offline:true},ID='7000000000000000007',job='10000000-0000-4000-8000-000000000001',item='20000000-0000-4000-8000-000000000002',idem='30000000-0000-4000-8000-000000000003';
function inputs(){
 const now=process.hrtime.bigint(),budget=Buffer.from(JSON.stringify(api.BUDGET));
 const c={schema:'wed-ui-photo-source-contract-v1',mode:'OFFLINE_TEST_ONLY',runID:'OFFLINE_TEST_ONLY_VECTOR',origin:api.ORIGIN,path:'/',approvedURL:'https://www.tiktok.com/@offline_vector/photo/'+ID,expectedPostID:ID,selectedIndex:2,decisionSHA256:'',budgetSHA256:api.hash(budget),startMonoNs:String(now-1000000n),observationDeadlineMonoNs:String(now+100000000000n),cleanupDeadlineMonoNs:String(now+120000000000n),runDeadlineMonoNs:String(now+121000000000n)};
 const d={schema:'wed-ui-photo-source-decision-v1',mode:c.mode,state:'OFFLINE_TEST_ONLY',runID:c.runID,approvedURL:c.approvedURL,expectedPostID:ID,selectedIndex:2,budgetSHA256:c.budgetSHA256,expiresAt:'2099-01-01T00:00:00Z'};
 const decision=Buffer.from(JSON.stringify(d));c.decisionSHA256=api.hash(decision);return {c,d,budget,decision};
}
// Deliberate public-API spies: no local replacement of the app's photo schema.
// Actual Zod/Prisma imports are unavailable on this host and are NOT_RUN.
const calls=[];const photos={photoPostId(url){calls.push('photoPostId');return url.endsWith('/'+ID)?ID:null;},checkedPhotoFormats(f,expected){calls.push(['checkedPhotoFormats',expected]);return f;},selectedPhoto(items,id,expected){calls.push(['selectedPhoto',expected]);return items[0].formats.find(f=>f.id===id);}};
const validated=()=>{const x=inputs();return api.validateInputs(x.c,x.decision,x.budget,photos,options);};
function formats(snapshot='a'.repeat(64)){return [1,2,3].map(index=>({index,id:`ttp1_${String(index).padStart(2,'0')}_${snapshot}`,contentId:ID,itemKey:String(index).repeat(64),snapshotKey:snapshot}));}
function publicJob(f=formats()){return {id:job,state:'selectable',items:[{id:item,kind:'photo',formats:f}]};}
function setup(){const c=validated(),guard=policy.createSelectionGuard(c,photos,options),selection=guard.selectable(publicJob());return {c,guard,selection,body:{itemId:item,formatId:selection.formatId,idempotencyKey:idem}};}
async function test(name,fn){await fn();rows.push({case:name,status:'PASS'});}
async function main(){try{
 await test('OFFLINE_INPUT_BOUND_HASH_AND_PUBLIC_URL_DELEGATE',()=>{assert.equal(validated().mode,'OFFLINE_TEST_ONLY');assert.ok(calls.includes('photoPostId'));});
 await test('FOREIGN_CLOCK_UTC_WINDOW_CLAMPS_DURATIONS_ONLY',()=>{const x=inputs(),now=Date.now(),mono=1000000000n;const w=api.calculateRuntimeWindow(x.c,new Date(now+121000).toISOString(),{wallNow:now,monoNow:mono});assert.equal(w.run-mono,121000000000n);assert.equal(w.observation-mono,100000000000n);assert.equal(w.cleanup-mono,120000000000n);assert.throws(()=>api.calculateRuntimeWindow(x.c,new Date(now+20000).toISOString(),{wallNow:now,monoNow:mono}));assert.throws(()=>api.calculateRuntimeWindow(x.c,new Date(now+481000).toISOString(),{wallNow:now,monoNow:mono}));});
 await test('FOREIGN_INPUT_PATH_REMAINS_OFFLINE_CAPABILITY',async()=>{const x=inputs();x.d.expiresAt=new Date(Date.now()+121000).toISOString();x.decision=Buffer.from(JSON.stringify(x.d));x.c.decisionSHA256=api.hash(x.decision);const c=api.validateInputs(x.c,x.decision,x.budget,photos,{offline:true,checkOwnerClock:false});assert.ok(api.remainingSeconds(c)>0&&api.remainingSeconds(c)<=100);await assert.rejects(()=>policy.startPassive(c,{seed:()=>{throw Error('MUST_NOT_START');}}));});
 for(const [name,change] of [
  ['FIXTURE_SCOPE',x=>{x.c.mode='COMBINED_FIXTURE_SOURCE_OFF';}],
  ['CONSUMED_AUTHORITY',x=>{x.d.state='CONSUMED';x.decision=Buffer.from(JSON.stringify(x.d));x.c.decisionSHA256=api.hash(x.decision);}],
  ['OLD_AUTHORITY_RUN',x=>{x.d.runID='OLD_CONSUMED_RUN';x.decision=Buffer.from(JSON.stringify(x.d));x.c.decisionSHA256=api.hash(x.decision);}],
  ['WRONG_DECISION_HASH',x=>{x.c.decisionSHA256='0'.repeat(64);}],
  ['WRONG_BUDGET_HASH',x=>{x.c.budgetSHA256='0'.repeat(64);}],
  ['EXPIRED_AUTHORITY',x=>{x.d.expiresAt='2000-01-01T00:00:00Z';x.decision=Buffer.from(JSON.stringify(x.d));x.c.decisionSHA256=api.hash(x.decision);}],
  ['MISSING_INDEX',x=>{delete x.c.selectedIndex;}],
  ['SHORT_CLEANUP_RESERVE',x=>{x.c.cleanupDeadlineMonoNs=String(BigInt(x.c.observationDeadlineMonoNs)+1n);}],
  ['DEADLINE_EXHAUSTED',x=>{x.c.startMonoNs='1';x.c.observationDeadlineMonoNs='2';x.c.cleanupDeadlineMonoNs='20000000002';x.c.runDeadlineMonoNs='21000000002';}],
  ['OVERCAP_POLICY',x=>{const b={...api.BUDGET,readSeconds:21};x.budget=Buffer.from(JSON.stringify(b));x.c.budgetSHA256=api.hash(x.budget);x.d.budgetSHA256=x.c.budgetSHA256;x.decision=Buffer.from(JSON.stringify(x.d));x.c.decisionSHA256=api.hash(x.decision);}]
 ])await test('REJECT_'+name,()=>{const x=inputs();change(x);assert.throws(()=>api.validateInputs(x.c,x.decision,x.budget,photos,options));});
 await test('PASSIVE_ONLY_SEED_CONSUMER_READY',async()=>{const seq=[];const r=await policy.startPassive(validated(),{seed:()=>seq.push('seed'),startConsumer:()=>seq.push('consumer'),ready:()=>seq.push('ready')},options);assert.deepEqual(seq,['seed','consumer','ready']);assert.equal(r.workflowAPICalls,0);});
 await test('CLEANUP_INDEPENDENT_AFTER_JOB_OR_CONSUMER_FAILURE',async()=>{for(const failing of ['job','consumer']){const seq=[],ops={};for(const k of ['job','consumer','queue','redis','db'])ops[k]=async()=>{seq.push(k);if(k===failing)throw Error();};const result=await policy.closePassive(ops);assert.deepEqual(seq,['job','consumer','queue','redis','db']);assert.equal(result.cleanupOK,false);assert.deepEqual(result.errors,[failing.toUpperCase()+'_CLOSE_UNKNOWN']);}});
 await test('MISSING_AUTHORITY_ZERO_SIDE_EFFECTS',async()=>{let n=0;await assert.rejects(()=>policy.startPassive({}, {seed:()=>n++,startConsumer:()=>n++,ready:()=>n++},options));assert.equal(n,0);});
 await test('OFFLINE_VECTOR_CANNOT_ACTIVATE_SOURCE',async()=>{let n=0;await assert.rejects(()=>policy.startPassive(validated(),{seed:()=>n++}));assert.equal(n,0);await assert.rejects(()=>api.runtimeContract(undefined,{STEP5_EXECUTE_SOURCE:'1',STEP5_OFFLINE_TEST:'1'}));});
 await test('SELECT_GUARD_PUBLIC_API_AND_VALID_FORWARD',()=>{const x=setup();let count=0;assert.equal(x.guard.prepare(job,x.body,()=>++count),1);assert.equal(count,1);assert.equal(x.guard.verify(publicJob().items,x.body.formatId).index,2);assert.ok(calls.some(r=>Array.isArray(r)&&r[0]==='checkedPhotoFormats'&&r[1]===ID));assert.ok(calls.some(r=>Array.isArray(r)&&r[0]==='selectedPhoto'&&r[1]===ID));});
 for(const [name,change] of [
  ['WRONG_INDEX',b=>{b.formatId=formats()[0].id;}],['WRONG_ITEM',b=>{b.itemId=idem;}],['WRONG_FORMAT',b=>{b.formatId='ttp1_02_'+'f'.repeat(64);}],['EXTRA_BODY_FIELD',b=>{b.url='OFFLINE_TEST_ONLY';}],['MISSING_IDEMPOTENCY',b=>{delete b.idempotencyKey;}]
 ])await test('PRE_FORWARD_REJECT_'+name,()=>{const x=setup();change(x.body);let count=0;assert.throws(()=>x.guard.prepare(job,x.body,()=>++count));const p=policy.publishedGuard(x.c,policy.selectionRecord(x.c,x.selection),options);assert.throws(()=>p.prepare(job,x.body,()=>++count));assert.equal(count,0);});
 await test('WRONG_BODY_ID_REJECT',()=>{const c=validated(),g=policy.createSelectionGuard(c,photos,options),f=formats();f[1].contentId='7000000000000000008';assert.throws(()=>g.selectable(publicJob(f)));});
 await test('CHANGED_SNAPSHOT_REJECT',()=>{const x=setup();assert.throws(()=>x.guard.selectable(publicJob(formats('b'.repeat(64)))));assert.throws(()=>x.guard.verify(publicJob(formats('b'.repeat(64))).items,formats('b'.repeat(64))[1].id));});
 await test('APPROVED_INDEX_MISSING_REJECT',()=>{const c=validated(),g=policy.createSelectionGuard(c,photos,options);assert.throws(()=>g.selectable(publicJob([formats()[0]])));});
 for(const key of ['runID','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256'])await test('PUBLISHED_BINDING_REJECT_'+key,()=>{const x=setup(),p=policy.selectionRecord(x.c,x.selection);p[key]=key==='selectedIndex'?3:'OFFLINE_WRONG';let n=0;assert.throws(()=>policy.publishedGuard(x.c,p,options).prepare(job,x.body,()=>n++));assert.equal(n,0);});
 await test('PUBLISHED_IMMUTABLE_AND_WRONG_JOB',()=>{const x=setup(),p=policy.selectionRecord(x.c,x.selection),g=policy.publishedGuard(x.c,p,options);p.itemId=idem;let n=0;assert.throws(()=>g.prepare(item,x.body,()=>++n));g.prepare(job,x.body,()=>++n);assert.equal(n,1);});
 await test('PREPARE_BEFORE_SELECTABLE_REJECT',()=>{const c=validated(),g=policy.createSelectionGuard(c,photos,options);let n=0;assert.throws(()=>g.prepare(job,{itemId:item,formatId:'',idempotencyKey:idem},()=>n++));assert.equal(n,0);});
 const phase=(phase,n)=>({phase,complete:true,metadataAttempts:n,imageAttempts:phase==='prepare'?1:0,attempts:n+(phase==='prepare'?1:0),observedResponses:n+(phase==='prepare'?1:0)});
 await test('ACCOUNT_ACTUAL_ONE_OR_TWO_AND_WIRE_UNKNOWN',()=>{assert.equal(policy.phaseAccounting(phase('analyze',1),phase('prepare',1)).attempts,3);const r=policy.phaseAccounting(phase('analyze',2),phase('prepare',2));assert.equal(r.attempts,5);assert.equal(r.wireGET,'UNKNOWN');});
 await test('ACCOUNT_CONTRADICTION_AND_OVERCAP_REJECT',()=>{assert.throws(()=>policy.phaseAccounting(phase('analyze',3),phase('prepare',1)));const d=phase('prepare',2);d.observedResponses=2;assert.throws(()=>policy.phaseAccounting(phase('analyze',1),d));});
 await test('NATIVE_RECEIPT_ONE_GET_BOUND_TO_CORE',()=>{const e={size:1234,sha256:'a'.repeat(64)},r={...e,method:'GET',status:200};assert.deepEqual(policy.checkedBrowserTransfer([r],e),r);});
 for(const [name,change] of [['MISSING',r=>[]],['DUPLICATE',r=>[r,r]],['HEAD',r=>[{...r,method:'HEAD'}]],['WRONG_HASH',r=>[{...r,sha256:'b'.repeat(64)}]],['WRONG_SIZE',r=>[{...r,size:1233}]]])await test('NATIVE_RECEIPT_REJECT_'+name,()=>{const e={size:1234,sha256:'a'.repeat(64)},r={...e,method:'GET',status:200};assert.throws(()=>policy.checkedBrowserTransfer(change(r),e));});
 await test('SOURCE_FINAL_STATUS_CLEANUP_AND_WRITER',async()=>{const writer=createEventWriter(path.join(temp,'events.jsonl'));writer.enqueue({event:'OFFLINE_TEST_ONLY'});const ok=await policy.finalizeSource({status:'PASS_GATEWAY_SOURCE'},{cleanupOK:true},writer);assert.equal(ok.status,'PASS_GATEWAY_SOURCE');assert.equal(ok.eventWriter.complete,true);const fail=await policy.finalizeSource({status:'PASS_GATEWAY_SOURCE'},{cleanupOK:false},createEventWriter(path.join(temp,'none.jsonl')));assert.equal(fail.status,'FAIL_FINAL_GUARDS');const broken={seal:async()=>{throw Error();},snapshot:()=>({complete:false})};assert.equal((await policy.finalizeSource({status:'PASS_GATEWAY_SOURCE'},{cleanupOK:true},broken)).status,'FAIL_FINAL_GUARDS');});
 await test('GATEWAY_IMPORT_AND_MISSING_AUTHORITY_NO_START',async()=>{const {runSourceGateway}=require('./gateway.cjs');await assert.rejects(()=>runSourceGateway());});
 await test('CONTROLLER_TYPESCRIPT_PARSE_IMPORT_DENY_BEFORE_DB',async()=>{
  const source=fs.readFileSync(path.join(__dirname,'controller.ts'),'utf8');let dynamicImports=0;
  const m=new vm.SourceTextModule(stripTypeScriptTypes(source),{importModuleDynamically:()=>{dynamicImports++;throw Error('UNEXPECTED_IMPORT');}});
  await m.link(async spec=>{const loaded=spec.startsWith('node:')?require(spec):require(path.resolve(__dirname,spec));const names=[...new Set(['default',...Object.keys(loaded)])];const dep=new vm.SyntheticModule(names,function(){for(const n of names)this.setExport(n,n==='default'?loaded:loaded[n]);});return dep;});
  await m.evaluate();await assert.rejects(()=>m.namespace.runSourceController());assert.equal(dynamicImports,0);
 });
 await test('START_ENTRY_AUTH_BEFORE_PRISMA_NO_DRIVER_LF_ONLY',()=>{const s=fs.readFileSync(path.join(__dirname,'start.sh'),'utf8');assert.ok(!s.includes('\r'));assert.ok(s.indexOf('runtimeContract()')<s.indexOf('node_modules/.bin/prisma'));assert.ok(!/driver\.ts|workflow\.ts|\/offline|sitecustomize/.test(s));});
 const result={status:'PASS_OFFLINE_SOURCE_GLUE_UNITS',runtime:process.versions.node,cases:rows,caseCount:rows.length,publicPhotoSchemaExecution:'NOT_RUN_PUBLIC_API_SPIES_ONLY',containerRuntime:'NOT_RUN',sourceCalls:0,claimsCreated:0,utc:new Date().toISOString()};fs.writeFileSync(receipt,JSON.stringify(result,null,2),{flag:'wx'});console.log(JSON.stringify({status:result.status,cases:rows.length}));
 }finally{assert.equal(fs.realpathSync(temp),path.resolve(temp));assert.equal(path.dirname(temp),ev);fs.rmSync(temp,{recursive:true});}}
main().catch(()=>{console.error('OFFLINE_GLUE_TEST_FAILED');process.exitCode=1;});
