import 'reflect-metadata';
import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,readlinkSync} from 'node:fs';
import {mkdir,readdir,realpath,lstat,rmdir} from 'node:fs/promises';
import http from 'node:http';
import expected from './expected.json';

const RealDate=Date,req=createRequire(__filename),privateValues=new Set<string>();
const digest=(s:string)=>createHash('sha256').update(s).digest('hex');
const privateValue=(s:string)=>{privateValues.add(s);return s;};
const mode=process.argv[2];
function raw(stage:string,data:any){const wall=new RealDate();const line=JSON.stringify({stage,mode,utc:wall.toISOString(),vn:new RealDate(wall.getTime()+25200000).toISOString().replace('Z','+07:00'),...data},(_k,v)=>typeof v==='bigint'?String(v):v);for(const s of privateValues)assert(!line.includes(s),'secret in raw');console.log('P31_RAW '+line);}
const pause=()=>new Promise<void>(r=>setTimeout(r,25));
async function until(fn:()=>Promise<boolean>,label:string){const end=performance.now()+5000;while(!await fn()){if(performance.now()>end)throw Error('Harness barrier deadline '+label);await pause();}}

async function main(){
 assert(mode==='baseline'||mode==='final');assert.equal(process.env.P31_GUARD,'wed-snap-ad-retention-lab');assert.equal(process.env.DATABASE_URL,'postgresql://p31@db:5432/wed_snap_ad_retention_test');assert.equal(process.env.REDIS_URL,'redis://redis:6379/12');assert.equal(process.env.MEDIA_ROOT,'/tmp/p31-media');assert.equal(process.env.APP_ORIGIN,'http://p31.invalid');assert.equal(process.env.COOKIE_SECURE,'false');assert.equal(process.env.ADMIN_SESSION_SECRET,'p31-unused-sentinel-replaced-in-memory');
 const coordinates=JSON.parse(readFileSync('/tmp/p31/coordinates.json','utf8'));
 const hashes=Object.fromEntries(coordinates.sources.map((p:string)=>[p,digest(readFileSync(p,'utf8'))]));
 assert.equal(digest(coordinates.sources.map((p:string)=>p+':'+hashes[p]).join('|')),coordinates.sourceSHA);assert.equal(coordinates.sourceSHA,process.env.P31_SOURCE_SHA);
 process.env.ADMIN_SESSION_SECRET=privateValue(randomBytes(32).toString('hex'));
 const net=req('node:net'),connect=net.Socket.prototype.connect,listen=net.Server.prototype.listen;
 let httpPort=0,listener:any,core:any,app:any,inspector:any,blockClient:any;
 const counters={redisDials:0,httpDials:0,listens:0,deniedDials:0,deniedListens:0};
 net.Socket.prototype.connect=function(...args:any[]){const a=Array.isArray(args[0])?args[0]:args,o=typeof a[0]==='object'?a[0]:{port:a[0],host:a[1]};if(Number(o.port)===6379&&['redis',coordinates.redisIP].includes(o.host)){counters.redisDials++;return connect.apply(this,args);}if(httpPort&&Number(o.port)===httpPort&&o.host==='127.0.0.1'){counters.httpDials++;return connect.apply(this,args);}counters.deniedDials++;throw Error('Foreign JS socket denied');};
 net.Server.prototype.listen=function(...args:any[]){const o=typeof args[0]==='object'?args[0]:{port:args[0],host:args[1]};if(listener||Number(o.port)!==0||o.host!=='127.0.0.1'){counters.deniedListens++;throw Error('Foreign listener denied');}listener=this;counters.listens++;return listen.apply(this,args);};
 const ownedEvents=new Set<string>(),campaignIds=new Set<string>();let mediaCreated=false,adminKey='';
 const results:any[]=[];let httpCount=0;
 try{
  const IORedis=req('ioredis');inspector=new IORedis(process.env.REDIS_URL,{maxRetriesPerRequest:1});assert(/\bdb=12\b/.test(String(await inspector.client('INFO'))));const redisInfo=String(await inspector.info('server'));assert(redisInfo.includes('run_id:'+coordinates.redisRun));assert.deepEqual(await inspector.keys('*'),[]);
  const {PrismaClient}=await import('@prisma/client');const preflight=new PrismaClient();
  try{const identity:any[]=await preflight.$queryRaw`SELECT current_database() AS database,host(inet_server_addr()) AS address,version() AS version,(SELECT system_identifier::text FROM pg_control_system()) AS cluster`;assert.equal(identity[0].database,'wed_snap_ad_retention_test');assert.equal(identity[0].address,coordinates.dbIP);assert.equal(identity[0].cluster,coordinates.cluster);raw('datastore-identity',{database:identity[0].database,numericAddressMatches:true,clusterMatches:true,postgres:identity[0].version,redisDb:12,redisRunMatches:true,redisVersion:/redis_version:([^\r\n]+)/.exec(redisInfo)?.[1]});}finally{await preflight.$disconnect();}
  core=await import('../../packages/shared/src/core');await core.queue.waitUntilReady();
  const outsideNames=['session','adminUser','downloadJob','mediaItem','temporaryAsset','transferLease','downloadTicket','egressBudget','settings','auditLog'];
  async function outside(){return Object.fromEntries(await Promise.all(outsideNames.map(async m=>[m,await core.db[m].findMany()])));}
  const outsideBefore=await outside();assert(Object.values(outsideBefore).every((x:any)=>x.length===0),'Only empty ownlab can run sweep');assert.equal(await core.db.adCampaign.count(),0);assert.equal(await core.db.adEvent.count(),0);
  await mkdir(core.mediaRoot,{recursive:false});mediaCreated=true;
  async function mediaGuard(){assert.equal(core.mediaRoot,'/tmp/p31-media');assert.equal(await realpath(core.mediaRoot),core.mediaRoot);const s=await lstat(core.mediaRoot);assert(s.isDirectory()&&!s.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);}
  await mediaGuard();
  const campaigns=[{id:randomUUID(),title:'p31-A'},{id:randomUUID(),title:'p31-zero'}];
  for(const c of campaigns){campaignIds.add(c.id);await core.db.adCampaign.create({data:{...c,enabled:false,targetUrl:'https://fixture.example.invalid/p31',startsAt:new RealDate('2025-01-01T00:00:00Z'),endsAt:new RealDate('2027-01-01T00:00:00Z')}});}
  const campaignBefore=await core.db.adCampaign.findMany({orderBy:{id:'asc'}});
  const {sweep}=await import('../../apps/worker/src/lifecycle');
  const helper=mode==='final'?(await import('../../apps/worker/src/ad-event-retention')).purgeAdEvents:undefined;
  async function sweepGuard(){await mediaGuard();assert.deepEqual(await outside(),outsideBefore);assert.equal(await core.queue.getWaitingCount(),0);assert.equal(await core.queue.getActiveCount(),0);assert.deepEqual(await core.db.adCampaign.findMany({orderBy:{id:'asc'}}),campaignBefore);}
  async function events(){const rows=await core.db.adEvent.findMany({orderBy:[{createdAt:'asc'},{id:'asc'}],take:515});if(rows.length>510)throw Error('Fixture row bound');return rows;}
  async function seed(rows:any[],name:string){assert.equal(await core.db.adEvent.count(),0);for(const r of rows)ownedEvents.add(r.id);await core.db.adEvent.createMany({data:rows.map(r=>({...r,campaignId:campaigns[0].id}))});raw('seed',{name,clock:expected.clock,cutoff:expected.cutoff,rows,expectedFromSeed:true});}
  async function clearEvents(name:string){const rows=await events();assert(rows.every((r:any)=>ownedEvents.has(r.id)&&campaignIds.has(r.campaignId)));const n=await core.db.adEvent.deleteMany({where:{id:{in:[...ownedEvents]}}});assert.equal(await core.db.adEvent.count(),0);raw('scenario-fixture-cleanup',{name,removedOwnRows:n.count,runtimeRetentionProof:false});}
  async function invoke(now:Date){
   if(helper)return helper(now);
   // Baseline runs the unmodified production sweep; only clock construction is controlled.
   await sweepGuard();class ClockDate extends RealDate{constructor(value?:string|number|Date){super(value===undefined?now.getTime():value instanceof RealDate?value.getTime():value);}static now(){return now.getTime();}}
   globalThis.Date=ClockDate as DateConstructor;
   try{await sweep();return undefined;}finally{globalThis.Date=RealDate;}
  }
  async function observe(call:()=>Promise<any>,name:string){const before=await events();const started=performance.now();const returned=await call();const after=await events();const remaining=new Set(after.map((r:any)=>r.id));const deleted=before.filter((r:any)=>!remaining.has(r.id)).map((r:any)=>r.id);if(returned)assert.equal(returned.count,deleted.length);const record={name,returned,ms:performance.now()-started,beforeCount:before.length,afterCount:after.length,deletedIds:deleted,deletedCount:deleted.length,retainedRows:after};raw('retention-observation',record);return record;}
  async function test(name:string,fn:()=>Promise<any>){try{const evidence=await fn();results.push({name,result:'PASS',evidence});}catch(e){if(!(e instanceof assert.AssertionError))throw e;results.push({name,result:'FAIL',category:'observed-production-constraint',error:e.message});}raw('case',results.at(-1));}
  raw('environment',{sourceSHA:coordinates.sourceSHA,hashes,expectedSHA:digest(readFileSync('tests/p31/expected.json','utf8')),testSHA:digest(readFileSync('tests/p31/retention.ts','utf8')),node:process.version,namespace:readlinkSync('/proc/self/ns/pid'),versions:Object.fromEntries(['@nestjs/core','@prisma/client','ioredis','bullmq','typescript'].map(p=>[p,req(p+'/package.json').version])),media:{path:core.mediaRoot,newPrivateTmpfsChild:true,empty:true},outsideBefore,stubs:mode==='baseline'?['Global Date constructor/now controlled only around unmodified sweep for deterministic boundaries/batch; restored in finally']:['Explicit now parameter of production helper for deterministic boundaries/batch'],actualSweep:'Real clock, margin seeds, no worker main/scheduler/jobs',nativePrisma:'Not covered by JS socket counter; numeric DB/cluster identity guarded'});
  const clock=new RealDate(expected.clock),cutoff=new RealDate(expected.cutoff);
  const boundary=[...expected.types.map((type,i)=>({id:randomUUID(),type,createdAt:new RealDate(cutoff.getTime()-1),role:'expired-'+i})),...expected.types.map((type,i)=>({id:randomUUID(),type,createdAt:cutoff,role:'exact-'+i})),{id:randomUUID(),type:'impression',createdAt:new RealDate(cutoff.getTime()+1),role:'after'},{id:randomUUID(),type:'click',createdAt:new RealDate(clock.getTime()+86400000),role:'future'}];
  await seed(boundary.map(({role,...r})=>r),'boundary-eight');
  await test('strict-boundary-all-types',async()=>{const r=await observe(()=>invoke(clock),'boundary');assert.equal(r.deletedCount,expected.boundaryDeleted);assert.deepEqual([...r.deletedIds].sort(),boundary.slice(0,3).map(x=>x.id).sort());assert.equal(r.afterCount,expected.boundaryRetained);assert.deepEqual(r.retainedRows.map((x:any)=>x.id).sort(),boundary.slice(3).map(x=>x.id).sort());return {deleted:r.deletedCount,retained:r.afterCount,cutoff:expected.cutoff,allTypes:true};});
  await test('boundary-repeat-idempotent',async()=>{const before=await events();const r=await observe(()=>invoke(clock),'boundary-repeat');assert.equal(r.deletedCount,0);assert.deepEqual(await events(),before);return {noEffects:true};});
  await clearEvents('boundary');
  const id=(i:number)=>'00000000-0000-4000-8000-'+String(i).padStart(12,'0');
  const oldestId='ffffffff-ffff-4fff-8fff-ffffffffffff';
  function batch(older:Date,tie:Date,kept:Date){return [{id:oldestId,type:'impression',createdAt:older},...Array.from({length:500},(_,i)=>({id:id(i+1),type:expected.types[(i+1)%3],createdAt:tie})),...Array.from({length:5},(_,i)=>({id:'11111111-1111-4111-8111-'+String(i).padStart(12,'0'),type:'unknown',createdAt:new RealDate(kept.getTime()+i*86400000)}))].reverse();}
  const firstIds=[oldestId,...Array.from({length:499},(_,i)=>id(i+1))];
  await seed(batch(new RealDate(cutoff.getTime()-2*86400000),new RealDate(cutoff.getTime()-1),cutoff),'deterministic-501-plus-five-kept');
  // Real Nest/auth/Redis/Prisma HTTP, not a business response fixture or login rerun.
  const {NestFactory}=await import('@nestjs/core');const {AppModule}=await import('../../apps/api/src/app.module');const {SafeErrors}=await import('../../apps/api/src/filters/safe-errors.filter');const {clientIdentityMiddleware}=await import('../../apps/api/src/security/client-ip');const auth=await import('../../apps/api/src/auth/session');
  const token=privateValue(randomBytes(32).toString('hex')),cookie=privateValue(token+'.'+auth.sign(token));adminKey='admin:'+core.hash(token);await core.redis.set(adminKey,'p31-own-fixture-actor','EX',600);
  app=await NestFactory.create(AppModule,{logger:false});app.getHttpAdapter().getInstance().set('trust proxy',false);app.use(clientIdentityMiddleware());app.use(req('helmet')({contentSecurityPolicy:false}));app.use(req('cookie-parser')());app.useGlobalFilters(new SafeErrors());app.use((r:any,res:any,next:any)=>{res.set('Cache-Control','no-store');if(r.method!=='GET'||!r.url.startsWith('/api/v1/admin/ad-statistics?')){res.status(403).end();return;}next();});await app.listen(0,'127.0.0.1');httpPort=app.getHttpServer().address().port;
  const query=new URLSearchParams({from:new RealDate(cutoff.getTime()-3*86400000).toISOString(),to:new RealDate(clock.getTime()+2*86400000).toISOString()});
  async function stats(adminCookie:boolean){if(++httpCount>6)throw Error('HTTP bound');const start=performance.now();return new Promise<any>((resolve,reject)=>{const request=http.request({hostname:'127.0.0.1',port:httpPort,path:'/api/v1/admin/ad-statistics?'+query,method:'GET',agent:false,headers:adminCookie?{Cookie:'ws_admin='+cookie}:{}},res=>{let body='';res.on('data',c=>{body+=c;if(Buffer.byteLength(body)>65536)request.destroy(Error('Response bound'));});res.on('end',()=>{try{const data=JSON.parse(body);const evidence={num:httpCount,method:'GET',path:'/api/v1/admin/ad-statistics?'+query,status:res.statusCode,adminCookie,guestCookie:false,csrfHeader:false,noStore:res.headers['cache-control']==='no-store',nosniff:res.headers['x-content-type-options']==='nosniff',setCookie:!!res.headers['set-cookie'],ms:performance.now()-start,response:data};raw('http',evidence);resolve(evidence);}catch(e){reject(e);}});});request.setTimeout(5000,()=>request.destroy(Error('HTTP deadline')));request.on('error',reject);request.end();});}
  async function checkStats(wanted:any,withAuthGuard:boolean){const before=await events(),other=await outside();if(withAuthGuard){const denied=await stats(false);assert.equal(denied.status,403);assert.equal(denied.response.error.code,'ADMIN_REQUIRED');}const r=await stats(true);assert.equal(r.status,200);assert(r.noStore&&r.nosniff&&!r.setCookie);assert.deepEqual(r.response.window,{from:query.get('from'),to:query.get('to'),timezone:'UTC'});const row=r.response.rows.find((x:any)=>x.campaignId===campaigns[0].id),zero=r.response.rows.find((x:any)=>x.campaignId===campaigns[1].id);assert.deepEqual({impressions:row.impressions,clicks:row.clicks,ctrPercent:row.ctrPercent},wanted);assert.deepEqual({impressions:zero.impressions,clicks:zero.clicks,ctrPercent:zero.ctrPercent},{impressions:0,clicks:0,ctrPercent:null});assert.deepEqual(await events(),before);assert.deepEqual(await outside(),other);const retained=before.filter((x:any)=>x.createdAt>=new RealDate(query.get('from')!)&&x.createdAt<new RealDate(query.get('to')!));assert.equal(row.impressions,retained.filter((x:any)=>x.type==='impression').length);assert.equal(row.clicks,retained.filter((x:any)=>x.type==='click').length);return {wanted,window:r.response.window,retainedRawRows:retained.length,guard:withAuthGuard,getNoEffects:true};}
  await test('http-admin-before',()=>checkStats(expected.batchStatsBefore,true));
  await test('batch-first500-stable-order',async()=>{const r=await observe(()=>invoke(clock),'batch-first');assert.equal(r.deletedCount,expected.batchFirstDeleted);assert(r.deletedCount<=expected.maxBatch);assert.deepEqual(r.deletedIds,firstIds);assert(r.retainedRows.some((x:any)=>x.id===id(500)));assert.equal(r.afterCount,6);return {deleted:500,eligibleResidual:1,olderFirst:true,timestampTieOrder:true};});
  await test('http-retained-after-first',()=>checkStats(expected.batchStatsAfterFirst,false));
  await test('batch-second-remainder1',async()=>{const r=await observe(()=>invoke(clock),'batch-second');assert.equal(r.deletedCount,expected.batchSecondDeleted);assert.deepEqual(r.deletedIds,[id(500)]);assert.equal(r.afterCount,5);return {deleted:1,eligibleResidual:0};});
  await test('batch-no-eligible-idempotent',async()=>{const before=await events();const r=await observe(()=>invoke(clock),'batch-third');assert.equal(r.deletedCount,expected.batchThirdDeleted);assert.deepEqual(await events(),before);return {noEffects:true};});
  await clearEvents('deterministic-batch');
  await test('same-cutoff-row-lock-recheck',async()=>{
   const eventId=randomUUID();await seed([{id:eventId,type:'unknown',createdAt:new RealDate(cutoff.getTime()-86400000)}],'row-recheck');blockClient=new PrismaClient();let release!:()=>void,entered!:()=>void,pid=0;const held=new Promise<void>(r=>release=r),started=new Promise<void>(r=>entered=r);
   const lock=blockClient.$transaction(async(tx:any)=>{pid=(await tx.$queryRaw`SELECT pg_backend_pid() AS pid`)[0].pid;await tx.adEvent.update({where:{id:eventId},data:{createdAt:new RealDate(clock.getTime())}});entered();await held;},{timeout:10000});
   let work:Promise<any>|undefined,waiters:any[]=[];
   try{await started;work=invoke(clock);await until(async()=>{waiters=await core.db.$queryRaw`SELECT pid,wait_event_type,pg_blocking_pids(pid) AS blockers FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND ${pid} = ANY(pg_blocking_pids(pid)) AND query LIKE '%DELETE%' AND query LIKE '%AdEvent%'`;return waiters.length>0;},'actual DELETE waiting on own row-update transaction');raw('row-lock-barrier',{ownBlockerPid:pid,waiters,uncommittedFreshTimestamp:clock.toISOString(),observedDeleteWait:true});release();await lock;const r=await work;const row=await core.db.adEvent.findUniqueOrThrow({where:{id:eventId}});assert.equal(row.createdAt.toISOString(),clock.toISOString());if(r)assert.equal(r.count,0);return {rowKept:eventId,newTimestamp:row.createdAt,deleteReturned:r,lockWaitObserved:true};}
   finally{release();await lock.catch(()=>{});if(work)await work.catch(()=>{});await blockClient.$disconnect();blockClient=undefined;}
  });
  await clearEvents('row-recheck');
  const actualBase=new RealDate();await seed(batch(new RealDate(actualBase.getTime()-32*86400000),new RealDate(actualBase.getTime()-31*86400000),new RealDate(actualBase.getTime()-29*86400000)),'actual-clock-501-one-day-margins');
  raw('actual-pre-state',{realClock:true,marginDays:1,eligible:501,kept:5,workerMain:false,scheduler:false,jobLeaseTicketOutboxEmpty:true,mediaEmpty:true,referenceNow:actualBase});
  await test('actual-sweep-first500',async()=>{await sweepGuard();assert.equal(globalThis.Date,RealDate);const r=await observe(()=>sweep(),'actual-sweep-first');assert.equal(r.deletedCount,500);assert.deepEqual(r.deletedIds,firstIds);assert.equal(r.afterCount,6);return {realClock:true,deleted:500,residual:1};});
  await test('actual-sweep-second1',async()=>{await sweepGuard();const r=await observe(()=>sweep(),'actual-sweep-second');assert.equal(r.deletedCount,1);assert.deepEqual(r.deletedIds,[id(500)]);assert.equal(r.afterCount,5);return {realClock:true,deleted:1};});
  await test('actual-sweep-idempotent',async()=>{await sweepGuard();const before=await events();const r=await observe(()=>sweep(),'actual-sweep-third');assert.equal(r.deletedCount,0);assert.deepEqual(await events(),before);return {realClock:true,noEffects:true};});
  await test('outside-models-media-no-effects',async()=>{await sweepGuard();assert.deepEqual(await outside(),outsideBefore);assert.equal(counters.deniedDials+counters.deniedListens,0);return {outsideModels:outsideNames,baselineEmpty:true,settingsBudgetChargedAuditUntouched:true,mediaEmpty:true,campaignsUnchanged:true};});
  assert.deepEqual(results.map(r=>r.name),expected.cases);
  raw('summary',{cases:results.length,pass:results.filter(r=>r.result==='PASS').length,fail:results.filter(r=>r.result==='FAIL').length,httpCount,results});if(results.some(r=>r.result==='FAIL'))process.exitCode=1;
 }finally{
  globalThis.Date=RealDate;
  if(app){await app.close();app=undefined;raw('http-close',{closed:true});}
  if(blockClient)await blockClient.$disconnect();
  if(core){
   const remaining=await core.db.adEvent.findMany();assert(remaining.every((r:any)=>ownedEvents.has(r.id)&&campaignIds.has(r.campaignId)),'Foreign fixture row; do not reset');const before={events:remaining.length,campaigns:await core.db.adCampaign.count()};assert.equal(before.campaigns,campaignIds.size);
   await core.db.$transaction(async(tx:any)=>{await tx.adEvent.deleteMany({where:{id:{in:[...ownedEvents]}}});await tx.adCampaign.deleteMany({where:{id:{in:[...campaignIds]}}});});
   await core.queue.close();const keys=await core.redis.keys('*');assert(keys.every((k:string)=>k===adminKey||k.startsWith('bull:media:')),'Foreign Redis key');if(keys.length)await core.redis.del(...keys);
   assert.equal(await core.db.adEvent.count(),0);assert.equal(await core.db.adCampaign.count(),0);for(const model of ['session','adminUser','downloadJob','mediaItem','temporaryAsset','transferLease','downloadTicket','egressBudget','settings','auditLog'])assert.equal(await core.db[model].count(),0);
   assert.deepEqual(await core.redis.keys('*'),[]);
   if(mediaCreated){assert.equal(await realpath(core.mediaRoot),'/tmp/p31-media');const s=await lstat(core.mediaRoot);assert(s.isDirectory()&&!s.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);await rmdir(core.mediaRoot);raw('media-cleanup',{verifiedResolvedOwnPath:true,emptyBeforeRmdir:true,recursive:false});}
   raw('cleanup',{before,fixtureRowsAfter:0,settingsBefore:[],settingsAfter:[],budgetBefore:[],budgetAfter:[],chargedWrites:0,ownedKeysRemoved:keys.length,requestCount:httpCount,keptMain:true});await core.redis.quit();await core.db.$disconnect();
  }
  if(inspector)await inspector.quit();net.Socket.prototype.connect=connect;net.Server.prototype.listen=listen;raw('close',{httpClosed:!app,datastoreClientsClosed:true,hooksRestored:true,counters});
 }
}
main().catch(e=>{let message=String(e?.message||'failure');for(const s of privateValues)message=message.split(s).join('[REDACTED]');raw('harness-failure',{type:e?.constructor?.name,message:message.slice(0,1500),productionVerdict:false});process.exitCode=2;});
