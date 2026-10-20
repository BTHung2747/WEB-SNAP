import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync, readlinkSync} from 'node:fs';
import {mkdir, realpath, lstat, readdir, rmdir} from 'node:fs/promises';
import expected from './expected.json';

const RealDate=Date, req=createRequire(__filename), mode=process.argv[2];
const sha=(s:string)=>createHash('sha256').update(s).digest('hex');
const uuid=()=>req('node:crypto').randomUUID() as string;
function raw(stage:string,data:any){const now=new RealDate();console.log('P34_RAW '+JSON.stringify({stage,mode,utc:now.toISOString(),vn:new RealDate(now.getTime()+25200000).toISOString().replace('Z','+07:00'),...data},(_k,v)=>typeof v==='bigint'?String(v):v));}
async function until(fn:()=>Promise<boolean>){const end=performance.now()+5000;while(!await fn()){if(performance.now()>end)throw Error('Harness PG barrier deadline; not production verdict');await new Promise(r=>setTimeout(r,25));}}
async function main(){
 assert(mode==='baseline'||mode==='final');
 assert.equal(process.env.P34_GUARD,'wed-snap-worker-metrics-retention-lab');
 assert.equal(process.env.DATABASE_URL,'postgresql://p34@db:5432/wed_snap_worker_metrics_retention_test');
 assert.equal(process.env.REDIS_URL,'redis://redis:6379/11');assert.equal(process.env.MEDIA_ROOT,'/tmp/p34-media');
 const coordinates=JSON.parse(readFileSync('/tmp/p34/coordinates.json','utf8'));
 const hashes=Object.fromEntries(coordinates.sources.map((p:string)=>[p,sha(readFileSync(p,'utf8'))]));
 assert.equal(sha(coordinates.sources.map((p:string)=>p+':'+hashes[p]).join('|')),coordinates.sourceSHA);
 assert.equal(coordinates.sourceSHA,process.env.P34_SOURCE_SHA);
 const net=req('node:net'),connect=net.Socket.prototype.connect,listen=net.Server.prototype.listen;
 const counters={redisDials:0,deniedDials:0,deniedListens:0};
 net.Socket.prototype.connect=function(...args:any[]){const a=Array.isArray(args[0])?args[0]:args,o=typeof a[0]==='object'?a[0]:{port:a[0],host:a[1]};if(Number(o.port)===6379&&['redis',coordinates.redisIP].includes(o.host)){counters.redisDials++;return connect.apply(this,args);}counters.deniedDials++;throw Error('Foreign JS socket denied');};
 net.Server.prototype.listen=function(){counters.deniedListens++;throw Error('All listeners denied in P34');};
 let core:any,inspector:any,block:any,mediaCreated=false;const owned=new Set<string>(),results:any[]=[];
 const outsideNames=['session','adminUser','downloadJob','mediaItem','temporaryAsset','transferLease','downloadTicket','adCampaign','adEvent','egressBudget','settings'];
 let outsideBefore:any;
 try{
  const Redis=req('ioredis');inspector=new Redis(process.env.REDIS_URL,{maxRetriesPerRequest:1});
  assert(/\bdb=11\b/.test(String(await inspector.client('INFO'))));const ri=String(await inspector.info('server'));assert(ri.includes('run_id:'+coordinates.redisRun));assert.deepEqual(await inspector.keys('*'),[]);
  const {PrismaClient}=await import('@prisma/client');const preflight=new PrismaClient();
  try{const rows:any[]=await preflight.$queryRaw`SELECT current_database() AS database,host(inet_server_addr()) AS address,version() AS version,(SELECT system_identifier::text FROM pg_control_system()) AS cluster`;assert.equal(rows[0].database,'wed_snap_worker_metrics_retention_test');assert.equal(rows[0].address,coordinates.dbIP);assert.equal(rows[0].cluster,coordinates.cluster);raw('datastore-identity',{...rows[0],redisDb:11,redisRunMatches:true,redisVersion:/redis_version:([^\r\n]+)/.exec(ri)?.[1]});}finally{await preflight.$disconnect();}
  core=await import('../../packages/shared/src/core');await core.queue.waitUntilReady();
  async function outside(){return Object.fromEntries(await Promise.all(outsideNames.map(async m=>[m,await core.db[m].findMany({orderBy:m==='egressBudget'?{month:'asc'}:{id:'asc'}})])));}
  assert(Object.values(await outside()).every((r:any)=>!r.length));assert.equal(await core.db.auditLog.count(),0);
  // Own sentinel fixtures exercise preservation of nonempty settings and charged, no main writes.
  await core.db.settings.create({data:{id:'main',value:core.defaults}});
  await core.db.egressBudget.create({data:{month:'p34-fixture',charged:37n}});
  outsideBefore=await outside();
  await mkdir(core.mediaRoot,{recursive:false});mediaCreated=true;
  async function mediaGuard(){assert.equal(await realpath(core.mediaRoot),'/tmp/p34-media');const s=await lstat(core.mediaRoot);assert(s.isDirectory()&&!s.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);}
  async function sweepGuard(){await mediaGuard();assert.deepEqual(await outside(),outsideBefore);assert.equal(await core.queue.getWaitingCount(),0);assert.equal(await core.queue.getActiveCount(),0);assert.equal(await core.queue.getDelayedCount(),0);}
  const {sweep}=await import('../../apps/worker/src/lifecycle');
  const helper=mode==='final'?(await import('../../apps/worker/src/worker-metrics-retention')).purgeWorkerMetrics:undefined;
  async function invoke(now:Date){if(helper)return helper(now);class Clock extends RealDate{constructor(...a:any[]){super(a.length?a[0]:now.getTime());}static now(){return now.getTime();}}try{globalThis.Date=Clock as DateConstructor;await sweepGuard();return await sweep();}finally{globalThis.Date=RealDate;}}
  const clock=new RealDate(expected.clock),cutoff=new RealDate(expected.cutoff);
  async function rows(){const r=await core.db.auditLog.findMany({orderBy:[{createdAt:'asc'},{id:'asc'}],take:530});assert(r.length<=520,'Fixture bound');return r;}
  async function seed(data:any[],label:string){assert.equal(await core.db.auditLog.count(),0);for(const r of data)owned.add(r.id);await core.db.auditLog.createMany({data:data.map(r=>({...r,detail:{marker:'p34',label,id:r.id}}))});raw('seed',{label,rows:await rows(),expectedFromSeed:true});}
  async function clear(label:string){const r=await rows();assert(r.every((x:any)=>owned.has(x.id)&&x.detail.marker==='p34'));const d=await core.db.auditLog.deleteMany({where:{id:{in:[...owned]}}});assert.equal(await core.db.auditLog.count(),0);raw('scenario-cleanup',{label,removedOwnRows:d.count,runtimeRetentionProof:false});}
  async function observe(fn:()=>Promise<any>,label:string,now:Date){const before=await rows(),started=performance.now();const result=await fn();const after=await rows(),kept=new Set(after.map((r:any)=>r.id)),deleted=before.filter((r:any)=>!kept.has(r.id));const c=new RealDate(now.getTime()-expected.ttlMs);const eligible=before.filter((r:any)=>r.actor==='worker'&&r.action==='worker.metrics'&&r.createdAt<c);raw('db-diff',{label,elapsedMs:performance.now()-started,cutoff:c,result,beforeCount:before.length,afterCount:after.length,selectedExpectedFromPreSeed:eligible.slice(0,500).map((r:any)=>r.id),deletedIds:deleted.map((r:any)=>r.id),retainedRows:after});assert.deepEqual(await outside(),outsideBefore);const protectedRows=before.filter((r:any)=>r.actor!=='worker'||r.action!=='worker.metrics'||r.createdAt>=c);for(const r of protectedRows)assert.deepEqual(after.find((a:any)=>a.id===r.id),r);return {before,after,deleted};}
  async function test(name:string,fn:()=>Promise<any>){try{results.push({name,result:'PASS',evidence:await fn()});}catch(e){if(!(e instanceof assert.AssertionError))throw e;results.push({name,result:'FAIL',category:'expected-new-policy-on-production-path',error:e.message});}raw('case',results.at(-1));}
  raw('environment',{hashes,sourceSHA:coordinates.sourceSHA,expectedSHA:sha(readFileSync('tests/p34/expected.json','utf8')),testSHA:sha(readFileSync('tests/p34/retention.ts','utf8')),node:process.version,namespace:readlinkSync('/proc/self/ns/pid'),versions:Object.fromEntries(['@prisma/client','ioredis','bullmq','typescript'].map(p=>[p,req(p+'/package.json').version])),stubs:expected.stubs,nativePrisma:'Actual PG native connection outside JS socket counter, numeric IP/cluster guarded',http:0,workerMain:false,scheduler:false,outsideBefore});
  await test(expected.cases[0],async()=>{const indexes:any[]=await core.db.$queryRaw`SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='public' AND tablename='AuditLog' ORDER BY indexname`;raw('index',{indexes});const i=indexes.find(x=>x.indexname===expected.index);assert(i,'New composite index absent');assert(i.indexdef.endsWith('("actor", action, "createdAt", id)')||i.indexdef.endsWith('(actor, action, "createdAt", id)'));assert.deepEqual(indexes.map(x=>x.indexname).sort(),[expected.index,'AuditLog_pkey'].sort());return {indexes};});
  function keepRows(base:Date){const old=new RealDate(base.getTime()-40*86400000);return [
   {id:uuid(),actor:'worker',action:'worker.metrics',createdAt:new RealDate(base.getTime()-30*86400000)},
   {id:uuid(),actor:'worker',action:'worker.metrics',createdAt:new RealDate(base.getTime()-29*86400000)},
   {id:uuid(),actor:'worker',action:'worker.metrics',createdAt:new RealDate(base.getTime()+86400000)},
   {id:uuid(),actor:'other',action:'worker.metrics',createdAt:old},
   {id:uuid(),actor:'worker',action:'worker.other',createdAt:old},
   ...['settings.update','campaign.create','campaign.update','campaign.delete'].map(action=>({id:uuid(),actor:'p34-admin',action,createdAt:old}))];}
  const kept=keepRows(clock),expired={id:uuid(),actor:'worker',action:'worker.metrics',createdAt:new RealDate(cutoff.getTime()-1)};
  await seed([expired,...kept],'strict-boundary-groups');
  await test(expected.cases[1],async()=>{const r=await observe(()=>invoke(clock),'boundary',clock);assert.deepEqual(r.deleted.map((x:any)=>x.id),[expired.id]);assert.deepEqual(r.after.map((x:any)=>x.id).sort(),kept.map(x=>x.id).sort());return {deleted:1,retained:9,exactCutoffKept:true};});
  await test(expected.cases[2],async()=>{const before=await rows();const r=await observe(()=>invoke(clock),'boundary-repeat',clock);assert.equal(r.deleted.length,0);assert.deepEqual(r.after,before);return {noEffects:true};});await clear('boundary');
  const id=(i:number)=>'00000000-0000-4000-8000-'+String(i).padStart(12,'0'),oldest='ffffffff-ffff-4fff-8fff-ffffffffffff';
  const firstIds=[oldest,...Array.from({length:499},(_,i)=>id(i+1))];
  function batch(base:Date){return [...keepRows(base),{id:oldest,actor:'worker',action:'worker.metrics',createdAt:new RealDate(base.getTime()-32*86400000)},...Array.from({length:500},(_,i)=>({id:id(i+1),actor:'worker',action:'worker.metrics',createdAt:new RealDate(base.getTime()-31*86400000)}))].reverse();}
  await seed(batch(clock),'helper-501-reverse-insertion');
  for(let n=0;n<3;n++)await test(expected.cases[3+n],async()=>{const r=await observe(()=>invoke(clock),'helper-batch-'+n,clock);assert(r.deleted.length<=500);assert.deepEqual(r.deleted.map((x:any)=>x.id),n===0?firstIds:n===1?[id(500)]:[]);assert.equal(r.after.filter((x:any)=>x.actor==='worker'&&x.action==='worker.metrics'&&x.createdAt<cutoff).length,n===0?1:0);return {deleted:r.deleted.length,olderBeforeSmallId:true,tieOrder:true,noEffects:n===2};});await clear('helper-batch');
  for(const [n,field] of ['createdAt','actor','action'].entries()){
   const name=expected.cases[6+n];if(!helper){results.push({name,result:'SKIP',reason:'Baseline has no AuditLog delete to observe with PG row barrier'});raw('case',results.at(-1));continue;}
   await test(name,async()=>{const auditId=uuid();await seed([{id:auditId,actor:'worker',action:'worker.metrics',createdAt:new RealDate(cutoff.getTime()-86400000)}],'race-'+field);block=new PrismaClient();let release!:()=>void,entered!:()=>void,pid=0;const held=new Promise<void>(r=>release=r),started=new Promise<void>(r=>entered=r);const data=field==='createdAt'?{createdAt:clock}:field==='actor'?{actor:'p34-admin'}:{action:'campaign.update'};
    const lock=block.$transaction(async(tx:any)=>{pid=(await tx.$queryRaw`SELECT pg_backend_pid() AS pid`)[0].pid;await tx.auditLog.update({where:{id:auditId},data});entered();await held;},{timeout:10000});let work:Promise<any>|undefined;
    try{await started;work=helper(clock);let waiters:any[]=[];await until(async()=>{waiters=await core.db.$queryRaw`SELECT pid,wait_event_type,pg_blocking_pids(pid) AS blockers,query FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND ${pid}=ANY(pg_blocking_pids(pid)) AND query LIKE '%DELETE%' AND query LIKE '%AuditLog%'`;return waiters.length>0;});raw('row-lock-barrier',{field,auditId,ownBlockerPid:pid,waiters,pendingResponse:true,afterSelectBeforeDeleteCommit:true,newValue:data});release();await lock;const r=await work,row=await core.db.auditLog.findUniqueOrThrow({where:{id:auditId}});assert.equal(r.count,0);for(const [k,v] of Object.entries(data))assert.deepEqual(row[k],v);assert.deepEqual(await outside(),outsideBefore);raw('race-readback',{field,row,deleteResult:r});return {rowKept:true,actualDeleteWaiting:true,recheckField:field};}finally{release();await lock.catch(()=>{});if(work)await work.catch(()=>{});await block.$disconnect();block=undefined;}
   });await clear('race-'+field);
  }
  const actualNow=new RealDate();const actualRows=batch(actualNow).map(r=>r.createdAt.getTime()===actualNow.getTime()-30*86400000?{...r,createdAt:new RealDate(actualNow.getTime()-28*86400000)}:r);await seed(actualRows,'actual-clock-501-min-one-day-margin');
  raw('actual-pre-state',{referenceNow:actualNow,marginDays:1,eligible:501,queueJobAssetLeaseTicketOutboxEmpty:true,mediaEmpty:true,manualSweep:true,scheduler:false});
  for(let n=0;n<3;n++)await test(expected.cases[9+n],async()=>{await sweepGuard();assert.equal(globalThis.Date,RealDate);const r=await observe(()=>sweep(),'actual-sweep-'+n,new RealDate());assert(r.deleted.length<=500);assert.deepEqual(r.deleted.map((x:any)=>x.id),n===0?firstIds:n===1?[id(500)]:[]);const cutoffNow=new RealDate(RealDate.now()-expected.ttlMs);assert.equal(r.after.filter((x:any)=>x.actor==='worker'&&x.action==='worker.metrics'&&x.createdAt<cutoffNow).length,n===0?1:0);return {deleted:r.deleted.length,realClock:true};});
  await test(expected.cases[12],async()=>{await sweepGuard();assert.equal(counters.deniedDials+counters.deniedListens,0);return {models:outsideNames,nonemptySettingsPreserved:true,chargedBefore:37,chargedAfter:37,mediaEmpty:true,http:0,workerMain:false};});
  assert.deepEqual(results.map(r=>r.name),expected.cases);raw('summary',{cases:results.length,pass:results.filter(r=>r.result==='PASS').length,fail:results.filter(r=>r.result==='FAIL').length,skip:results.filter(r=>r.result==='SKIP').length,results});if(results.some(r=>r.result==='FAIL'))process.exitCode=1;
 }finally{
  globalThis.Date=RealDate;if(block)await block.$disconnect();
  if(core){const remaining=await core.db.auditLog.findMany();assert(remaining.every((r:any)=>owned.has(r.id)&&r.detail.marker==='p34'),'Foreign rows: no reset');await core.db.auditLog.deleteMany({where:{id:{in:[...owned]}}});if(outsideBefore){assert.deepEqual(await core.db.settings.findMany(),outsideBefore.settings);assert.deepEqual(await core.db.egressBudget.findMany(),outsideBefore.egressBudget);await core.db.settings.delete({where:{id:'main'}});await core.db.egressBudget.delete({where:{month:'p34-fixture'}});}await core.queue.close();const keys:string[]=await core.redis.keys('*');assert(keys.every(k=>k.startsWith('bull:media:')),'Foreign key');if(keys.length)await core.redis.del(...keys);for(const m of [...outsideNames,'auditLog'])assert.equal(await core.db[m].count(),0);assert.deepEqual(await core.redis.keys('*'),[]);if(mediaCreated){assert.equal(await realpath(core.mediaRoot),'/tmp/p34-media');const s=await lstat(core.mediaRoot);assert(s.isDirectory()&&!s.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);await rmdir(core.mediaRoot);}raw('cleanup',{removedOnlyOwnMarkerRows:remaining.length,modelsEmpty:true,keysEmpty:true,ownedKeysRemoved:keys.length,chargedPreservedUntilOwnFixtureCleanup:37,settingsRestoredToOriginalEmpty:true,mediaResolvedEmptyNonrecursiveRmdir:true,runtimeRetentionProof:false});await core.redis.quit();await core.db.$disconnect();}
  if(inspector)await inspector.quit();net.Socket.prototype.connect=connect;net.Server.prototype.listen=listen;raw('close',{hooksRestored:true,clientsClosed:true,http:0,counters});
 }
}
main().catch(e=>{raw('harness-failure',{type:e?.constructor?.name,message:String(e?.message).slice(0,1500),productionVerdict:false});process.exitCode=2;});
