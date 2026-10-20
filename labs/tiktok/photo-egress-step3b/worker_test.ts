import assert from 'node:assert/strict';
import { randomBytes,randomUUID,createHash } from 'node:crypto';
import { readFile,writeFile,mkdir,access,copyFile } from 'node:fs/promises';
import { after,db,redis,queue,defaults } from '/app/packages/shared/src/core';
import { processJob } from '/app/apps/worker/src/processor';
import { ProcessGroup } from '/app/apps/worker/src/process-group';
import { liveProcesses } from '/app/apps/worker/src/process-registry';
import { sweep } from '/app/apps/worker/src/lifecycle';
const OUT='/control',URL='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const sleep=(n:number)=>new Promise(r=>setTimeout(r,n)),cases:any[]=[];
const sid=randomBytes(32).toString('hex');
const baseLimits={...defaults,enabledPlatforms:['tiktok','youtube'],analyzeTimeout:10,prepareTimeout:40,sessionTtl:180};
async function settings(extra:any={}){const value={...baseLimits,...extra};await db.settings.upsert({where:{id:'main'},create:{id:'main',value},update:{value}});}
async function mode(name:string){await writeFile(OUT+'/mode.tmp',JSON.stringify({mode:name}));const fs=await import('node:fs/promises');await fs.rename(OUT+'/mode.tmp',OUT+'/mode.json');}
async function idle(){for(let i=0;i<150;i++){try{const d=JSON.parse(await readFile(OUT+'/service.json','utf8'));if(!d.active&&!d.pending)return;}catch{}await sleep(20);}throw new Error('Fixture did not quiesce');}
async function absent(p:string){try{await access(p);return false;}catch{return true;}}
async function create(){const id=randomUUID();await db.downloadJob.create({data:{id,sessionId:sid,platform:'tiktok',sourceUrl:URL,ownerUntil:after(180)}});await mkdir(OUT+'/jobs/'+id,{recursive:true});return id;}
async function nativeMode(id:string,value:string){await writeFile(OUT+'/jobs/'+id+'/case.json',JSON.stringify({mode:value}));}
async function native(id:string){try{return (await readFile(OUT+'/jobs/'+id+'/native.jsonl','utf8')).trim().split('\n').map(s=>JSON.parse(s));}catch{return [];}}
async function run(id:string,phase:string){const start=performance.now();await processJob({name:phase,data:{id}});return performance.now()-start;}
async function row(id:string){return db.downloadJob.findUniqueOrThrow({where:{id},include:{items:true,asset:true}});}
async function prepare(id:string){const j=await row(id);assert.equal(j.state,'selectable');await db.downloadJob.update({where:{id},data:{state:'queued',formatId:(j.items[0].formats as any[])[1].id,prepareKey:randomUUID()}});}
async function analyzeHappy(){await mode('happy');const id=await create();await run(id,'analyze');const j=await row(id);assert.equal(j.state,'selectable');assert.equal(j.items[0].kind,'photo');await idle();return id;}
async function rejection(id:string,wanted='failed'){
 const j=await row(id);assert.equal(j.state,wanted);assert.equal(j.workerToken,null);assert.equal(j.processUntil,null);assert.equal(await absent('/media/'+id),true);
 assert.ok(!j.asset||j.asset.state!=='available');return j;
}
async function main(){
 assert.ok(process.env.DATABASE_URL?.endsWith('/photo_gate_fixture'));await settings();await db.session.create({data:{id:sid,csrf:randomBytes(32).toString('hex'),expiresAt:after(180)}});
 await writeFile('/media/other-owner-sentinel','KEEP');
 const happy=await analyzeHappy();await prepare(happy);await run(happy,'prepare');const ready=await row(happy);assert.equal(ready.state,'ready');assert.equal(ready.asset!.state,'available');
 const bytes=await readFile('/media/'+happy+'/image.jpg'),sha=createHash('sha256').update(bytes).digest('hex');assert.deepEqual(bytes,await readFile(OUT+'/input.jpg'));await writeFile(OUT+'/prepared-image.jpg',bytes);
 await copyFile('/media/'+happy+'/tiktok-operations.jsonl',OUT+'/tiktok-operations.jsonl');
 const raw=await native(happy);assert.deepEqual(raw.map(r=>r.coreExit),[0,0]);
 const counts=JSON.parse(await readFile(OUT+'/counts.json','utf8'));assert.equal(counts.metadata,4);assert.equal(counts.JPEG,1);
 cases.push({case:'actual-parent-worker-DB-selectable-ready-after-phase-proof',jobId:happy,metadataGET:4,JPEGGET:1,nativeExits:[0,0],sha256:sha,size:bytes.length});
 const lease=await db.transferLease.create({data:{assetId:ready.asset!.id,expiresAt:after(180),reserved:0n,month:new Date().toISOString().slice(0,7)}});
 for(const name of ['late-analyze','unknown','cross-phase','cross-job','channel-error','missing']){
  await mode(name);const id=await create();const elapsed=await run(id,'analyze');const j=await rejection(id);assert.ok((await native(id)).some(n=>n.phase==='analyze'&&n.coreExit===0));assert.equal(j.items.length,0);await idle();cases.push({case:name,jobId:id,state:j.state,nativeExit:0,elapsedMs:elapsed,error:j.errorCode});
 }
 const cdn=await analyzeHappy();await prepare(cdn);await mode('late-CDN');const cdnMs=await run(cdn,'prepare');const failed=await rejection(cdn);assert.ok((await native(cdn)).some(n=>n.phase==='prepare'&&n.coreExit===0&&n.fileExists&&n.sha256===sha));await idle();
 cases.push({case:'late-CDN-after-valid-file-native0-rejected-before-ready',jobId:cdn,state:failed.state,nativeExit:0,fileStagingWasValid:true,fileCleaned:true,elapsedMs:cdnMs});
 await settings({analyzeTimeout:5});await mode('missing');const deadline=await create();await nativeMode(deadline,'deadline-gate');const elapsed=await run(deadline,'analyze');assert.ok(elapsed<6500);await rejection(deadline);await idle();cases.push({case:'absolute-phase-deadline-not-reset-for-gate',jobId:deadline,elapsedMs:elapsed,native:await native(deadline)});await settings();
 for(const phase of ['analyze','prepare'])for(const suffix of ['exit20','hang']){
  const id=phase==='prepare'?await analyzeHappy():await create();if(phase==='prepare')await prepare(id);
  await mode('happy');await nativeMode(id,phase+'-'+suffix);await settings({analyzeTimeout:5,prepareTimeout:20});const elapsed=await run(id,phase);await rejection(id);assert.ok((await native(id)).some(r=>r.phase===phase&&r.coreExit===0));await idle();cases.push({case:phase+'-PASS-'+suffix,jobId:id,elapsedMs:elapsed,outputCleaned:true});await settings();
 }
 // Cancellation while a native worker is still alive: production ProcessGroup stops it.
 const cancel=await create();await nativeMode(cancel,'analyze-hang');await mode('happy');const pending=run(cancel,'analyze');for(let i=0;i<200;i++){if((await native(cancel)).length)break;await sleep(20);}assert.ok((await native(cancel)).length);await db.downloadJob.update({where:{id:cancel},data:{cancelRequested:true,state:'cancelled'}});await pending;await rejection(cancel,'cancelled');await idle();cases.push({case:'cancel-native-and-own-phase-cleanup',jobId:cancel});
 const saved=process.env.TIKTOK_EGRESS_CONTROL_SECRET;delete process.env.TIKTOK_EGRESS_CONTROL_SECRET;const unconfigured=await create();await run(unconfigured,'analyze');await rejection(unconfigured);assert.equal((await native(unconfigured)).length,0);process.env.TIKTOK_EGRESS_CONTROL_SECRET=saved;cases.push({case:'missing-control-capability-reject-before-child',jobId:unconfigured});
 process.env.TIKTOK_EGRESS_CONTROL_SECRET='0'.repeat(64);const unauthorized=await create();await run(unauthorized,'analyze');await rejection(unauthorized);assert.equal((await native(unauthorized)).length,0);process.env.TIKTOK_EGRESS_CONTROL_SECRET=saved;cases.push({case:'wrong-control-secret-denied-before-child',jobId:unauthorized});
 await mode('missing');const expired=await create();const waiting=run(expired,'analyze');for(let i=0;i<200;i++){if((await native(expired)).length)break;await sleep(20);}assert.ok((await native(expired)).length);await db.downloadJob.update({where:{id:expired},data:{ownerUntil:after(-1)}});await waiting;await rejection(expired,'expired');await idle();cases.push({case:'ownership-expiry-during-proof-wait-no-selectable',jobId:expired});
 const quarantine=await analyzeHappy();await prepare(quarantine);const original=ProcessGroup.prototype.members;
 try{ProcessGroup.prototype.members=function(){throw new Error('FIXTURE_GROUP_UNCONFIRMED');};await run(quarantine,'prepare');}finally{ProcessGroup.prototype.members=original;}
 const q=await row(quarantine);assert.ok(q.workerToken&&liveProcesses.has(q.workerToken));assert.equal(q.state,'preparing');assert.equal(q.asset!.state,'staging');assert.equal(await absent('/media/'+quarantine+'/image.jpg'),false);
 for(const n of await native(quarantine))assert.equal(await absent('/proc/'+n.pid),true);
 liveProcesses.delete(q.workerToken!);await db.downloadJob.update({where:{id:quarantine},data:{processUntil:after(-1)}});await sweep();assert.equal(await absent('/media/'+quarantine),true);await idle();cases.push({case:'group-uncertain-quarantine-retains-staging-until-actual-closure',jobId:quarantine,observerFaultInjected:true});
 for(const url of ['https://www.tiktok.com/@fixture/video/7000000000000000002','https://www.youtube.com/watch?v=abcdefghijk']){
  await mode('happy');const id=await create();await db.downloadJob.update({where:{id},data:{sourceUrl:url,platform:url.includes('youtube')?'youtube':'tiktok'}});await run(id,'analyze');const j=await row(id);assert.equal(j.state,'selectable');assert.equal(j.items[0].kind,'video');
  if(url.includes('youtube')){const env=JSON.parse(await readFile(OUT+'/jobs/'+id+'/legacy-env.json','utf8'));assert.equal(env.connectScopePresent,false);assert.equal(env.controlSecretPresent,false);}await idle();cases.push({case:url.includes('youtube')?'YouTube-extractor-fixture-no-new-credentials':'TikTok-video-real-TLS-ungated-compatibility',jobId:id,state:j.state});
 }
 assert.equal((await readFile('/media/other-owner-sentinel','utf8')),'KEEP');assert.equal(await absent('/media/'+happy+'/image.jpg'),false);assert.equal((await db.transferLease.findUniqueOrThrow({where:{id:lease.id}})).state,'started');cases.push({case:'other-job-sentinel-active-lease-preserved'});
 // Crash is last: no restart/retry of this phase or source request.
 const crash=await analyzeHappy();await prepare(crash);await mode('crash');await run(crash,'prepare');await rejection(crash);assert.ok((await native(crash)).some(n=>n.phase==='prepare'&&n.coreExit===0&&n.fileExists));cases.push({case:'proxy-crash-after-CDN-native0-rejected',jobId:crash});
 await writeFile(OUT+'/worker-result.json',JSON.stringify({status:'PASS_ACTUAL_WORKER_DB_PROXY_GATE_FIXTURE',sourceCalls:0,apiServerRun:false,cases},null,2));console.log('PASS worker gate',cases.length,'cases');
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async(e)=>{
 await writeFile(OUT+'/failure.json',JSON.stringify({class:e?.constructor?.name,operator:e?.operator,frames:String(e?.stack||'').split('\n').filter((s:string)=>/^\s+at /.test(s)).slice(0,5)},null,2));
 console.error('WORKER_GATE_TEST_FAILED');await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;
});
