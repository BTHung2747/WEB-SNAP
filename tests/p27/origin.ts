import 'reflect-metadata';
import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,readlinkSync} from 'node:fs';
import {cases,operationSuccess,sources,maxRequests,requestDeadlineMs,responseMaxBytes} from './origin-expectations';
import {canonical,checkSchema} from './schema';

const sha=(path:string)=>createHash('sha256').update(readFileSync(path)).digest('hex');
const digest=(value:string)=>createHash('sha256').update(value).digest('hex');
const privateValues=new Set<string>();
const privateValue=(s:string)=>{if(s.length>=12)privateValues.add(s);return s;};
const raw=(stage:string,data:any)=>{
  const text=JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...data},(_k,v)=>typeof v==='bigint'?String(v):v);
  for(const s of privateValues)assert(!text.includes(s),'secret redaction guard');
  console.log('P27_ORIGIN_RAW '+text);
};
const safeError=(e:any)=>({type:e?.constructor?.name||'Error',code:typeof e?.code==='string'&&/^[A-Z0-9_]+$/.test(e.code)?e.code:undefined,message:'details suppressed to protect credentials; inspect preceding bounded HTTP/DB records'});

async function main(){
  assert.equal(process.env.P27_GUARD,'wed-snap-admin-http-lab');
  assert.equal(process.env.DATABASE_URL,'postgresql://p27@db:5432/wed_snap_admin_http_test');
  assert.equal(process.env.REDIS_URL,'redis://redis:6379/15');
  assert.equal(process.env.MEDIA_ROOT,'/tmp/p27-no-media');
  assert.equal(process.env.TRUSTED_PROXY_HOSTS,'');
  assert.equal(process.env.COOKIE_SECURE,'false');
  assert.equal(process.env.ADMIN_SESSION_SECRET,'p27-unused-sentinel-replaced-in-test-memory');
  const hashes=Object.fromEntries(sources.map(p=>[p,sha(p)]));
  assert.equal(digest(sources.map(p=>p+':'+hashes[p]).join('|')),process.env.P27_SOURCE_SHA);
  assert(process.env.P27_DB_IP&&process.env.P27_REDIS_IP&&process.env.P27_PG_CLUSTER&&process.env.P27_REDIS_RUN,'actual datastore coordinates from host guard');
  // Real random signing/password material remains in this process, never Compose/argv/log.
  process.env.ADMIN_SESSION_SECRET=privateValue(randomBytes(32).toString('hex'));
  const req=createRequire(__filename),net=req('node:net'),http=req('node:http');
  const saved={connect:net.Socket.prototype.connect,listen:net.Server.prototype.listen};
  const counters={httpDials:0,redisDials:0,allowedListens:0,deniedDials:0,deniedListens:0};
  const sockets=new Set<any>(),peers=new Set<any>();let port=0,server:any,app:any,core:any,inspector:any;
  net.Socket.prototype.connect=function(...args:any[]){
    const a=Array.isArray(args[0])?args[0]:args;const opts=typeof a[0]==='object'?a[0]:{port:a[0],host:a[1]};
    const isHttp=port>0&&Number(opts.port)===port&&opts.host==='127.0.0.1';
    const isRedis=Number(opts.port)===6379&&[process.env.P27_REDIS_IP,'redis'].includes(opts.host);
    if(!isHttp&&!isRedis){counters.deniedDials++;throw Error('P27 forbidden socket');}
    if(isHttp)counters.httpDials++;else counters.redisDials++;
    sockets.add(this);this.once('close',()=>sockets.delete(this));return saved.connect.apply(this,args);
  };
  net.Server.prototype.listen=function(...args:any[]){
    const opts=typeof args[0]==='object'?args[0]:{port:args[0],host:args[1]};
    if(server||Number(opts.port)!==0||opts.host!=='127.0.0.1'){counters.deniedListens++;throw Error('P27 forbidden listen');}
    server=this;counters.allowedListens++;return saved.listen.apply(this,args);
  };
  let countBefore:any,settingsBefore:any,budgetBefore:any,queueBefore:any,redisBefore:string[]=[];
  const owned={adminId:randomUUID(),campaignIds:[] as string[],eventIds:[] as string[],jobIds:[] as string[],assetIds:[] as string[],leaseIds:[] as string[],sessionIds:[] as string[],budgetMonth:'p27-'+randomUUID(),auditIds:[] as string[]};
  const email='p27-'+randomUUID()+'@example.invalid';const password=privateValue(randomBytes(32).toString('hex'));
  let guestCookie='',csrf='',adminCookie='',adminKey='',campaignId='',sessionId='',currentCase='',requests=0,order=0,passed=0,failed=0,cleanupOk=false;
  const success=new Set<string>(),caseResults:any[]=[];
  const expectCase=(name:string)=>{const e=cases.find(c=>c[0]===name);assert(e,'registered independent case');return e![1];};
  const run=async(name:string,fn:()=>Promise<void>)=>{
    currentCase=name;const before=requests;let err:any;
    try{await fn();passed++;}catch(e){failed++;err=safeError(e);}
    const result={name,expected:expectCase(name),result:err?'FAIL':'PASS',requests:requests-before,error:err||null};caseResults.push(result);raw('case-result',result);
  };
  const route=(path:string)=>path.replace(/\/admin\/campaigns\/[^/?]+$/,'/admin/campaigns/{id}').split('?')[0];
  const cookieFlags=(headers:any)=>{const c=(headers['set-cookie']||[]).join(';');return {present:!!c,httpOnly:/\bHttpOnly\b/i.test(c),secure:/\bSecure\b/i.test(c),sameSiteLax:/\bSameSite=Lax\b/i.test(c),pathApi:/\bPath=\/api(?:;|$)/i.test(c),maxAge:Number(/\bMax-Age=(\d+)/i.exec(c)?.[1]??-1),cleared:/Expires=Thu, 01 Jan 1970/i.test(c)};};
  const call=async(path:string,method:string,status:number,body?:any,headers:Record<string,string>={},code?:string)=>{
    assert(++requests<=maxRequests,'request inventory bound');const startOrder=++order,start=performance.now();
    raw('request-start',{name:currentCase,request:requests,startOrder,method,path,role:headers.Cookie?.includes('ws_admin')?(headers.Cookie?.includes('ws_session')?'admin+guest':'admin-only'):(headers.Cookie?'guest-only':'none'),origin:headers.Origin?(headers.Origin==='http://p27.local'?'own':'wrong'):'missing',csrfHeader:headers['x-csrf-token']?(headers['x-csrf-token']===csrf?'correct':'wrong'):'missing',bodyKeys:body&&typeof body==='object'?Object.keys(body):[],expectedStatus:status,expectedCode:code||null});
    const wire=body===undefined?undefined:JSON.stringify(body);
    const out:any=await new Promise((resolve,reject)=>{
      const r=http.request({hostname:'127.0.0.1',port,path,method,agent:false,headers:{...(wire!==undefined?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(wire)}:{}),...headers}},(res:any)=>{
        const chunks:Buffer[]=[];let bytes=0;
        res.on('data',(c:Buffer)=>{bytes+=c.length;if(bytes>responseMaxBytes)res.destroy(Error('response cap'));else chunks.push(c);});
        res.on('error',reject);res.on('end',()=>{clearTimeout(timer);const text=Buffer.concat(chunks).toString();let value:any;try{value=JSON.parse(text);}catch{reject(Error('JSON response required'));return;}resolve({status:res.statusCode,headers:res.headers,body:value,bytes});});
      });
      const timer=setTimeout(()=>r.destroy(Error('request deadline')),requestDeadlineMs);r.on('error',(e:any)=>{clearTimeout(timer);reject(e);});if(wire!==undefined)r.write(wire);r.end();
    });
    for(const c of out.headers['set-cookie']||[]){const v=c.split(';')[0];privateValue(v);privateValue(v.split('=').slice(1).join('='));}
    if(path==='/api/v1/session'&&typeof out.body.csrf==='string')privateValue(out.body.csrf);
    // Track successful fixture creations before assertions, to clean even a later schema mismatch.
    if(method==='POST'&&path==='/api/v1/admin/campaigns'&&typeof out.body?.id==='string')owned.campaignIds.push(out.body.id);
    raw('request-finish',{name:currentCase,request:requests,startOrder,finishOrder:++order,method,path,status:out.status,elapsedMs:Math.round((performance.now()-start)*1000)/1000,bodyBytes:out.bytes,body:path==='/api/v1/session'?{...out.body,csrf:'[REDACTED]'}:out.body,headers:{cacheControl:out.headers['cache-control'],contentType:out.headers['content-type'],nosniff:out.headers['x-content-type-options'],cookieFlags:cookieFlags(out.headers)}});
    assert.equal(out.status,status,'HTTP status vs independent expected');assert.equal(out.headers['cache-control'],'no-store','production no-store');assert.equal(out.headers['x-content-type-options'],'nosniff','helmet');assert(out.bytes<=responseMaxBytes,'bounded response');
    const operation=doc.paths[route(path)]?.[method.toLowerCase()];assert(operation,'operation in production snapshot');
    const response=operation.responses[String(status)]||operation.responses.default;checkSchema(doc,response.content['application/json'].schema,out.body);
    if(code){assert.deepEqual(out.body,{error:{code}},'safe exact error envelope');if(response['x-app-error-codes'])assert(response['x-app-error-codes'].includes(code),'AppError profile');}
    else if(operationSuccess.some(x=>x[0]===method&&x[1]===route(path)&&x[2]===status))success.add(method+' '+route(path));
    return out;
  };
  let doc:any;
  const both=()=>({Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local','x-csrf-token':csrf});
  const guest=()=>({Cookie:guestCookie,Origin:'http://p27.local','x-csrf-token':csrf});
  const readonlyAdmin=()=>({Cookie:adminCookie});
  const counts=async()=>({session:await core.db.session.count(),admin:await core.db.adminUser.count(),campaign:await core.db.adCampaign.count(),event:await core.db.adEvent.count(),audit:await core.db.auditLog.count(),job:await core.db.downloadJob.count(),item:await core.db.mediaItem.count(),asset:await core.db.temporaryAsset.count(),lease:await core.db.transferLease.count(),ticket:await core.db.downloadTicket.count()});
  const state=async()=>({counts:await counts(),settings:await core.db.settings.findMany({orderBy:{id:'asc'}}),budget:await core.db.egressBudget.findMany({orderBy:{month:'asc'}})});
  const unchanged=async(fn:()=>Promise<void>)=>{const before=await state();await fn();assert.deepEqual(await state(),before,'rejected mutation DB unchanged');raw('db-rejection',{name:currentCase,beforeCounts:before.counts,afterCounts:(await counts()),settingsBudgetDeepEqual:true});};
  const audit=async(action:string,id?:string)=>{const rows=await core.db.auditLog.findMany({where:{actor:email,action},orderBy:{createdAt:'asc'}});const matches=id?rows.filter((r:any)=>r.detail.id===id):rows;assert.equal(matches.length,1,'exact audit actor/action/target');assert(matches[0].createdAt instanceof Date);owned.auditIds.push(matches[0].id);raw('audit-readback',{action,actorMatches:true,actorHash:digest(email),targetId:id||'settings-main',count:1,createdAt:matches[0].createdAt.toISOString()});};
  try{
    const IORedis=req('ioredis');inspector=new IORedis(process.env.REDIS_URL,{maxRetriesPerRequest:1});
    assert(/\bdb=15\b/.test(String(await inspector.client('INFO'))),'actual Redis15');
    const redisInfo=String(await inspector.info('server'));assert(redisInfo.includes('run_id:'+process.env.P27_REDIS_RUN),'actual guarded Redis server');
    redisBefore=(await inspector.keys('*')).sort();assert.equal(redisBefore.length,0,'foreign keys refuse');
    const {PrismaClient}=await import('@prisma/client');const preflight=new PrismaClient();
    try{const ident:any[]=await preflight.$queryRaw`SELECT current_database() AS database,inet_server_addr()::text AS address,host(inet_server_addr()) AS host,version() AS version,(SELECT system_identifier::text FROM pg_control_system()) AS cluster`;
      raw('datastore-identity-comparison',{database:ident[0].database,addressText:ident[0].address,numericHost:ident[0].host,expectedContainerIP:process.env.P27_DB_IP,clusterMatches:ident[0].cluster===process.env.P27_PG_CLUSTER,note:'PostgreSQL inet::text retains /32; host(inet) is the numeric address for guard comparison, not a business verdict'});
      assert.equal(ident[0].database,'wed_snap_admin_http_test');assert.equal(ident[0].host,process.env.P27_DB_IP);assert.equal(ident[0].cluster,process.env.P27_PG_CLUSTER);
      raw('datastore-identity',{database:ident[0].database,postgres:ident[0].version,serverAddressMatchesContainer:true,clusterMatchesContainer:true,redisDatabase:15,redisRunMatchesContainer:true,redisVersion:/redis_version:([^\r\n]+)/.exec(redisInfo)?.[1],keysBefore:0});
    }finally{await preflight.$disconnect();}
    core=await import('../../packages/shared/src/core');
    const {NestFactory}=await import('@nestjs/core'),{SwaggerModule}=await import('@nestjs/swagger');
    const cookieParser=(await import('cookie-parser')).default,helmet=(await import('helmet')).default;
    const {AppModule}=await import('../../apps/api/src/app.module'),{SafeErrors}=await import('../../apps/api/src/common');
    const {clientIdentityMiddleware}=await import('../../apps/api/src/security/client-ip'),api=await import('../../apps/api/src/openapi');
    app=await NestFactory.create(AppModule,{logger:false,abortOnError:false});app.getHttpAdapter().getInstance().set('trust proxy',false);
    app.use(clientIdentityMiddleware());app.use(helmet({contentSecurityPolicy:false}));app.use(cookieParser());app.useGlobalFilters(new SafeErrors());
    doc=api.createOpenApiDocument(app);assert.deepEqual(canonical(doc),canonical(JSON.parse(readFileSync('docs/openapi.json','utf8'))),'factory matches accepted26 snapshot');SwaggerModule.setup('api/docs',app,doc);
    app.use((_r:any,res:any,next:any)=>{res.setHeader('Cache-Control','no-store');next();});
    countBefore=await counts();assert(Object.values(countBefore).every(n=>n===0),'foreign business rows refuse');
    settingsBefore=await core.db.settings.findMany({orderBy:{id:'asc'}});budgetBefore=await core.db.egressBudget.findMany({orderBy:{month:'asc'}});assert.equal(settingsBefore.length,0);assert.equal(budgetBefore.length,0);
    queueBefore={waiting:await core.queue.getWaitingCount(),active:await core.queue.getActiveCount()};assert.deepEqual(queueBefore,{waiting:0,active:0});
    const versions=Object.fromEntries(['@nestjs/core','@nestjs/platform-express','express','@nestjs/swagger','typescript','@prisma/client','bullmq','ioredis','zod'].map(p=>[p,JSON.parse(readFileSync('node_modules/'+p+'/package.json','utf8')).version]));
    raw('matrix-before-write',{expected:cases.map(([name,expected])=>({name,expected})),operationSuccess,hashes,sourceSha:process.env.P27_SOURCE_SHA,testSha:sha('tests/p27/origin.ts'),schemaHelperSha:sha('tests/p27/schema.ts'),expectedSha:sha('tests/p27/origin-expectations.ts'),node:process.version,versions,namespace:readlinkSync('/proc/self/ns/pid'),beforeCounts:countBefore,settingsBefore,budgetBefore,queueBefore,maxRequests,requestDeadlineMs,responseMaxBytes,doubles:['no business/auth/parser/filter/DB/Redis verdict doubles','random in-memory admin/signing fixtures; direct DB aggregation fixtures declared','restricted OpenAPI keyword checker, no claim universal validator'],networkFence:'own internal Docker network + JS sockets only Redis or exact HTTPloopback; Prisma native TCP verified via inet_server_addr/cluster, not counted by JS socket hook'});
    await app.listen(0,'127.0.0.1');port=server.address().port;assert(port>0&&server.address().address==='127.0.0.1');server.on('connection',(s:any)=>{peers.add(s);s.once('close',()=>peers.delete(s));});
    const encoded=privateValue(core.passwordHash(password));await core.db.adminUser.create({data:{id:owned.adminId,email,passwordHash:encoded}});
    const campaign:any={title:'P27 contract fixture',targetUrl:'https://example.invalid/p27',linkType:'sponsored',placement:'banner',enabled:true,startsAt:new Date(Date.now()-60000).toISOString(),endsAt:new Date(Date.now()+3600000).toISOString(),weight:1};
    await run('origin-fixture-bootstrap',async()=>{
      const s=await call('/api/v1/session','GET',200);guestCookie=privateValue(s.headers['set-cookie'].find((c:string)=>c.startsWith('ws_session=')).split(';')[0]);csrf=privateValue(s.body.csrf);sessionId=core.hash(privateValue(guestCookie.split('=')[1]));owned.sessionIds.push(sessionId);
      const r=await call('/api/v1/admin/login','POST',201,{email,password},guest());adminCookie=privateValue(r.headers['set-cookie'].find((c:string)=>c.startsWith('ws_admin=')).split(';')[0]);const value=privateValue(adminCookie.split('=')[1]),[token,mac]=value.split('.');privateValue(token);privateValue(mac);adminKey='admin:'+core.hash(token);assert.equal(await core.redis.get(adminKey),email);
      const c=await call('/api/v1/admin/campaigns','POST',201,campaign,both());campaignId=c.body.id;assert(await core.db.adCampaign.findUnique({where:{id:campaignId}}));await audit('campaign.create',campaignId);
    });
    await run('delete-origin-missing-and-wrong',async()=>{await unchanged(async()=>{
      await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',403,{extra:true},{Cookie:guestCookie+'; '+adminCookie,'x-csrf-token':csrf},'CSRF_INVALID');
      await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',403,{extra:true},{...both(),Origin:'http://wrong.invalid'},'CSRF_INVALID');
      assert(await core.db.adCampaign.findUnique({where:{id:campaignId}}));assert.equal(await core.redis.exists(adminKey),1);
    });});
    await run('logout-origin-wrong',async()=>{await unchanged(async()=>{
      await call('/api/v1/admin/logout','POST',403,{csrf,extra:true},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://wrong.invalid'},'CSRF_INVALID');assert.equal(await core.redis.exists(adminKey),1,'wrong Origin retains actual token');
    });});
    await run('origin-valid-cleanup-controls',async()=>{
      await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',200,{csrf,extra:true},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'});assert.equal(await core.db.adCampaign.findUnique({where:{id:campaignId}}),null);await audit('campaign.delete',campaignId);
      const r=await call('/api/v1/admin/logout','POST',201,{extra:true},both());assert.equal(await core.redis.exists(adminKey),0);assert(cookieFlags(r.headers).cleared);
    });
    assert.equal(caseResults.length,cases.length);assert.equal(requests,8,'supplement only8HTTP');
  }finally{
    let cleanupError:any;
    try{
      if(core&&countBefore){
        // Production lifecycle/media not invoked: aggregation-only fixture rows individually removed.
        await core.db.adEvent.deleteMany({where:{id:{in:owned.eventIds}}});await core.db.adCampaign.deleteMany({where:{id:{in:owned.campaignIds}}});
        await core.db.transferLease.deleteMany({where:{id:{in:owned.leaseIds}}});await core.db.temporaryAsset.deleteMany({where:{id:{in:owned.assetIds}}});await core.db.downloadJob.deleteMany({where:{id:{in:owned.jobIds}}});
        const logs=await core.db.auditLog.findMany({where:{actor:email},select:{id:true,action:true}});assert(logs.every((x:any)=>['settings.update','campaign.create','campaign.update','campaign.delete'].includes(x.action)),'only own audit actor actions');await core.db.auditLog.deleteMany({where:{id:{in:logs.map((x:any)=>x.id)},actor:email}});
        await core.db.session.deleteMany({where:{id:{in:owned.sessionIds}}});await core.db.adminUser.deleteMany({where:{id:owned.adminId,email}});
        if(settingsBefore.length===0)await core.db.settings.deleteMany({where:{id:'main'}});else for(const row of settingsBefore)await core.db.settings.upsert({where:{id:row.id},create:row,update:{value:row.value}});
        await core.db.egressBudget.deleteMany({where:{month:owned.budgetMonth}});
        assert.deepEqual(await core.db.settings.findMany({orderBy:{id:'asc'}}),settingsBefore,'restore settings');assert.deepEqual(await core.db.egressBudget.findMany({orderBy:{month:'asc'}}),budgetBefore,'restore budget');assert.deepEqual(await counts(),countBefore,'only own rows');assert.deepEqual({waiting:await core.queue.getWaitingCount(),active:await core.queue.getActiveCount()},queueBefore,'queue unchanged');
        await core.queue.close();
        const allowed=new Set(['rate:session:create:ip:'+core.hash('127.0.0.1'),'rate:login:'+core.hash('127.0.0.1'),...owned.sessionIds.flatMap(id=>['rate:ads:'+id,'ads:sponsor:'+id]),...(adminKey?[adminKey]:[]),'bull:media:meta','bull:media:events','bull:media:id']);
        const keys=(await inspector.keys('*')).sort();const added=keys.filter((k:string)=>!redisBefore.includes(k));assert(added.every((k:string)=>allowed.has(k)),'unknown Redis key refuses cleanup');if(added.length)await inspector.del(...added);
        assert.deepEqual((await inspector.keys('*')).sort(),redisBefore,'only own Redis keys cleaned');cleanupOk=true;
        raw('cleanup',{fixtureRowsRestored:true,settingsBudgetDeepEqual:true,rows:await counts(),queueBefore,queueAfter:queueBefore,keysRemoved:added.length,redisKeysAfter:redisBefore.length,ownAdmin:1,ownSessions:owned.sessionIds.length,ownCampaigns:owned.campaignIds.length,ownEvents:owned.eventIds.length,ownJobs:owned.jobIds.length,ownAssets:owned.assetIds.length,ownLeases:owned.leaseIds.length,ownAudits:logs.length,noReset:true,noMediaCreated:true});
      }
    }catch(e){cleanupError=safeError(e);raw('CLEANUP_FAIL',{error:cleanupError});}
    try{if(app)await app.close();if(core){await core.queue.close();await core.redis.quit();await core.db.$disconnect();}if(inspector)await inspector.quit();
      await Promise.all([...new Set([...sockets,...peers])].map(s=>new Promise<void>((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('socket close2s')),2000);s.once('close',()=>{clearTimeout(timer);resolve();});s.destroy();})));
    }finally{net.Socket.prototype.connect=saved.connect;net.Server.prototype.listen=saved.listen;}
    raw('finally',{hooksRestored:true,serverClosed:!server||!server.listening,socketsRemaining:sockets.size,peersRemaining:peers.size,counters,cleanupOk,closeBoundMs:2000});
    assert(!cleanupError,'cleanup failed; not runtime PASS');assert(cleanupOk,'fixtures cleanup must prove restoration');assert(!server.listening);assert.equal(sockets.size,0);assert.equal(peers.size,0);assert.equal(counters.deniedDials,0);assert.equal(counters.deniedListens,0);assert.equal(counters.allowedListens,1);
  }
  raw('summary',{passed,failed,result:failed?'FAIL':'PASS',requests,maxRequests,successOperations:[...success].sort(),successCount:success.size,counters,cleanupOk,scope:'supplementary logout/DELETE Origin controls, real own HTTP/PG/Redis; original36case evidence preserved; no lifecycle/platform proof'});if(failed)process.exitCode=1;
}
main().catch(e=>{raw('HARNESS_FAIL',{error:safeError(e),scope:'startup/fixture/isolation or final guard, not automatically a production bug'});process.exitCode=1;});
