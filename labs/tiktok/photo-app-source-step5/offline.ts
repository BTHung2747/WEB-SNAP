import assert from 'node:assert/strict';
import {spawn,ChildProcess} from 'node:child_process';
import {readFile,writeFile,mkdir,access,readdir,rename} from 'node:fs/promises';
import {randomUUID,createHash} from 'node:crypto';
import {appendFileSync} from 'node:fs';
import {Worker} from '/app/node_modules/bullmq/dist/cjs/index.js';
import {db,redis,queue,defaults} from '/app/packages/shared/src/core';
const ROOT='/control',ORIGIN='http://step5-offline.invalid',BASE='http://127.0.0.1:3000/api/v1/',URL='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const cases:any[]=[],sleep=(n:number)=>new Promise(r=>setTimeout(r,n));
const mono=()=>Number(process.hrtime.bigint())/1e9;
let child:ChildProcess|undefined,workerRows:any[]=[],current:any,config:any,workflowEnd=0,localEnd=Infinity;
let cleanupClient:any;
let eventCount=0;
function event(line:string){
 const r=JSON.parse(line),events=['LAB_CONSUMER_READY','QUEUE_ERROR','adapter_parent_closed','proxy_phase_gate','adapter_group_stopped','worker_complete','worker_failed'];
 if(!events.includes(r.event))return;
 const safe:any={event:r.event};for(const k of ['id','phase','actualExit','actualSignal','groupLive','registryProtected','accepted','connections','code','inputBytes','workerMs','concurrency','maxStalledCount','maxStartedAttempts']){
  const v=r[k];if(v===undefined)continue;
  if(v===null||typeof v==='number'||typeof v==='boolean'||(k==='id'&&/^[a-f0-9-]{36}$/.test(v))||(k==='phase'&&['analyze','prepare'].includes(v))||(k==='actualSignal'&&['SIGTERM','SIGKILL'].includes(v))||(k==='code'&&/^[A-Z_]{1,50}$/.test(v)))safe[k]=v;
 }
 if(++eventCount>256)throw Error('WORKER_EVENT_CAP');workerRows.push(safe);appendFileSync(ROOT+'/worker.jsonl',JSON.stringify(safe)+'\n');
}
async function json(path:string){return JSON.parse(await readFile(path,'utf8'));}
async function exists(path:string){try{await access(path);return true;}catch{return false;}}
async function request(c:any,path:string,body?:any,max=5){
 const left=Math.min(max,workflowEnd?workflowEnd-mono():max,localEnd-mono());if(left<=0)throw Error('ABSOLUTE_DEADLINE');
 return fetch(BASE+path,{method:body===undefined?'GET':'POST',headers:{cookie:c.cookie,origin:ORIGIN,'x-csrf-token':c.csrf,'content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(Math.max(1,Math.floor(left*1000)))});
}
async function api(c:any,path:string,body?:any){const r=await request(c,path,body);const d=await r.json();return {status:r.status,data:d};}
async function waitFor(fn:()=>Promise<boolean>,seconds=10){const end=mono()+seconds;while(!(await fn())){if(mono()>end)throw Error('WAIT_DEADLINE');await sleep(40);}}
async function client(){const r=await fetch(BASE+'session');assert.equal(r.status,200);const d:any=await r.json();cleanupClient={cookie:r.headers.get('set-cookie')!.split(';')[0],csrf:d.csrf};return cleanupClient;}
async function worker(){
 const p=spawn('/app/node_modules/.bin/tsx',['/fixture/worker.ts'],{cwd:'/app',env:{...process.env,STEP5_OFFLINE_TLS:'1'},stdio:['ignore','pipe','pipe']});
 child=p;workerRows=[];let buffer='';p.stdout!.on('data',b=>{buffer+=b;if(buffer.length>65536){p.kill('SIGTERM');return;}let n;while((n=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,n);buffer=buffer.slice(n+1);try{event(line);}catch{p.kill('SIGTERM');}}});
 p.stderr!.on('data',()=>{});await waitFor(async()=>workerRows.some(r=>r.event==='LAB_CONSUMER_READY'));return p;
}
async function closeWorker(){if(!child)return;const p=child;child=undefined;const close=new Promise<number|null>(r=>p.once('close',r));p.kill('SIGTERM');const code=await Promise.race([close,sleep(6000).then(()=>{p.kill('SIGKILL');return 91;})]);assert.equal(code,0);}
async function start(name:string,fault='normal',seconds=250){
 await closeWorker();localEnd=Infinity;workflowEnd=mono()+seconds;
 config={case:name,mode:'offline',url:URL,fault,end:workflowEnd,wallEnd:Date.now()+seconds*1000};current={name,dir:ROOT+'/cases/'+name,jobId:''};
 await mkdir(current.dir,{recursive:true});await writeFile(ROOT+'/active.tmp',JSON.stringify(config));await rename(ROOT+'/active.tmp',ROOT+'/active.json');await writeFile(ROOT+'/mode.json',JSON.stringify({mode:fault==='missing-proof'?'missing':'happy'}));
 await worker();return client();
}
async function analyze(c:any){const r=await api(c,'jobs/analyze',{url:URL});assert.equal(r.status,202);current.jobId=r.data.jobId;return current.jobId;}
async function state(c:any,id:string,target:string,limit=40){
 const end=Math.min(workflowEnd,mono()+limit);let beat=mono()+15;
 const queueEnd=mono()+10;
 for(;;){const started=await exists(current.dir+'/'+(target==='ready'?'prepare':'analyze')+'.consumer-once');const cap=started?5:Math.min(5,queueEnd-mono());if(cap<=0)throw Error('QUEUE_DEADLINE');const response=await request(c,'jobs/'+id,undefined,cap);const r={data:await response.json()};if(r.data.state===target)return r.data;if(['failed','expired','cancelled'].includes(r.data.state))throw Error('TERMINAL');if(r.data.state==='queued'&&mono()>=queueEnd)throw Error('QUEUE_DEADLINE');if(mono()>end)throw Error('PHASE_DEADLINE');if(mono()>=beat){await api(c,'jobs/'+id+'/heartbeat',{});beat=mono()+15;}await sleep(80);}
}
async function ownedCleanup(c:any,id:string){
 const end=mono()+20;
 await fetch(BASE+'jobs/'+id+'/cancel',{method:'POST',headers:{cookie:c.cookie,origin:ORIGIN,'x-csrf-token':c.csrf,'content-type':'application/json'},body:'{}',signal:AbortSignal.timeout(Math.max(1,Math.min(5000,Math.floor((end-mono())*1000))))}).catch(()=>{});
 if(!child)await worker(); // Cancellation is persisted BEFORE restarting only the lab sweeper/consumer.
 while(mono()<end){const j=await db.downloadJob.findUnique({where:{id}});if(!j?.workerToken&&!(await exists('/media/'+id))){current.cleaned=true;return;}await sleep(80);}
 throw Error('CLEANUP_UNKNOWN');
}
async function proof(phase:string){const p=await json(current.dir+'/'+phase+'.diagnostics.json');assert.equal(p.complete,true);assert.equal(p.metadataAttempts,2);assert.equal(p.imageAttempts,phase==='prepare'?1:0);assert.equal(p.wireGET,'UNKNOWN');return p;}
async function nativeFile(c:any,id:string){
 localEnd=Math.min(workflowEnd,mono()+20);
 const r=await api(c,'jobs/'+id+'/download-ticket',{});assert.equal(r.status,201);const url=r.data.url;assert.match(url,/^\/api\/v1\/downloads\/[a-f0-9]{64}$/);
 const info=await db.downloadJob.findUniqueOrThrow({where:{id},include:{asset:true}});const count=await db.transferLease.count({where:{assetId:info.asset!.id}});
 const h=await fetch('http://127.0.0.1:3000'+url,{method:'HEAD',headers:{cookie:c.cookie},signal:AbortSignal.timeout(Math.floor((localEnd-mono())*1000))});assert.equal(h.status,200);assert.equal(h.headers.get('content-type'),'image/jpeg');assert.equal(h.headers.get('content-disposition'),'attachment; filename="wed-snap-image.jpg"');assert.equal(await db.transferLease.count({where:{assetId:info.asset!.id}}),count);
 const b=await fetch('http://127.0.0.1:3000'+url,{headers:{cookie:c.cookie},signal:AbortSignal.timeout(Math.floor((localEnd-mono())*1000))});assert.equal(b.status,200);const parts:Buffer[]=[];let size=0;for await(const chunk of b.body as any){size+=chunk.length;if(size>16*1024*1024||mono()>=localEnd)throw Error('LOCAL_CAP');parts.push(Buffer.from(chunk));}const file=Buffer.concat(parts);assert.equal(file[0],255);assert.equal(file[1],216);assert.deepEqual(file,await readFile('/media/'+id+'/image.jpg'));
 const range=await fetch('http://127.0.0.1:3000'+url,{headers:{cookie:c.cookie,range:'bytes=0-99'},signal:AbortSignal.timeout(Math.floor((localEnd-mono())*1000))});assert.equal(range.status,206);assert.deepEqual(Buffer.from(await range.arrayBuffer()),file.subarray(0,100));
 await writeFile(current.dir+'/native-image.jpg',file);localEnd=Infinity;
 return {sha256:createHash('sha256').update(file).digest('hex'),size:file.length,localHEAD:1,localGET:1,localRangeGET:1,sourceRequestsFromLocalTransfer:0};
}
async function main(){
 const startup=mono();assert.ok(process.env.DATABASE_URL?.endsWith('/step5_offline'));
 await waitFor(async()=>{try{return (await fetch(BASE+'health',{signal:AbortSignal.timeout(1000)})).ok;}catch{return false;}},Math.max(1,60-(mono()-startup)));await writeFile(ROOT+'/startup.ready','ready');
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}},update:{value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}}});
 let c=await start('happy');let id=await analyze(c);const selectable=await state(c,id,'selectable');await proof('analyze');
 const f=selectable.items[0].formats[1];assert.equal(f.index,2);const selection={itemId:selectable.items[0].id,formatId:f.id,idempotencyKey:randomUUID()};assert.equal((await api(c,'jobs/'+id+'/prepare',selection)).status,202);await state(c,id,'ready',190);const prepared=await proof('prepare');
 assert.equal(prepared.diagnostics.requests.reduce((n:number,r:any)=>n+r.decodedBytes,0),prepared.diagnostics.inputBytes);
 const cp=(await readFile(ROOT+'/completions.jsonl','utf8')).trim().split('\n').map(JSON.parse).filter(r=>r.case==='happy');assert.equal(cp.length,3);assert.ok(cp.every(r=>r.accepted&&r.threadClosed&&r.clientClosed&&!r.traceIncomplete));
 const file=await nativeFile(c,id);await sleep(100);const counter=await json(ROOT+'/counts.json');assert.equal(counter.metadata,4);assert.equal(counter.JPEG,1);
 const first=JSON.parse(JSON.stringify(current));await ownedCleanup(c,id);cases.push({case:'one-job-two-child-index2-fresh-native-HEAD-GET-Range',jobId:id,sourceCalls:0,fixtureOriginGET:5,...file});
 // Separate workflow: still selectable, so sourceUrl matches when durable phase fence denies replay.
 c=await start('redelivery');id=await analyze(c);await state(c,id,'selectable');
 await closeWorker();await worker();const before=JSON.stringify(await json(ROOT+'/counts.json'));await queue.add('analyze',{id},{jobId:'offline-redelivery-'+randomUUID(),attempts:1});await waitFor(async()=>exists(current.dir+'/stopped'));
 const log=(await readFile(current.dir+'/consumer.jsonl','utf8')).trim().split('\n').map(JSON.parse);assert.equal(log.filter(r=>r.event==='PROCESSOR_BEGIN'&&r.phase==='analyze').length,1);assert.equal(JSON.stringify(await json(ROOT+'/counts.json')),before);await ownedCleanup(c,id);cases.push({case:'restart-duplicate-redelivery-denied-before-processor-no-second-child',jobId:id});
 // Real Redis lock expiry via the public Worker manual-fetch API; maxStalledCount0 must not rerun it.
 c=await start('stalled');id=await analyze(c);await state(c,id,'selectable');await closeWorker();
 const redelivery=await queue.add('analyze',{id},{jobId:'offline-stalled-'+randomUUID(),attempts:1});
 const holder=new Worker('media',undefined,{connection:redis as any,autorun:false,lockDuration:250,skipLockRenewal:true,stalledInterval:100,maxStalledCount:1});
 const locked=await holder.getNextJob('offline-lock-token',{block:false});assert.equal(locked?.id,redelivery.id);await holder.close(true);await sleep(350);
 const prior=JSON.stringify(await json(ROOT+'/counts.json'));await worker();await waitFor(async()=> (await redelivery.getState())==='failed',8);
 assert.equal(JSON.stringify(await json(ROOT+'/counts.json')),prior);const stalledLog=(await readFile(current.dir+'/consumer.jsonl','utf8')).trim().split('\n').map(JSON.parse);assert.equal(stalledLog.filter(r=>r.event==='PROCESSOR_BEGIN').length,1);await ownedCleanup(c,id);cases.push({case:'actual-expired-Redis-lock-maxStalled0-no-second-processor-or-child',jobId:id});
 c=await start('missing-diagnostics','missing-diagnostics');id=await analyze(c);await state(c,id,'failed');const bad=await json(current.dir+'/analyze.diagnostics.json');assert.equal(bad.complete,false);assert.equal(bad.attempts,'UNKNOWN');assert.ok((await api(c,'jobs/'+id+'/download-ticket',{})).status>=400);await ownedCleanup(c,id);cases.push({case:'missing-diagnostics-UNKNOWN-native-fail-no-ticket',jobId:id});
 c=await start('missing-proof','missing-proof');id=await analyze(c);await state(c,id,'failed',12);assert.ok((await api(c,'jobs/'+id+'/download-ticket',{})).status>=400);await ownedCleanup(c,id);cases.push({case:'missing-proxy-proof-native0-failed-no-ticket',jobId:id});
 c=await start('cancel','cancel-wait');id=await analyze(c);await waitFor(async()=>exists(current.dir+'/analyze.child-once'));await ownedCleanup(c,id);assert.equal(await exists(current.dir+'/prepare.child-once'),false);cases.push({case:'cancel-partial-diagnostic-UNKNOWN-physical-cleanup',jobId:id,wireGET:'UNKNOWN'});
 c=await start('post-timeout','cancel-wait');let posts=0;posts++;const accepted=await api(c,'jobs/analyze',{url:URL});id=accepted.data.jobId;current.jobId=id;
 // Offline observer drops completion AFTER actual server202; do not resend ambiguous POST.
 const ambiguous=await Promise.race([sleep(50).then(()=> 'POST_COMPLETION_TIMEOUT'),sleep(1000).then(()=>accepted)]);assert.equal(ambiguous,'POST_COMPLETION_TIMEOUT');assert.equal(posts,1);await ownedCleanup(c,id);cases.push({case:'POST-accepted-response-completion-timeout-no-resend-no-prepare',jobId:id,analyzePOST:1,fixtureDroppedCompletion:true});
 c=await start('deadline','cancel-wait',3);id=await analyze(c);await sleep(3100);let denied=false;try{await api(c,'jobs/'+id+'/prepare',{});}catch{denied=true;}assert.equal(denied,true);await ownedCleanup(c,id);assert.equal(await exists(current.dir+'/prepare.child-once'),false);await waitFor(async()=>exists(current.dir+'/independent-deadline.json'));assert.equal((await json(current.dir+'/independent-deadline.json')).successAllowed,false);cases.push({case:'independent-absolute-workflow-exhausted-before-prepare-no-reset',jobId:id,cleanupWindowSeparate:true,fixtureWorkflowSeconds:3});
 c=await start('local-exhausted');localEnd=mono()+.02;await sleep(30);let localDenied=false;try{await request(c,'health');}catch{localDenied=true;}assert.equal(localDenied,true);localEnd=Infinity;cases.push({case:'local-subdeadline-exhausted-no-HTTP-start',fixtureLocalSeconds:.02});
 c=await start('queue-exhausted');await closeWorker();id=await analyze(c);let queueDenied=false;try{await state(c,id,'selectable',20);}catch{queueDenied=true;}assert.equal(queueDenied,true);const counterBefore=JSON.stringify(await json(ROOT+'/counts.json'));await worker();await waitFor(async()=>exists(current.dir+'/stopped'));assert.equal(await exists(current.dir+'/analyze.consumer-once'),false);assert.equal(await exists(current.dir+'/analyze.child-once'),false);assert.equal(JSON.stringify(await json(ROOT+'/counts.json')),counterBefore);await ownedCleanup(c,id);cases.push({case:'queue10-exhausted-late-consumer-denied-before-processor-child-source',jobId:id});
 await closeWorker();workflowEnd=0;localEnd=Infinity;
 await writeFile(ROOT+'/offline-result.json',JSON.stringify({status:'PASS_STEP5_NARROW_OFFLINE',sourceGrant:false,sourceExecutionStarted:false,sourceCalls:0,apiServerActual:true,BullMQActual:true,productionProcessorActual:true,sourceModeExecutable:false,apiBrowserCombined:false,cases,deadlines:{startup:60,workflow:250,queueEachPhase:10,local:20,cleanup:20,OS:360},wireGET:'UNKNOWN_NOT_INFERRED_FROM_CONNECT',historicalExpectationUsedForFixture:false},null,2));
 console.log('PASS step5 offline',cases.length);
}
main().catch(async e=>{const name=['Error','AssertionError','TypeError','TimeoutError'].includes(e?.constructor?.name)?e.constructor.name:'UNKNOWN';const operator=['strictEqual','deepStrictEqual','equal','ok'].includes(e?.operator)?e.operator:'UNKNOWN';await writeFile(ROOT+'/failure.json',JSON.stringify({class:name,operator,code:'OFFLINE_FAILED'}));console.error('OFFLINE_FAILED');process.exitCode=1;}).finally(async()=>{if(current?.jobId&&!current.cleaned&&cleanupClient){await ownedCleanup(cleanupClient,current.jobId).catch(()=>{});}await closeWorker().catch(()=>{});await queue.close();redis.disconnect();await db.$disconnect();});
