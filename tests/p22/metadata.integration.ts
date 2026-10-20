import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync, readlinkSync } from 'node:fs';
import { access, mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import cookieParser from 'cookie-parser';
import { Worker } from 'bullmq';
import { PrismaClient } from '@prisma/client';
import { JobsController } from '../../apps/api/src/controllers/jobs.controller';
import { DownloadsController } from '../../apps/api/src/controllers/downloads.controller';
import { JobsService } from '../../apps/api/src/services/jobs.service';
import { DownloadsService } from '../../apps/api/src/services/downloads.service';
import { SafeErrors } from '../../apps/api/src/common';
import { db, redis, queue, secret, hash, defaults, limitsSchema, filePath, lockJob } from '../../packages/shared/src/core';
import { processJob } from '../../apps/worker/src/processor';
import { sweep } from '../../apps/worker/src/lifecycle';
import { liveProcesses } from '../../apps/worker/src/process-registry';

const NativeDate = Date, realNow = () => NativeDate.now();
let cursor = realNow(), clock = cursor;
class ClockDate extends NativeDate { constructor(value?: any) { if (arguments.length) super(value); else super(clock); } static now() { return clock; } }
const raw = (stage: string, data: object) => console.log('P22_RAW ' + JSON.stringify({ stage, utc: new NativeDate().toISOString(), vn: new NativeDate(realNow()+7*3600000).toISOString().replace('Z','+07:00'), clockMs: clock, ...data }, (_, v) => typeof v === 'bigint' ? v.toString() : v));
async function until(predicate: () => Promise<boolean>, reason: string, ms = 8000) { const end=performance.now()+ms; while (!(await predicate()) && performance.now()<end) await new Promise(r=>setTimeout(r,10)); assert(await predicate(), 'Bound'+ms+'ms: '+reason); }
async function exists(path: string) { try { await access(path); return true; } catch { return false; } }
const sourcePaths=['prisma/schema.prisma','packages/shared/src/core.ts','apps/api/src/services/jobs.service.ts','apps/worker/src/processor.ts','apps/worker/src/lifecycle.ts'];
type Fixture = {token:string;csrf:string;sessionId:string;id:string;itemId:string;formatId:string;key:string;base:number};
const owned:Fixture[]=[], workerCalls: {id:string;phase:string;clock:number}[]=[], http:object[]=[];
let order=0, inflight=0, peak=0, activeCase='setup';
let baseUrl:string, worker:Worker;
async function calls(id:string) { const text=await readFile('/tmp/p22-control/invocations.jsonl','utf8').catch(()=> ''); return text.trim().split('\n').filter(Boolean).map(line=>JSON.parse(line)).filter(row=>row.id===id); }
async function snapshot(id:string) {
  const row:any=await db.downloadJob.findUniqueOrThrow({where:{id},include:{items:true,asset:{include:{leases:true}}}});
  const q=await queue.getJob('prepare-'+id);
  return {id,state:row.state,errorCode:row.errorCode,metadataAcceptedAt:row.metadataAcceptedAt??null,metadataExpiresAt:row.metadataExpiresAt??null,ownerUntil:row.ownerUntil,updatedAt:row.updatedAt,sourcePresent:!!row.sourceUrl,title:row.title,itemCount:row.items.length,formats:row.items.map((i:any)=>i.formats),prepareKey:row.prepareKey,workerToken:row.workerToken,processUntil:row.processUntil,asset:row.asset,queuePrepare:q?await q.getState():null,workerCalls:workerCalls.filter(c=>c.id===id),adapterCalls:await calls(id),folder:await exists(filePath(id)),preview:await exists(filePath(id+'/preview'))};
}
async function request(f:Fixture,path:string,method='GET',body?:object,extra:Record<string,string>={}) {
  const start=++order; const headers={Cookie:'ws_session='+f.token,Origin:'http://p22.local','x-csrf-token':f.csrf,'Content-Type':'application/json',...extra};
  const response=await fetch(baseUrl+'/api/v1/'+path,{method,headers,body:body?JSON.stringify(body):undefined});
  const bytes=Buffer.from(await response.arrayBuffer()); let data:any=null; if(response.headers.get('content-type')?.includes('json')) data=JSON.parse(bytes.toString());
  const event={case:activeCase,startOrder:start,finishOrder:++order,path:path.replace(/downloads\/.+/,'downloads/<fixture-ticket>'),method,status:response.status,code:data?.error?.code??null,jobId:data?.jobId??data?.id??null,state:data?.state??null,itemCount:data?.items?.length??null,previewUrl:data?.previewUrl??null,bytes:bytes.length};
  http.push(event);raw('http',event);return {status:response.status,data,bytes,headers:response.headers};
}
const prepare=(f:Fixture,key=f.key,format=f.formatId)=>request(f,'jobs/'+f.id+'/prepare','POST',{itemId:f.itemId,formatId:format,idempotencyKey:key});
const status=(f:Fixture)=>request(f,'jobs/'+f.id);
const beat=(f:Fixture)=>request(f,'jobs/'+f.id+'/heartbeat','POST');
async function make(sourceExpiry?:number) {
  const token=secret(), csrf=secret(), sessionId=hash(token);
  await db.session.create({data:{id:sessionId,csrf,expiresAt:new Date(clock+3600000)}});
  const f:Fixture={token,csrf,sessionId,id:'',itemId:'',formatId:'fixture-mp4',key:randomUUID(),base:clock};
  const r=await request(f,'jobs/analyze','POST',{url:'https://www.youtube.com/watch?v=p22meta0001'});
  assert.equal(r.status,202);f.id=r.data.jobId;owned.push(f);
  if(sourceExpiry!==undefined)await writeFile('/tmp/p22-control/'+f.id+'.source-expiry.json',JSON.stringify({sourceExpiresAt:sourceExpiry}));
  worker.resume();await until(async()=>{const row=await db.downloadJob.findUniqueOrThrow({where:{id:f.id}});return row.state!=='analyzing'},'analyze accepted/terminal');await worker.pause();
  const row=await db.downloadJob.findUniqueOrThrow({where:{id:f.id},include:{items:true}});f.itemId=row.items[0]?.id??randomUUID();
  raw('analyze-accepted',{case:activeCase,base:f.base,snapshot:await snapshot(f.id)});return f;
}
function expired(r:{status:number;data:any}) { assert.equal(r.status,410,'Expected JOB_EXPIRED410');assert.equal(r.data.error.code,'JOB_EXPIRED'); }
async function noPrepare(f:Fixture) { const s=await snapshot(f.id);raw('expired-counts',{case:activeCase,snapshot:s});assert.equal(s.state,'expired');assert.equal(s.sourcePresent,false);assert.equal(s.itemCount,0);assert.equal(s.asset,null);assert.equal(s.queuePrepare,null);assert.equal(s.adapterCalls.filter((c:any)=>c.phase==='prepare').length,0);assert.equal(s.prepareKey,null); }
async function cleanup(f:Fixture) {
  await unlink('/tmp/p22-control/'+f.id+'.prepare-gate').catch(()=>{});
  await worker.pause();const current=await snapshot(f.id);
  if(!current.asset && ['analyzing','selectable','queued'].includes(current.state)) {
    await request(f,'jobs/'+f.id+'/release','POST');clock+=30001;
  }else if(current.asset)await request(f,'jobs/'+f.id+'/cancel','POST');
  const begin=performance.now();await sweep();await sweep();
  const row=await snapshot(f.id);raw('fixture-lifecycle-cleanup',{id:f.id,elapsedMs:performance.now()-begin,snapshot:row,registrySize:liveProcesses.size});
  assert.equal(row.folder,false);assert.equal(row.workerToken,null);assert.equal(liveProcesses.size,0);assert(!row.asset||row.asset.state==='deleted');
  // Remove only owned leftover outbox entries; retain DB rows/charged/counters/volumes/log.
  for(const phase of ['analyze','prepare']) {const job=await queue.getJob(phase+'-'+f.id);if(job){assert.notEqual(await job.getState(),'active');await job.remove();}}
}
const cases:{name:string;expected:string;run:()=>Promise<void>}[]=[];
const add=(name:string,expected:string,run:()=>Promise<void>)=>cases.push({name,expected,run});
add('heartbeat-does-not-keep-stale-selection','repeat HB<120s; at120001 status410/no formats; repeat status/HB/prepare410 no revival/queue/asset/adapter',async()=>{
  const f=await make();for(const ms of [30000,60000,90000,119999]){clock=f.base+ms;assert.equal((await beat(f)).status,201);raw('heartbeat-age',{age:ms,snapshot:await snapshot(f.id)});}
  clock=f.base+120001;const r=await status(f);raw('baseline-stale-status',{response:{status:r.status,data:r.data},snapshot:await snapshot(f.id)});expired(r);
  const deadline=(await snapshot(f.id)).metadataExpiresAt;
  for(let i=0;i<2;i++){expired(await status(f));expired(await beat(f));expired(await prepare(f));}
  assert.deepEqual((await snapshot(f.id)).metadataExpiresAt,deadline);await noPrepare(f);
});
add('stale-prepare-at-120000','old metadata with owner alive:410; transaction commits expiry,0 enqueue/asset/prepare adapter',async()=>{
  const f=await make();clock=f.base+119999;assert.equal((await beat(f)).status,201);clock=f.base+120000;
  const r=await prepare(f);raw('baseline-stale-prepare',{response:r.data,status:r.status,snapshot:await snapshot(f.id)});expired(r);await noPrepare(f);
});
add('boundary-119999-and-ready-transfer','119999 status/preview200; accept prepare; after120001 queued retry/ready/ticket/full8192/hash/lease correct',async()=>{
  const f=await make();clock=f.base+119999;assert.equal((await status(f)).status,200);assert.equal((await request(f,'jobs/'+f.id+'/preview')).status,200);
  assert.equal((await prepare(f)).status,202);const initial=await snapshot(f.id);assert.equal(initial.state,'queued');assert.equal(initial.queuePrepare,'waiting');
  clock=f.base+120001;assert.equal((await prepare(f)).status,202);assert.equal((await status(f)).data.state,'queued');assert.equal((await beat(f)).status,201);
  worker.resume();await until(async()=> (await snapshot(f.id)).state==='ready','ready control');await worker.pause();
  assert.equal((await prepare(f)).data.state,'ready');const ready=await snapshot(f.id);assert.equal(ready.adapterCalls.filter((c:any)=>c.phase==='prepare').length,1);assert.equal(ready.asset.size,8192n);
  const ticket=await request(f,'jobs/'+f.id+'/download-ticket','POST');assert.equal(ticket.status,201);const token=ticket.data.url.split('/').at(-1);
  const response=await request(f,'downloads/'+token);assert.equal(response.status,200);assert.deepEqual(response.bytes,Buffer.alloc(8192,7));
  await until(async()=> (await snapshot(f.id)).asset.leases.some((l:any)=>l.state==='server_finished'),'transfer finalize');
  const final=await snapshot(f.id);raw('ready-transfer-control',{snapshot:final,bytes:response.bytes.length,sha256:createHash('sha256').update(response.bytes).digest('hex')});
  assert.equal(final.state,'ready');assert.equal(final.asset.state,'available');assert.equal(final.asset.leases[0].bytes,8192n);assert.equal(final.asset.leases[0].reserved,8192n);
});
add('boundary-120000-heartbeat-first','HB410 immediately at equality; no owner or deadline renew; status/preview/prepare410',async()=>{
  const f=await make();const before=await snapshot(f.id);clock=f.base+120000;expired(await beat(f));const after=await snapshot(f.id);
  assert.deepEqual(after.ownerUntil,before.ownerUntil);assert.deepEqual(after.metadataExpiresAt,before.metadataExpiresAt);expired(await status(f));expired(await request(f,'jobs/'+f.id+'/preview'));expired(await prepare(f));await noPrepare(f);
});
add('boundary-120001-preview-first','preview410 before sweep; status410 and0 cached options',async()=>{const f=await make();clock=f.base+120001;const r=await request(f,'jobs/'+f.id+'/preview');raw('preview-first-expiry',{status:r.status,snapshot:await snapshot(f.id)});expired(r);expired(await status(f));await noPrepare(f);});
add('fixed-publish-deadline','deadline acceptedAt+120000; repeated HB/status cannot renew despite owner/updatedAt mutation',async()=>{
  const f=await make();const first:any=await snapshot(f.id);assert.equal(first.metadataAcceptedAt?.getTime(),f.base);assert.equal(first.metadataExpiresAt?.getTime(),f.base+120000);
  for(const age of [1,15000,60000,119999]){clock=f.base+age;assert.equal((await beat(f)).status,201);const r=await status(f);assert.equal(r.status,200);const s:any=await snapshot(f.id);assert.deepEqual(s.metadataExpiresAt,first.metadataExpiresAt);assert(s.ownerUntil.getTime()>first.ownerUntil.getTime());raw('fixed-deadline-age',{age,snapshot:s});}
});
add('earlier-trusted-source-deadline','fixture absolute expiry30000 clamps production publish; valid29999/expired30000',async()=>{
  const f=await make(clock+30000);const first:any=await snapshot(f.id);assert.equal(first.metadataExpiresAt?.getTime(),f.base+30000);clock=f.base+29999;assert.equal((await status(f)).status,200);assert.equal((await beat(f)).status,201);clock=f.base+30000;expired(await prepare(f));expired(await status(f));await noPrepare(f);
});
add('source-already-expired-at-publish','trusted source expiry at acceptance:expired/JOB_EXPIRED/no selectable publication',async()=>{const f=await make(clock);const s=await snapshot(f.id);assert.equal(s.state,'expired');assert.equal(s.errorCode,'JOB_EXPIRED');assert.equal(s.itemCount,0);expired(await status(f));await noPrepare(f);});
add('legacy-selectable-no-timestamp','NULL stamps fail closed; no backfill from heartbeat-updatedAt; historical title retained',async()=>{
  const f=await make();await db.$executeRaw`UPDATE "DownloadJob" SET "state"='selectable' WHERE id=${f.id}`;
  const columns:any[]=await db.$queryRaw`SELECT column_name FROM information_schema.columns WHERE table_name='DownloadJob' AND column_name='metadataAcceptedAt'`;
  if(columns.length)await db.$executeRaw`UPDATE "DownloadJob" SET "metadataAcceptedAt"=NULL,"metadataExpiresAt"=NULL WHERE id=${f.id}`;
  const r=await beat(f);raw('legacy-heartbeat',{status:r.status,snapshot:await snapshot(f.id)});expired(r);expired(await status(f));assert.equal((await snapshot(f.id)).title,'P22 local metadata fixture');await noPrepare(f);
});
add('sweeper-metadata-cache-preview-cleanup','owner alive at120000; sweep expires cache/source and removes preview<=8s;2more sweeps no orphan/revival',async()=>{
  const f=await make();assert(await exists(filePath(f.id+'/preview')));clock=f.base+120000;const start=performance.now();await sweep();await noPrepare(f);assert(!await exists(filePath(f.id)));assert(performance.now()-start<8000);clock++;await sweep();clock++;await sweep();assert(!await exists(filePath(f.id)));raw('sweep-bound',{elapsedMs:performance.now()-start,iterations:3,snapshot:await snapshot(f.id)});
});
add('queued-preparing-ready-idempotency-after-deadline','accepted119999 continues all3 states after expiry, exactly1 asset/adapter/completion, conflict409',async()=>{
  const f=await make();clock=f.base+119999;assert.equal((await prepare(f)).status,202);const queued=await snapshot(f.id);assert.equal(queued.state,'queued');assert.equal(queued.asset,null);
  clock=f.base+120001;assert.equal((await prepare(f)).status,202);assert.equal((await prepare(f,randomUUID())).status,202);assert.equal((await prepare(f,randomUUID(),'conflict-format')).status,409);
  await writeFile('/tmp/p22-control/'+f.id+'.prepare-gate','hold');worker.resume();await until(async()=> (await snapshot(f.id)).state==='preparing'&&await exists(filePath(f.id+'/media.mp4.part')),'actual preparing/staging/partial');
  const preparing=await snapshot(f.id);assert.equal(preparing.asset.state,'staging');assert(preparing.workerToken);assert.equal((await prepare(f)).data.state,'preparing');assert.equal((await beat(f)).status,201);await sweep();assert(await exists(filePath(f.id+'/media.mp4.part')));
  await unlink('/tmp/p22-control/'+f.id+'.prepare-gate');await until(async()=> (await snapshot(f.id)).state==='ready','ready after gate');await worker.pause();
  assert.equal((await prepare(f)).data.state,'ready');assert.equal((await status(f)).data.state,'ready');const ready=await snapshot(f.id);
  assert.equal(ready.adapterCalls.filter((c:any)=>c.phase==='prepare').length,1);assert.equal(ready.workerCalls.filter(c=>c.phase==='prepare').length,1);assert.equal(await db.temporaryAsset.count({where:{jobId:f.id}}),1);
  const metrics=await db.auditLog.findMany({where:{action:'worker.metrics'}});assert.equal(metrics.filter(m=>(m.detail as any).id===f.id&&(m.detail as any).phase==='prepare'&&(m.detail as any).result==='complete').length,1);
  assert.deepEqual(ready.metadataExpiresAt,queued.metadataExpiresAt);raw('three-state-control',{queued,preparing,ready});
});
async function prepareRace(cross:boolean) {
  const f=await make();clock=f.base+119999;
  let held!:()=>void, unlock!:()=>void;const acquired=new Promise<void>(r=>held=r), release=new Promise<void>(r=>unlock=r);
  // A separate real pool avoids consuming all3 production pool connections with
  // the lock holder +2 requests, leaving a connection for observing pg locks.
  const holder=new PrismaClient();
  const blocker=holder.$transaction(async tx=>{await lockJob(tx,f.id);held();await release},{timeout:15000});await acquired;
  const oldPeak=peak;const first=prepare(f), second=prepare(f);let waiting=0;
  try {await until(async()=>{const rows:any[]=await db.$queryRaw`SELECT count(*)::int AS n FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock'`;waiting=rows[0].n;return waiting>=2},'two production transactions waiting on real PostgreSQL locks');raw('race-before-unlock',{cross,pendingHTTP:inflight,waitingDatabaseLocks:waiting,oldPeak,peak,snapshot:await snapshot(f.id)});assert(inflight>=2);if(cross)clock=f.base+120000;} finally {unlock();await blocker;await holder.$disconnect();}
  const results=await Promise.all([first,second]);raw('race-results',{cross,statuses:results.map(r=>r.status),codes:results.map(r=>r.data?.error?.code),snapshot:await snapshot(f.id)});
  if(cross){results.forEach(expired);await noPrepare(f);}else{
    assert(results.every(r=>r.status===202));const s=await snapshot(f.id);assert.equal(s.state,'queued');assert.equal(s.queuePrepare,'waiting');assert.equal(s.asset,null);assert.equal(s.adapterCalls.filter((c:any)=>c.phase==='prepare').length,0);
    clock=f.base+120001;assert.equal((await prepare(f)).status,202);worker.resume();await until(async()=> (await snapshot(f.id)).state==='ready','one race prepare completes');await worker.pause();const ready=await snapshot(f.id);assert.equal(ready.adapterCalls.filter((c:any)=>c.phase==='prepare').length,1);assert.equal(ready.workerCalls.filter(c=>c.phase==='prepare').length,1);assert.equal(await db.temporaryAsset.count({where:{jobId:f.id}}),1);
  }
}
add('concurrent-prepare-before-deadline','real lock/inflight2 at119999:one queued/one real invocation, retries after expiry idempotent',()=>prepareRace(false));
add('concurrent-prepare-cross-deadline','2blocked production transactions before120s; unlock at120000 both410 and0 queued/asset/adapter',()=>prepareRace(true));
add('auth-csrf-and-owner-lifecycle-controls','wrongcsrf403/foreign404; owner/release expiry remain independent and no prepare',async()=>{
  const f=await make();assert.equal((await request(f,'jobs/'+f.id+'/heartbeat','POST',undefined,{'x-csrf-token':'bad-fixture'})).status,403);
  const other=await make();assert.equal((await request(other,'jobs/'+f.id)).status,404);const first=await snapshot(f.id);assert.equal(first.state,'selectable');
  await db.downloadJob.update({where:{id:f.id},data:{ownerUntil:new Date(clock+1000)}});clock+=1000;expired(await prepare(f));await sweep();assert.equal((await snapshot(f.id)).state,'expired');
  await request(other,'jobs/'+other.id+'/release','POST');clock+=30000;await sweep();assert.equal((await snapshot(other.id)).state,'expired');assert.equal((await snapshot(other.id)).metadataExpiresAt?.getTime(),other.base+120000);
});
add('new-analyze-new-deadline','expired original cannot revive; new job/key has acceptedAt/deadline from new analyze',async()=>{const old=await make();clock=old.base+120000;expired(await status(old));const fresh=await make();assert.notEqual(fresh.id,old.id);const s:any=await snapshot(fresh.id);assert.equal(s.metadataAcceptedAt?.getTime(),fresh.base);assert.equal(s.metadataExpiresAt?.getTime(),fresh.base+120000);assert.equal((await status(fresh)).status,200);expired(await status(old));});

async function main(){
  // Same R9 matrix may run in the separate guarded P23 datastore; no fallback.
  const cleanupLab=process.env.P23_GUARD==='wed-snap-cleanup-lab';
  assert.equal(process.env.P22_GUARD,'wed-snap-metadata-lab');assert.equal(process.env.DATABASE_URL,cleanupLab?'postgresql://p23@db:5432/wed_snap_cleanup_test':'postgresql://p22@db:5432/wed_snap_metadata_test');assert.equal(process.env.REDIS_URL,'redis://redis:6379/14');assert.equal(process.env.MEDIA_ROOT,'/media');
  const hashes=Object.fromEntries(sourcePaths.map(path=>[path,createHash('sha256').update(readFileSync(path)).digest('hex')]));
  assert.equal(createHash('sha256').update(sourcePaths.map(path=>path+':'+hashes[path]).join('|')).digest('hex'),process.env.P22_SOURCE_SHA);
  const identity:any[]=await db.$queryRaw`SELECT current_database() AS database,version() AS version`;assert.equal(identity[0].database,cleanupLab?'wed_snap_cleanup_test':'wed_snap_metadata_test');assert(/\bdb=14\b/.test(String(await redis.client('INFO'))));
  assert.equal(await db.adCampaign.count(),0);assert.equal(await db.adEvent.count(),0);assert.equal(liveProcesses.size,0);
  await mkdir('/tmp/p22-control',{recursive:true});
  const saved=await db.settings.findMany({orderBy:{id:'asc'}});const chargedBefore=await db.egressBudget.findMany({orderBy:{month:'asc'}});
  raw('matrix-before-write',{hashes,testSha:createHash('sha256').update(readFileSync('tests/p22/metadata.integration.ts')).digest('hex'),fixtureSha:createHash('sha256').update(readFileSync('tests/p22/fixture_adapter.py')).digest('hex'),settingsSnapshot:saved,chargedSnapshot:chargedBefore,database:identity[0],redisDb:14,redisVersion:(await redis.info('server')).match(/redis_version:([^\r\n]+)/)?.[1],node:process.version,prisma:JSON.parse(readFileSync('node_modules/@prisma/client/package.json','utf8')).version,namespace:readlinkSync('/proc/self/ns/pid'),stubs:['global Date no-arg/Date.now monotonic virtual clock; real timers/performance/DB timestamps','local Python analyze metadata/sourceExpiresAt/preview and8192 deterministic byte prepare; no socket/platform','fixture cookie/session DB seed; real production cookie/CSRF validation','manual invocation of production sweep, real BullMQ Worker processJob concurrency1','external real PostgreSQL row-lock barrier, not verdict/TTL mocks'],matrix:cases.map(({name,expected})=>({name,expected})),policy:'accepted timestamp max120000ms; now>=expiry; source absolute trusted earlier; legacy NULL expires conservatively; queued/preparing/ready preserve prepare idempotency/owner/asset/transfer'});
  globalThis.Date=ClockDate as typeof Date;
  @Module({controllers:[JobsController,DownloadsController],providers:[JobsService,DownloadsService]})class LabModule{}
  const app=await NestFactory.create(LabModule,{logger:['error']});app.use(cookieParser());app.useGlobalFilters(new SafeErrors());
  app.use((req:any,res:any,next:()=>void)=>{if(req.path.endsWith('/prepare')){inflight++;peak=Math.max(peak,inflight);res.once('finish',()=>inflight--);}next();});await app.listen(0,'127.0.0.1');baseUrl=await app.getUrl();
  const workerRedis=redis.duplicate();worker=new Worker('media',async job=>{workerCalls.push({id:job.data.id,phase:job.name,clock});await processJob(job)},{connection:workerRedis as any,concurrency:1});await worker.waitUntilReady();await worker.pause();
  worker.on('error',e=>raw('worker-error',{error:e.message}));let passed=0,failed=0;
  try{
    const override=limitsSchema.parse({...defaults,sessionTtl:600,readyTtl:600,sweepSeconds:1,retryGrace:2,transferMax:600});
    await db.settings.upsert({where:{id:'main'},create:{id:'main',value:override},update:{value:override}});raw('settings-test-override',{value:override,noProductionCapChanges:true});
    for(const test of cases){cursor+=240000;clock=cursor;activeCase=test.name;const startOwned=owned.length;let error:string|null=null;try{await test.run();}catch(e){error=String(e);}finally{for(const f of owned.slice(startOwned)){try{await cleanup(f);}catch(e){error=(error??'')+' cleanup:'+String(e);}}}
      if(error)failed++;else passed++;raw('case-result',{name:test.name,expected:test.expected,result:error?'FAIL':'PASS',error,fixtureIds:owned.slice(startOwned).map(f=>f.id),registrySize:liveProcesses.size});
    }
  }finally{
    await worker.close();await workerRedis.quit();await app.close();globalThis.Date=NativeDate;
    const prior=saved.find(s=>s.id==='main');if(prior)await db.settings.update({where:{id:'main'},data:{value:prior.value!}});else await db.settings.deleteMany({where:{id:'main'}});
    assert.deepEqual(await db.settings.findMany({orderBy:{id:'asc'}}),saved);
    const chargedAfter=await db.egressBudget.findMany({orderBy:{month:'asc'}});raw('finally',{settingsDeepEqual:true,chargedBefore,chargedAfter,chargedPolicy:'retain actual finalized download counters; never reset/restore charged',rowsRetained:owned.map(f=>f.id),fixtureFoldersRemaining:await Promise.all(owned.map(async f=>({id:f.id,exists:await exists(filePath(f.id))}))),registrySize:liveProcesses.size,clockRestored:globalThis.Date===NativeDate,noReset:true});
    await queue.close();await redis.quit();await db.$disconnect();
  }
  raw('summary',{passed,failed,result:failed?'FAIL':'PASS'});if(failed)process.exitCode=1;
}
main().catch(e=>{globalThis.Date=NativeDate;console.error('P22_HARNESS_FAIL',String(e));process.exit(1);});
