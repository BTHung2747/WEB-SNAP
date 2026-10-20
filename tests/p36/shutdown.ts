import assert from 'node:assert/strict';
import {createHash, randomUUID, randomBytes} from 'node:crypto';
import {spawn, ChildProcess} from 'node:child_process';
import {createRequire} from 'node:module';
import {readFileSync, readlinkSync} from 'node:fs';
import {mkdir, realpath, lstat, readdir, rmdir} from 'node:fs/promises';
import expected from './expected.json';

const req=createRequire(__filename);
const hash=(b:string)=>createHash('sha256').update(b).digest('hex');
const pause=(ms:number)=>new Promise<void>(resolve=>setTimeout(resolve,ms));
const results:any[]=[];
let rawCount=0, failure:any;
function raw(stage:string,data:any) {
  assert(++rawCount<1000,'Observation bound');
  const now=new Date();
  console.log('P36_RAW '+JSON.stringify({stage,utc:now.toISOString(),vn:new Date(now.getTime()+25200000).toISOString().replace('Z','+07:00'),monoMs:performance.now(),...data},(_k,v)=>typeof v==='bigint'?String(v):v));
}
async function check(index:number,fn:()=>Promise<any>,fatal=false) {
  try {const evidence=await fn();results.push({name:expected.cases[index],result:'PASS',evidence});}
  catch(error) {failure ||= error;results.push({name:expected.cases[index],result:'FAIL',message:String((error as Error).message).slice(0,1800)});raw('case',results.at(-1));if(fatal)throw error;return false;}
  raw('case',results.at(-1));return true;
}
async function until(fn:()=>Promise<boolean>,label:string,ms=expected.waitDeadlineMs,sampleMs=expected.sampleMs) {
  const end=performance.now()+ms;let count=0;
  while(!await fn()) {assert(performance.now()<end,'Observation deadline: '+label);assert(++count<1000,'Poll bound');await pause(sampleMs);}
}
async function main() {
  assert.equal(process.env.P36_GUARD,'wed-snap-worker-shutdown-lab');
  const baseURL=process.env.DATABASE_URL!;
  assert.equal(baseURL,'postgresql://p36@db:5432/wed_snap_worker_shutdown_test');
  assert.equal(process.env.REDIS_URL,'redis://redis:6379/9');
  assert.equal(process.env.MEDIA_ROOT,'/tmp/p36-media');assert.equal(process.env.SWEEP_SECONDS,'2');
  const coordinates=JSON.parse(readFileSync('/tmp/p36/coordinates.json','utf8'));
  const hashes=Object.fromEntries(coordinates.sources.map((p:string)=>[p,hash(readFileSync(p,'utf8'))]));
  assert.equal(hash(coordinates.sources.map((p:string)=>p+':'+hashes[p]).join('|')),coordinates.sourceSHA);
  assert.equal(coordinates.sourceSHA,process.env.P36_SOURCE_SHA);
  assert(/sweepSeconds: num\('SWEEP_SECONDS', 30\)/.test(readFileSync('packages/shared/src/core.ts','utf8')));
  assert(/concurrency: 1/.test(readFileSync('apps/worker/src/main.ts','utf8')));
  const namespace=readlinkSync('/proc/self/ns/pid'),appEnv={...process.env,DATABASE_URL:baseURL};
  let core:any,inspector:any,locks:any,parentPid=0,mediaCreated=false,settingsSeeded=false,budgetSeeded=false;
  let child:ChildProcess|undefined,childIdentity:any,childExit:any,childLabel='',stdout='',stderr='',ready:any;
  let exitPromise:Promise<any>,outsideBefore:any,protectedAudits:any[],campaignBefore:any,freshEvent:any;
  let expiredId='',freshId='',freshSession:any;
  const ownedAudits=new Set<string>(),ownedEvents=new Set<string>(),ownedCampaigns=new Set<string>(),ownedSessions=new Set<string>();
  const outsideNames=['adminUser','downloadJob','mediaItem','temporaryAsset','transferLease','downloadTicket','settings','egressBudget'];
  const latches:any[]=[];
  function procIdentity(pid:number) {
    const root='/proc/'+pid,stat=readFileSync(root+'/stat','utf8');
    const fields=stat.slice(stat.lastIndexOf(')')+2).trim().split(/\s+/);
    return {pid,startTicks:fields[19],namespace:readlinkSync(root+'/ns/pid'),exe:readlinkSync(root+'/exe'),argv:readFileSync(root+'/cmdline').toString().split('\0').filter(Boolean)};
  }
  function signalOwn(signal:NodeJS.Signals,label:string) {
    assert(child?.pid&&childIdentity&&!childExit,'Only live own child');
    const identity=procIdentity(child.pid);assert.deepEqual(identity,childIdentity);assert.equal(identity.namespace,namespace);
    assert.equal(identity.exe,process.execPath);assert.deepEqual(identity.argv,[process.execPath,...expected.childArgv]);
    const at=performance.now();raw('signal',{childLabel,label,signal,identity,guarded:true,signalAt:at});assert(child.kill(signal));return at;
  }
  function startChild(label:string) {
    assert(!child||childExit,'Previous child must exit');childLabel=label;childExit=undefined;ready=undefined;stdout='';stderr='';
    child=spawn(process.execPath,expected.childArgv,{cwd:'/app',env:appEnv,stdio:['ignore','pipe','pipe']});assert(child.pid);
    childIdentity=procIdentity(child.pid);assert.equal(childIdentity.namespace,namespace);assert.deepEqual(childIdentity.argv,[process.execPath,...expected.childArgv]);
    exitPromise=new Promise((resolve,reject)=>{child!.once('error',reject);child!.once('exit',(code,signal)=>{childExit={childLabel:label,code,signal,at:performance.now(),utc:new Date().toISOString()};raw('child-exit',childExit);resolve(childExit);});});exitPromise.catch(()=>{});
    function output(kind:string,chunk:Buffer) {
      const value=chunk.toString();if(kind==='stdout')stdout+=value;else stderr+=value;
      assert(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)<32768,'Child output bound');raw('child-output',{childLabel:label,kind,chunk:value});
      for(const line of stdout.split('\n')) {let event:any;try{event=JSON.parse(line);}catch{}if(event?.event==='worker_ready'&&!ready){ready={...event,at:performance.now(),utc:new Date().toISOString()};raw('worker-ready',{childLabel:label,...ready});}}
    }
    child.stdout!.on('data',chunk=>output('stdout',chunk));child.stderr!.on('data',chunk=>output('stderr',chunk));
    raw('child-spawn',{childLabel:label,identity:childIdentity,argv:expected.childArgv,sourceSHA:coordinates.sourceSHA});
  }
  async function latch(label:string,sql:(tx:any)=>Promise<any>) {
    let open!:()=>void,entered!:()=>void;
    const hold=new Promise<void>(r=>open=r),start=new Promise<void>(r=>entered=r);
    const handle:any={label,pid:0,released:false,open,done:undefined};latches.push(handle);
    handle.done=locks.$transaction(async(tx:any)=>{handle.pid=(await tx.$queryRaw`SELECT pg_backend_pid() AS pid`)[0].pid;await sql(tx);entered();await hold;},{timeout:expected.lockDeadlineMs,maxWait:5000});handle.done.catch(()=>{});
    await Promise.race([start,handle.done.then(()=>{throw Error('Latch ended before acquired');})]);raw('pg-lock-acquired',{label,pid:handle.pid,deadlineMs:expected.lockDeadlineMs});return handle;
  }
  async function release(handle:any) {if(!handle.released){raw('pg-lock-release-start',{label:handle.label,pid:handle.pid});handle.released=true;handle.open();await handle.done;raw('pg-lock-released',{label:handle.label,pid:handle.pid});}}
  try {
    const Redis=req('ioredis');inspector=new Redis(process.env.REDIS_URL,{maxRetriesPerRequest:1});
    assert(/\bdb=9\b/.test(String(await inspector.client('INFO'))));assert(String(await inspector.info('server')).includes('run_id:'+coordinates.redisRun));assert.deepEqual(await inspector.keys('*'),[]);
    // Pool-only observation fixture; production methods and original child DSN remain real.
    process.env.DATABASE_URL=baseURL+'?connection_limit=1&connect_timeout=5&pool_timeout=5';
    core=await import('../../packages/shared/src/core');await core.db.$connect();process.env.DATABASE_URL=baseURL;await core.queue.waitUntilReady();
    const identity=(await core.db.$queryRaw`SELECT current_database() AS database,host(inet_server_addr()) AS address,(SELECT system_identifier::text FROM pg_control_system()) AS cluster,pg_backend_pid() AS pid,version() AS version`)[0];
    assert.equal(identity.database,'wed_snap_worker_shutdown_test');assert.equal(identity.address,coordinates.dbIP);assert.equal(identity.cluster,coordinates.cluster);parentPid=identity.pid;
    async function outside() {const value:any={};for(const model of outsideNames)value[model]=await core.db[model].findMany({orderBy:model==='egressBudget'?{month:'asc'}:{id:'asc'}});return value;}
    async function audits() {return core.db.auditLog.findMany({orderBy:[{createdAt:'asc'},{id:'asc'}],take:1020});}
    async function eligibleIds() {return (await audits()).filter((r:any)=>r.actor==='worker'&&r.action==='worker.metrics'&&r.createdAt.getTime()<Date.now()-30*86400000).map((r:any)=>r.id);}
    const sessionSelect={id:true,createdAt:true,expiresAt:true};
    async function sessions() {return core.db.session.findMany({select:sessionSelect,orderBy:{id:'asc'}});}
    async function mediaGuard() {assert.equal(await realpath(core.mediaRoot),'/tmp/p36-media');const stat=await lstat(core.mediaRoot);assert(stat.isDirectory()&&!stat.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);}
    async function emptyJobGuard() {for(const model of ['downloadJob','mediaItem','temporaryAsset','transferLease','downloadTicket'])assert.equal(await core.db[model].count(),0);for(const state of ['Waiting','Active','Delayed','Failed','Completed'])assert.equal(await core.queue['get'+state+'Count'](),0);await mediaGuard();}
    async function childActivity() {const data:any[]=await core.db.$queryRaw`SELECT pid,state,wait_event_type,wait_event,query,query_start,state_change,pg_blocking_pids(pid) AS blockers FROM pg_stat_activity WHERE datname=current_database() AND backend_type='client backend' AND pid<>${parentPid} ORDER BY pid`;return data.filter(p=>!latches.some(h=>h.pid===p.pid));}
    async function redisClients() {return String(await inspector.client('LIST')).trim().split('\n').filter(Boolean).map(line=>Object.fromEntries(line.split(' ').map(x=>x.split('=',2)))).filter(c=>c.db==='9').map(c=>({id:c.id,db:c.db,cmd:c.cmd,name:c.name,flags:c.flags}));}
    assert(Object.values(await outside()).every((value:any)=>value.length===0));for(const model of ['session','auditLog','adEvent','adCampaign'])assert.equal(await core.db[model].count(),0);
    await mkdir(core.mediaRoot,{recursive:false});mediaCreated=true;
    await check(0,async()=>{await emptyJobGuard();assert.equal(core.defaults.sweepSeconds,2);assert.equal((await core.limits()).sweepSeconds,2);raw('preflight',{identity,redisDb:9,redisRunMatch:true,namespace,sourceSHA:coordinates.sourceSHA,hashes,effectiveSeconds:2,sourceDefaultSeconds:30,expectedSHA:hash(readFileSync('tests/p36/expected.json','utf8')),testSHA:hash(readFileSync('tests/p36/shutdown.ts','utf8')),node:process.version,versions:Object.fromEntries(['@prisma/client','ioredis','bullmq','typescript','tsx'].map(p=>[p,req(p+'/package.json').version])),doubles:expected.doubles});return {empty:true,effectiveSeconds:2,sourceDefaultSeconds:30};},true);
    const reference=new Date(),oldestDate=new Date(reference.getTime()-32*86400000),oldDate=new Date(reference.getTime()-31*86400000),freshDate=new Date(reference.getTime()-29*86400000);
    const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0'),oldest='ffffffff-ffff-4fff-8fff-ffffffffffff';
    const metricRows=[{id:oldest,actor:'worker',action:'worker.metrics',createdAt:oldestDate},...Array.from({length:1000},(_,n)=>({id:id(n+1),actor:'worker',action:'worker.metrics',createdAt:oldDate}))];
    const keepRows=[{id:randomUUID(),actor:'worker',action:'worker.metrics',createdAt:freshDate},{id:randomUUID(),actor:'worker',action:'worker.metrics',createdAt:new Date(reference.getTime()+86400000)},{id:randomUUID(),actor:'p36-other',action:'worker.metrics',createdAt:oldestDate},{id:randomUUID(),actor:'worker',action:'worker.other',createdAt:oldestDate},...['settings.update','campaign.create','campaign.update','campaign.delete'].map(action=>({id:randomUUID(),actor:'p36-admin',action,createdAt:oldestDate}))];
    const rows=[...metricRows,...keepRows].reverse().map(row=>({...row,detail:{marker:'p36',id:row.id}}));for(const row of rows)ownedAudits.add(row.id);await core.db.auditLog.createMany({data:rows});protectedAudits=(await audits()).filter((r:any)=>keepRows.some(k=>k.id===r.id));
    const campaignId=randomUUID();ownedCampaigns.add(campaignId);await core.db.adCampaign.create({data:{id:campaignId,title:'p36-own-disabled',enabled:false,targetUrl:'https://fixture.example.invalid/p36',startsAt:oldestDate,endsAt:new Date(reference.getTime()+86400000)}});campaignBefore=await core.db.adCampaign.findMany();
    const oldEventId=randomUUID(),freshEventId=randomUUID();ownedEvents.add(oldEventId);ownedEvents.add(freshEventId);await core.db.adEvent.createMany({data:[{id:oldEventId,campaignId,type:'impression',createdAt:oldDate},{id:freshEventId,campaignId,type:'click',createdAt:freshDate}]});freshEvent=await core.db.adEvent.findUniqueOrThrow({where:{id:freshEventId}});
    await core.db.settings.create({data:{id:'main',value:core.defaults}});settingsSeeded=true;await core.db.egressBudget.create({data:{month:'p36-fixture',charged:37n}});budgetSeeded=true;outsideBefore=await outside();
    const firstIds=[oldest,...Array.from({length:499},(_,n)=>id(n+1))],secondIds=Array.from({length:500},(_,n)=>id(n+500)),beforeAudits=await audits();
    raw('seed',{reference,eligibleIds:metricRows.map(r=>r.id),protectedAudits,expectedStartup:firstIds,expectedPeriodic:secondIds,expectedAtShutdown:[id(1000)],settings:outsideBefore.settings,budget:outsideBefore.egressBudget,adEvents:await core.db.adEvent.findMany(),campaigns:campaignBefore});
    const {PrismaClient}=await import('@prisma/client');locks=new PrismaClient({datasources:{db:{url:baseURL+'?connection_limit=3&connect_timeout=5&pool_timeout=5'}}});
    const startup=await latch('startup-after-metrics-before-ready',tx=>tx.$executeRaw`LOCK TABLE "DownloadTicket" IN SHARE MODE`);
    const periodic=await latch('periodic-row500-outside-startup',tx=>tx.$queryRaw`SELECT id FROM "AuditLog" WHERE id=${id(500)} FOR UPDATE`);
    const redisBefore=await redisClients();startChild('inflight');
    async function preserve(label:string) {await emptyJobGuard();assert.deepEqual(await outside(),outsideBefore);assert.deepEqual(await core.db.adCampaign.findMany(),campaignBefore);assert.deepEqual(await core.db.adEvent.findMany(),[freshEvent]);const all=await audits();for(const row of protectedAudits)assert.deepEqual(all.find((r:any)=>r.id===row.id),row);if(freshId)assert.deepEqual(await core.db.session.findUnique({where:{id:freshId},select:sessionSelect}),freshSession);raw('preservation',{label,charged:37,settingsUnchanged:true,protectedAudits:all.filter((r:any)=>keepRows.some(k=>k.id===r.id)),sessions:await sessions(),freshAdEvent:await core.db.adEvent.findMany(),jobsEmpty:true});}
    async function diff(label:string,before:any[],wanted:string[],remaining:number) {const after=await audits(),ids=new Set(after.map((r:any)=>r.id)),deleted=before.filter((r:any)=>!ids.has(r.id)).map((r:any)=>r.id),eligible=await eligibleIds();raw('db-phase',{label,childLabel,beforeCount:before.length,afterCount:after.length,deletedIds:deleted,retainedIds:after.map((r:any)=>r.id),eligibleIds:eligible,wantedDeletedIds:wanted,remainingExpected:remaining,childAlreadyExited:!!childExit,workerReady:!!ready});assert.deepEqual(deleted,wanted);assert.equal(eligible.length,remaining);await preserve(label);return after;}
    let afterStartup:any[]=[],periodicPg:any[]=[],signalAt=0,allReleasedAt=0,tailObserved=false,tailSnapshot:any;
    await check(1,async()=>{await until(async()=>{assert(!childExit,'Startup child exited');return (await childActivity()).some(p=>p.query.includes('DELETE')&&p.query.includes('DownloadTicket')&&p.blockers.includes(startup.pid));},'startup500 latch');assert(!ready);afterStartup=await diff('startup-precondition-before-ready',beforeAudits,firstIds,501);assert.equal(await core.db.adEvent.count({where:{id:oldEventId}}),0);raw('startup-precondition',{pg:await childActivity(),blocker:startup.pid,ready:false,eligible:501});return {deleted:500,eligible:501,ready:false};},true);
    await release(startup);
    let tail:any;
    await check(2,async()=>{await until(async()=>!!ready,'worker ready');assert.equal(ready.concurrency,1);await until(async()=>(await core.queue.getWorkers()).length===1,'actual worker registered');expiredId=randomUUID();freshId=randomUUID();ownedSessions.add(expiredId);ownedSessions.add(freshId);const now=new Date();await core.db.session.createMany({data:[{id:expiredId,csrf:randomBytes(32).toString('hex'),expiresAt:new Date(now.getTime()-3600000)},{id:freshId,csrf:randomBytes(32).toString('hex'),expiresAt:new Date(now.getTime()+86400000)}]});freshSession=await core.db.session.findUniqueOrThrow({where:{id:freshId},select:sessionSelect});raw('session-witness-seeded-after-ready',{ready,expiredId,freshId,sessions:await sessions(),jobs:0,redacted:['csrf']});tail=await latch('tail-session-table-after-ready',tx=>tx.$executeRaw`LOCK TABLE "Session" IN SHARE MODE`);await until(async()=>{assert(!childExit);periodicPg=(await childActivity()).filter(p=>p.query.includes('DELETE')&&p.query.includes('AuditLog')&&p.blockers.includes(periodic.pid));return periodicPg.length===1;},'periodic DELETE after ready');assert.equal((await eligibleIds()).length,501);assert.equal(await core.db.session.count({where:{id:expiredId}}),1);raw('periodic-blocked',{ready,pg:periodicPg,blocker:periodic.pid,tailBlocker:tail.pid,sessions:await sessions(),eligible:501});return {afterReady:true,eligible:501,expiredWitnessPresent:true};},true);
    signalAt=signalOwn('SIGTERM','periodic-inflight-test');
    await check(3,async()=>{let samples=0;while(performance.now()-signalAt<expected.observeHoldMs){const pg=await childActivity();const blocked=pg.filter(p=>p.query.includes('DELETE')&&p.query.includes('AuditLog')&&p.blockers.includes(periodic.pid));raw('sigterm-held-sample',{elapsedMs:performance.now()-signalAt,childExited:childExit||null,pg,blocker:periodic.pid});assert(!childExit,'Early child exit before release');assert.equal(blocked.length,1,'Periodic query must remain blocked after SIGTERM');assert.deepEqual(procIdentity(child!.pid!),childIdentity);samples++;await pause(expected.sampleMs);}assert(performance.now()-signalAt>=expected.holdMinimumMs);return {heldMs:performance.now()-signalAt,samples,childAlive:true,queryStillBlocked:true};});
    await release(periodic);
    await check(4,async()=>{try{while(performance.now()-signalAt<expected.tailObservationDeadlineMs){const pg=await childActivity();raw('tail-observation',{elapsedSinceSignalMs:performance.now()-signalAt,pg,childExit:childExit||null,tailBlocker:tail.pid});if(pg.some(p=>p.query.includes('DELETE')&&p.query.includes('Session')&&p.blockers.includes(tail.pid))){tailObserved=true;break;}if(childExit)break;await pause(5);}raw('tail-latch-result',{tailObserved,childExit:childExit||null,sessions:await sessions(),eligibleIds:await eligibleIds()});assert(tailObserved,'Current sweep did not reach tail DELETE Session while child live');assert(!childExit);await diff('periodic500-tail-blocked-before-exit',afterStartup,secondIds,1);assert.equal(await core.db.session.count({where:{id:expiredId}}),1);}finally{for(const lock of latches)await release(lock);allReleasedAt=performance.now();raw('all-latches-released',{signalAt,allReleasedAt,elapsedSinceSignalMs:allReleasedAt-signalAt,deadlineMs:expected.releaseAllDeadlineMs,childExit:childExit||null});}assert(allReleasedAt-signalAt<=expected.releaseAllDeadlineMs,'Release deadline1000ms');return {tailObserved:true,deleted:500,eligible:1,releaseAllMs:allReleasedAt-signalAt};});
    // Immediate real DB polling after release establishes tail deletion before the observed child exit.
    await check(5,async()=>{assert(tailObserved,'No live tail statement observation');let snapshot:any;await until(async()=>{snapshot=await sessions();if(!snapshot.some((r:any)=>r.id===expiredId))return true;if(childExit)throw Error('Child exited with expiredSession witness still present');return false;},'tail witness deletion',expected.shutdownDeadlineMs,1);const observedAt=performance.now();assert(!childExit,'Tail commit must be observed before child exit');const liveStat=readFileSync('/proc/'+child!.pid+'/stat','utf8');const liveFields=liveStat.slice(liveStat.lastIndexOf(')')+2).trim().split(/\s+/);const actualLiveIdentity={pid:Number(liveStat.slice(0,liveStat.indexOf(' '))),startTicks:liveFields[19],state:liveFields[0]};assert.equal(actualLiveIdentity.pid,childIdentity.pid);assert.equal(actualLiveIdentity.startTicks,childIdentity.startTicks);assert(['R','S','D'].includes(actualLiveIdentity.state),'Actual child must be live, not zombie');raw('tail-witness-before-exit',{snapshot,expiredId,freshId,observedAt,childExit:childExit||null,actualLiveIdentity,allReleasedAt});assert.deepEqual(snapshot,[freshSession]);assert.deepEqual(await eligibleIds(),[id(1000)]);tailSnapshot=snapshot;return {expiredGone:true,freshKept:true,observedBeforeExit:true,eligibleIds:[id(1000)]};});
    async function closed(label:string,beforeRedis:any[]) {await until(async()=>(await childActivity()).length===0&&(await redisClients()).every(r=>beforeRedis.some(b=>b.id===r.id))&&(await core.queue.getWorkers()).length===0,'child connections closed',5000);raw('closed-readback',{label,childLabel,childExit,pgChildConnections:0,workerConsumers:0,redisBefore:beforeRedis,redisAfter:await redisClients(),osPidNotPgPid:true});}
    await check(6,async()=>{const exited=await Promise.race([exitPromise!,pause(expected.shutdownDeadlineMs).then(()=>{throw Error('Shutdown release deadline5000ms');})]);assert.deepEqual({code:exited.code,signal:exited.signal},{code:0,signal:null});assert(exited.at-allReleasedAt<=expected.shutdownDeadlineMs);raw('inflight-exit-readback',{childExit:exited,allReleasedAt,shutdownAfterReleaseMs:exited.at-allReleasedAt,sessions:await sessions(),eligibleIds:await eligibleIds(),tailSnapshot});assert.equal(stderr,'','No child errors allowed');await closed('inflight',redisBefore);return {actualExit:0,shutdownAfterReleaseMs:exited.at-allReleasedAt,pg:0,redisChild:0,consumers:0};});
    await check(7,async()=>{assert(childExit);const rows=await audits(),beforeSessions=await sessions(),from=performance.now();await pause(expected.postExitMs);assert.deepEqual(await audits(),rows);assert.deepEqual(await sessions(),beforeSessions);assert.deepEqual(await eligibleIds(),[id(1000)]);assert.equal((await childActivity()).length,0);assert.equal((await core.queue.getWorkers()).length,0);raw('postexit-nochange',{label:'inflight',observedMs:performance.now()-from,rows,sessions:beforeSessions,eligibleIds:await eligibleIds(),connections:0,consumers:0});return {observedMs:performance.now()-from,remaining:1,noNewPeriodicSweep:true};});
    await check(8,async()=>{await preserve('inflight-after-exit-before-idle-control');return {adminOtherGroupsFreshKept:true,settingsPreserved:true,charged:37};});
    // Distinct control in this new suite, no replay of the old35 matrix.
    await check(9,async()=>{assert(childExit,'Inflight child must already exit');for(const lock of latches)await release(lock);const beforeRedis=await redisClients();raw('idle-control-pre-state',{eligibleIds:await eligibleIds(),sessions:await sessions(),priorChildExit:childExit});startChild('idle-control');await until(async()=>!!ready,'idle control ready');assert.equal(ready.concurrency,1);await until(async()=>(await core.queue.getWorkers()).length===1,'idle worker registration');let pg:any[]=[];await until(async()=>{pg=await childActivity();raw('idle-pg-observation',{childLabel,parentPid,pg,locksReleased:latches.every(h=>h.released)});return pg.length>0&&pg.every(p=>p.state==='idle'&&!p.blockers.length)&&pg.some(p=>p.query.includes('DELETE')&&p.query.includes('Session'));},'idle final Session statement');await emptyJobGuard();raw('idle-pre-signal',{pg,ready,jobsEmpty:true,locksReleased:latches.every(h=>h.released)});const sent=signalOwn('SIGTERM','idle-control');const exited=await Promise.race([exitPromise!,pause(expected.shutdownDeadlineMs).then(()=>{throw Error('Idle deadline5000ms');})]);assert.deepEqual({code:exited.code,signal:exited.signal},{code:0,signal:null});assert.equal(stderr,'');await closed('idle-control',beforeRedis);await preserve('idle-control-after-exit');raw('idle-result',{actualExit:exited,signalAt:sent,signalToExitMs:exited.at-sent});return {exit:0,signal:null,connectionsClosed:true,protectedControlsKept:true};});
  } catch(error) {failure ||= error;raw('failure',{type:(error as Error).constructor.name,message:String((error as Error).message).slice(0,1800),scope:'Keep observed failure, classify harness/isolation separately from production'});}
  finally {
    process.env.DATABASE_URL=baseURL;
    for(const lock of latches){try{await release(lock);}catch(error){failure ||= error;raw('cleanup-lock-error',{label:lock.label,message:String((error as Error).message)});}}
    if(child&&!childExit){try{signalOwn('SIGTERM','finally-cleanup-not-runtime-PASS');await until(async()=>!!childExit,'own child finally TERM',5000);}catch(error){failure ||= error;if(!childExit){signalOwn('SIGKILL','finally-guarded-fallback-not-runtime-PASS');await until(async()=>!!childExit,'own child finally KILL',3000);}}}
    if(locks)await locks.$disconnect();
    await check(10,async()=>{if(core){assert(!child||childExit,'Never cleanup while own child lives');const rows=await core.db.auditLog.findMany();assert(rows.every((r:any)=>ownedAudits.has(r.id)&&r.detail.marker==='p36'));await core.db.auditLog.deleteMany({where:{id:{in:[...ownedAudits]}}});const events=await core.db.adEvent.findMany();assert(events.every((r:any)=>ownedEvents.has(r.id)&&ownedCampaigns.has(r.campaignId)));await core.db.adEvent.deleteMany({where:{id:{in:[...ownedEvents]}}});await core.db.adCampaign.deleteMany({where:{id:{in:[...ownedCampaigns]}}});const sessions=await core.db.session.findMany({select:{id:true}});assert(sessions.every((r:any)=>ownedSessions.has(r.id)));await core.db.session.deleteMany({where:{id:{in:[...ownedSessions]}}});if(settingsSeeded){assert.deepEqual(await core.db.settings.findMany(),outsideBefore.settings);await core.db.settings.delete({where:{id:'main'}});}if(budgetSeeded){assert.deepEqual(await core.db.egressBudget.findMany(),outsideBefore.egressBudget);await core.db.egressBudget.delete({where:{month:'p36-fixture'}});}await core.queue.close();const keys:string[]=await core.redis.keys('*');assert(keys.every(k=>k.startsWith('bull:media:')));if(keys.length)await core.redis.del(...keys);for(const model of [...outsideNames,'session','auditLog','adEvent','adCampaign'])assert.equal(await core.db[model].count(),0);assert.deepEqual(await core.redis.keys('*'),[]);if(mediaCreated){assert.equal(await realpath(core.mediaRoot),'/tmp/p36-media');const stat=await lstat(core.mediaRoot);assert(stat.isDirectory()&&!stat.isSymbolicLink());assert.deepEqual(await readdir(core.mediaRoot),[]);await rmdir(core.mediaRoot);}raw('cleanup',{modelsEmpty:true,keysEmpty:true,knownKeysRemoved:keys.length,ownMarkerIdsOnly:true,childExited:true,locksReleased:latches.every(h=>h.released),chargedPreservedUntilCleanup:37,settingsRemovedOwnSentinelOnly:true,mediaResolvedEmptyNonrecursiveRmdir:true,runtimeSweepProof:false});await core.redis.quit();await core.db.$disconnect();}if(inspector)await inspector.quit();return {empty:true,ownChildrenClosed:true,parentClientsClosed:true,noHooksInstalled:true};});
    for(const name of expected.cases)if(!results.some(r=>r.name===name))results.push({name,result:'NOT_RUN',reason:'Earlier precondition failure; not fabricated PASS'});
    results.sort((a,b)=>expected.cases.indexOf(a.name)-expected.cases.indexOf(b.name));raw('summary',{uniqueControls:expected.cases.length,pass:results.filter(r=>r.result==='PASS').length,fail:results.filter(r=>r.result==='FAIL').length,notRun:results.filter(r=>r.result==='NOT_RUN').length,results,sourceSHA:coordinates.sourceSHA,entrypoint:'apps/worker/src/main.ts',fixtureSeconds:2,sourceDefaultSeconds:30,parentSweepCalls:0,http:0,mainApplied:false});
  }
  if(failure)process.exitCode=1;
}
main().catch(error=>{raw('harness-failure',{type:error?.constructor?.name,message:String(error?.message).slice(0,1800),productionVerdict:false});process.exitCode=2;});


