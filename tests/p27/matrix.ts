import 'reflect-metadata';
import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,readlinkSync} from 'node:fs';
import {cases,operationSuccess,limits,sources,maxRequests,requestDeadlineMs,responseMaxBytes} from './expectations';
import {canonical,checkSchema} from './schema';

const sha=(path:string)=>createHash('sha256').update(readFileSync(path)).digest('hex');
const digest=(value:string)=>createHash('sha256').update(value).digest('hex');
const privateValues=new Set<string>();
const privateValue=(s:string)=>{if(s.length>=12)privateValues.add(s);return s;};
const raw=(stage:string,data:any)=>{
  const text=JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...data},(_k,v)=>typeof v==='bigint'?String(v):v);
  for(const s of privateValues)assert(!text.includes(s),'secret redaction guard');
  console.log('P27_RAW '+text);
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
    raw('matrix-before-write',{expected:cases.map(([name,expected])=>({name,expected})),operationSuccess,hashes,sourceSha:process.env.P27_SOURCE_SHA,testSha:sha('tests/p27/matrix.ts'),schemaHelperSha:sha('tests/p27/schema.ts'),expectedSha:sha('tests/p27/expectations.ts'),node:process.version,versions,namespace:readlinkSync('/proc/self/ns/pid'),beforeCounts:countBefore,settingsBefore,budgetBefore,queueBefore,maxRequests,requestDeadlineMs,responseMaxBytes,doubles:['no business/auth/parser/filter/DB/Redis verdict doubles','random in-memory admin/signing fixtures; direct DB aggregation fixtures declared','restricted OpenAPI keyword checker, no claim universal validator'],networkFence:'own internal Docker network + JS sockets only Redis or exact HTTPloopback; Prisma native TCP verified via inet_server_addr/cluster, not counted by JS socket hook'});
    await app.listen(0,'127.0.0.1');port=server.address().port;assert(port>0&&server.address().address==='127.0.0.1');server.on('connection',(s:any)=>{peers.add(s);s.once('close',()=>peers.delete(s));});
    const encoded=privateValue(core.passwordHash(password));await core.db.adminUser.create({data:{id:owned.adminId,email,passwordHash:encoded}});
    const campaign:any={title:'P27 contract fixture',targetUrl:'https://example.invalid/p27',linkType:'sponsored',placement:'banner',enabled:true,startsAt:new Date(Date.now()-60000).toISOString(),endsAt:new Date(Date.now()+3600000).toISOString(),weight:1};
    const selectedLimits={...limits,maxDuration:599,maxBytes:8192,maxInputBytes:10240,monthlyBytes:9999,acceptJobs:false};
    await run('session-issued',async()=>{const r=await call('/api/v1/session','GET',200);const c=r.headers['set-cookie'].find((v:string)=>v.startsWith('ws_session='));assert(c,'guest cookie present');guestCookie=privateValue(c.split(';')[0]);const token=privateValue(guestCookie.split('=')[1]);csrf=privateValue(r.body.csrf);sessionId=core.hash(token);owned.sessionIds.push(sessionId);const row=await core.db.session.findUnique({where:{id:sessionId}});assert(row&&row.csrf===csrf,'guest actual DB');assert(row.expiresAt.getTime()>Date.now()+86300000,'session TTL');assert(cookieFlags(r.headers).httpOnly&&cookieFlags(r.headers).sameSiteLax&&cookieFlags(r.headers).pathApi&&!cookieFlags(r.headers).secure,'local cookie flags');assert.deepEqual(r.body.supported,['youtube']);raw('session-db',{ownedSessionHash:sessionId,csrfMatches:true,ttlSeconds:Math.floor((row.expiresAt.getTime()-Date.now())/1000)});});
    await run('ads-missing-cookie',async()=>{await call('/api/v1/ads','GET',403,undefined,{},'SESSION_REQUIRED');});
    await run('ads-empty',async()=>{assert.equal((await call('/api/v1/ads','GET',200,undefined,{Cookie:guestCookie})).body,null);});
    await run('admin-get-unauthenticated',async()=>{for(const path of ['dashboard','settings','campaigns'])await call('/api/v1/admin/'+path,'GET',403,undefined,{},'ADMIN_REQUIRED');});
    await run('login-missing-guest',async()=>{await call('/api/v1/admin/login','POST',403,{email,password},{Origin:'http://p27.local','x-csrf-token':csrf},'SESSION_REQUIRED');});
    await run('login-csrf-profiles',async()=>{for(const h of [{Cookie:guestCookie},{Cookie:guestCookie,Origin:'http://wrong.invalid','x-csrf-token':csrf},{Cookie:guestCookie,Origin:'http://p27.local'},{Cookie:guestCookie,Origin:'http://p27.local','x-csrf-token':'wrong'}])await call('/api/v1/admin/login','POST',403,{email,password,...(h['x-csrf-token']==='wrong'?{csrf}:{})},h as any,'CSRF_INVALID');});
    await run('login-strict-header-body',async()=>{await call('/api/v1/admin/login','POST',400,{email,password,csrf},guest(),'INVALID_REQUEST');await call('/api/v1/admin/login','POST',400,{email,password,csrf},{Cookie:guestCookie,Origin:'http://p27.local'},'INVALID_REQUEST');});
    await run('login-invalid-password',async()=>{await call('/api/v1/admin/login','POST',400,{email,password:'short'},guest(),'INVALID_REQUEST');});
    await run('login-wrong-credentials',async()=>{await call('/api/v1/admin/login','POST',403,{email,password:privateValue(randomBytes(32).toString('hex'))},guest(),'LOGIN_FAILED');});
    await run('login-success',async()=>{const r=await call('/api/v1/admin/login','POST',201,{email,password},guest());adminCookie=privateValue(r.headers['set-cookie'].find((c:string)=>c.startsWith('ws_admin=')).split(';')[0]);const value=privateValue(adminCookie.split('=')[1]),[token,mac]=value.split('.');privateValue(token);privateValue(mac);adminKey='admin:'+core.hash(token);const ttl=await core.redis.ttl(adminKey);assert(ttl>3590&&ttl<=3600,'admin TTL');assert.equal(await core.redis.get(adminKey),email,'admin principal');const f=cookieFlags(r.headers);assert(f.httpOnly&&f.sameSiteLax&&f.pathApi&&!f.secure&&f.maxAge===3600,'admin cookie flags');const loginCounter=Number(await core.redis.get('rate:login:'+core.hash('127.0.0.1')));assert.equal(loginCounter,5,'bounded login branch count');raw('login-redis',{ttlSeconds:ttl,actorMatches:true,cookieFlags:f,loginRateCount:loginCounter,noCredentialsLogged:true});});
    await run('admin-get-admin-only',async()=>{for(const path of ['dashboard','settings','campaigns']){const r=await call('/api/v1/admin/'+path,'GET',200,undefined,readonlyAdmin());if(path==='settings')assert.deepEqual(r.body,limits);}});
    await run('admin-invalid-cookie',async()=>{await call('/api/v1/admin/campaigns','GET',403,undefined,{Cookie:'ws_admin='+('1'.repeat(64))+'.'+('2'.repeat(64))},'ADMIN_REQUIRED');});
    await run('admin-write-auth-profiles',async()=>{await unchanged(async()=>{await call('/api/v1/admin/settings','PUT',403,selectedLimits,readonlyAdmin(),'SESSION_REQUIRED');await call('/api/v1/admin/settings','PUT',403,selectedLimits,guest(),'ADMIN_REQUIRED');for(const h of [{Cookie:guestCookie+'; '+adminCookie,'x-csrf-token':csrf},{...both(),Origin:'http://wrong.invalid'},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'},{...both(),'x-csrf-token':'wrong'}])await call('/api/v1/admin/settings','PUT',403,{...selectedLimits,...(h['x-csrf-token']==='wrong'?{csrf}:{})},h as any,'CSRF_INVALID');});});
    await run('settings-put-success',async()=>{const r=await call('/api/v1/admin/settings','PUT',200,selectedLimits,both());assert.deepEqual(r.body,selectedLimits);assert.equal(Object.keys(r.body).length,17);assert.deepEqual((await core.db.settings.findUnique({where:{id:'main'}})).value,selectedLimits);assert.deepEqual((await call('/api/v1/admin/settings','GET',200,undefined,readonlyAdmin())).body,selectedLimits);await audit('settings.update');});
    await run('settings-validation-no-effects',async()=>{await unchanged(async()=>{const missing:any={...selectedLimits};delete missing.maxBytes;for(const [payload,code]of [[{...selectedLimits,maxDuration:601},'INVALID_REQUEST'],[{...selectedLimits,monthlyBytes:1.5},'INVALID_REQUEST'],[missing,'INVALID_REQUEST'],[{...selectedLimits,csrf},'INVALID_REQUEST'],[{...selectedLimits,extra:1},'INVALID_REQUEST'],[{...selectedLimits,enabledPlatforms:['tiktok']},'PLATFORM_NOT_VERIFIED']] as any[])await call('/api/v1/admin/settings','PUT',400,payload,both(),code);});});
    await run('campaign-validation-no-effects',async()=>{await unchanged(async()=>{for(const change of [{csrf},{title:''},{weight:0},{targetUrl:'http://example.invalid'},{targetUrl:'https://127.0.0.1'},{endsAt:campaign.startsAt},{placement:'invalid'},{extra:1}])await call('/api/v1/admin/campaigns','POST',400,{...campaign,...change},both(),'INVALID_REQUEST');});});
    await run('campaign-create-omitted-image',async()=>{const r=await call('/api/v1/admin/campaigns','POST',201,campaign,both());campaignId=r.body.id;const row=await core.db.adCampaign.findUnique({where:{id:campaignId}});assert(row&&r.body.imageUrl===null&&row.imageUrl===null);assert.equal(r.body.startsAt,row.startsAt.toISOString());assert.equal(r.body.endsAt,row.endsAt.toISOString());await audit('campaign.create',campaignId);raw('campaign-readback',{id:campaignId,imageUrlNull:true,dateMatches:true,created:true});});
    await run('campaign-list',async()=>{const r=await call('/api/v1/admin/campaigns','GET',200,undefined,readonlyAdmin());assert.equal(r.body.length,1);assert.equal(r.body[0].id,campaignId);});
    await run('campaign-update',async()=>{campaign.title='P27 updated';campaign.imageUrl='https://example.invalid/p27/image';campaign.weight=100;const r=await call('/api/v1/admin/campaigns/'+campaignId,'PUT',200,campaign,both());const row=await core.db.adCampaign.findUnique({where:{id:campaignId}});assert.deepEqual(r.body,JSON.parse(JSON.stringify(row)));assert.equal(row.title,campaign.title);await audit('campaign.update',campaignId);raw('campaign-readback',{id:campaignId,updated:true,weight:row.weight,dateMatches:true});});
    await run('campaign-invalid-id-before-auth',async()=>{await unchanged(async()=>{await call('/api/v1/admin/campaigns/not-uuid','PUT',400,campaign,{},'INVALID_REQUEST');await call('/api/v1/admin/campaigns/not-uuid','DELETE',400,undefined,{},'INVALID_REQUEST');});});
    await run('campaign-missing-row',async()=>{await unchanged(async()=>{const id=randomUUID();await call('/api/v1/admin/campaigns/'+id,'PUT',500,campaign,both(),'INTERNAL_ERROR');await call('/api/v1/admin/campaigns/'+id,'DELETE',500,undefined,both(),'INTERNAL_ERROR');});});
    await run('ads-query-projection',async()=>{const row=await core.db.adCampaign.findUnique({where:{id:campaignId}});for(const q of ['', '?placement=banner','?placement=other']){const r=await call('/api/v1/ads'+q,'GET',200,undefined,{Cookie:guestCookie});assert.deepEqual(r.body,{id:row.id,title:row.title,imageUrl:row.imageUrl,targetUrl:row.targetUrl,linkType:row.linkType,placement:'banner'});}});
    await run('ads-sponsor-empty',async()=>{assert.equal((await call('/api/v1/ads?placement=sponsor','GET',200,undefined,{Cookie:guestCookie})).body,null);assert.equal(await core.redis.exists('ads:sponsor:'+sessionId),0);});
    await run('event-auth-profiles',async()=>{await unchanged(async()=>{const body={id:randomUUID(),campaignId,type:'impression'};await call('/api/v1/ad-events','POST',403,body,{},'SESSION_REQUIRED');for(const h of [{Cookie:guestCookie,'x-csrf-token':csrf},{Cookie:guestCookie,Origin:'http://p27.local'},{...guest(),'x-csrf-token':'wrong'}])await call('/api/v1/ad-events','POST',403,{...body,...(h['x-csrf-token']==='wrong'?{csrf}:{})},h as any,'CSRF_INVALID');});});
    await run('event-validation-no-insert',async()=>{await unchanged(async()=>{const body={id:randomUUID(),campaignId,type:'impression'};for(const change of [{csrf},{id:'bad'},{type:'view'}])await call('/api/v1/ad-events','POST',400,{...body,...change},guest(),'INVALID_REQUEST');});});
    await run('event-unavailable',async()=>{await unchanged(async()=>{await call('/api/v1/ad-events','POST',404,{id:randomUUID(),campaignId:randomUUID(),type:'impression'},guest(),'CAMPAIGN_UNAVAILABLE');});});
    await run('event-success-dedupe',async()=>{const a=randomUUID(),b=randomUUID();owned.eventIds.push(a,b);await call('/api/v1/ad-events','POST',201,{id:a,campaignId,type:'impression'},guest());await call('/api/v1/ad-events','POST',201,{id:a,campaignId,type:'click'},guest());await call('/api/v1/ad-events','POST',201,{id:b,campaignId,type:'click'},guest());assert.equal(await core.db.adEvent.count({where:{id:{in:[a,b]}}}),2);assert.equal((await core.db.adEvent.findUnique({where:{id:a}})).type,'impression');assert.equal((await core.db.adEvent.findUnique({where:{id:b}})).type,'click');const n=Number(await core.redis.get('rate:ads:'+sessionId));assert.equal(n,7);raw('event-readback',{rows:2,sequentialRetrySameUUID:true,firstTypePreserved:true,distinctClick:true,rateCount:n,rateLimit:60});});
    await run('dashboard-fixtures',async()=>{
      const nullJob=randomUUID(),errorJob=randomUUID(),aggregateJob=randomUUID(),asset=randomUUID(),lease=randomUUID(),zeroLease=randomUUID();owned.jobIds.push(nullJob,errorJob,aggregateJob);owned.assetIds.push(asset);owned.leaseIds.push(lease,zeroLease);
      await core.db.downloadJob.createMany({data:[{id:nullJob,sessionId,platform:'fixture-platform',state:'failed',errorCode:null,ownerUntil:new Date(Date.now()+3600000)},{id:errorJob,sessionId,platform:'youtube',state:'failed',errorCode:'LIMIT_EXCEEDED',ownerUntil:new Date(Date.now()+3600000)},{id:aggregateJob,sessionId,platform:'youtube',state:'fixture-aggregate',ownerUntil:new Date(Date.now()+3600000)}]});
      await core.db.temporaryAsset.create({data:{id:asset,jobId:aggregateJob,state:'fixture-aggregate',path:'p27/'+asset+'/never-created.mp4',size:0n}});
      await core.db.transferLease.createMany({data:[{id:lease,assetId:asset,state:'finished',bytes:9007199254740993n,reserved:0n,month:owned.budgetMonth,expiresAt:new Date(0),endedAt:new Date()},{id:zeroLease,assetId:asset,state:'fixture-zero',bytes:0n,reserved:0n,month:owned.budgetMonth,expiresAt:new Date(0),endedAt:new Date()}]});
      await core.db.egressBudget.create({data:{month:owned.budgetMonth,charged:9007199254740995n}});
      raw('dashboard-prestate',{fixtureOnly:true,directDB:true,noJobAPI:true,noQueueOrWorker:true,noMediaCreated:true,jobIds:owned.jobIds,assetId:asset,leaseIds:owned.leaseIds,bytes:'9007199254740993',charged:'9007199254740995',counts:await counts()});
      const r=await call('/api/v1/admin/dashboard','GET',200,undefined,readonlyAdmin());const d=r.body;
      assert.deepEqual(d.groups.find((g:any)=>g.state==='failed'),{state:'failed',_count:2});assert.deepEqual(d.groups.find((g:any)=>g.state==='fixture-aggregate'),{state:'fixture-aggregate',_count:1});
      assert.deepEqual(d.leases.find((g:any)=>g.state==='finished'),{state:'finished',_count:1,_sum:{bytes:'9007199254740993'}});assert.equal(d.leases.find((g:any)=>g.state==='fixture-zero')._sum.bytes,'0');
      assert.deepEqual(d.budget,[{month:owned.budgetMonth,charged:'9007199254740995'}]);assert(d.failed.some((f:any)=>f.id===nullJob&&f.errorCode===null&&f.platform==='fixture-platform'));assert(d.failed.some((f:any)=>f.id===errorJob&&f.errorCode==='LIMIT_EXCEEDED'));
      for(const f of d.failed){const j=await core.db.downloadJob.findUnique({where:{id:f.id}});assert.equal(f.updatedAt,j.updatedAt.toISOString());}
      assert.deepEqual(d.events.map((e:any)=>({type:e.type,count:e._count})).sort((a:any,b:any)=>a.type.localeCompare(b.type)),[{type:'click',count:1},{type:'impression',count:1}]);assert.deepEqual(d.queue,queueBefore);assert.deepEqual(d.verified,['youtube']);
      raw('dashboard-readback',{bigIntStrings:true,aboveSafeInteger:true,zeroBytesString:true,nullableError:true,dateReadback:true,eventsRows:2,queueUnchanged:true});
    });
    await run('delete-token-profiles',async()=>{await unchanged(async()=>{await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',403,{extra:true},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'},'CSRF_INVALID');await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',403,{csrf,extra:true},{...both(),'x-csrf-token':'wrong'},'CSRF_INVALID');});});
    await run('delete-header-extra-success',async()=>{const c=await call('/api/v1/admin/campaigns','POST',201,{...campaign,imageUrl:null,enabled:false},both());await audit('campaign.create',c.body.id);await call('/api/v1/admin/campaigns/'+c.body.id,'DELETE',200,{extra:true},both());assert.equal(await core.db.adCampaign.findUnique({where:{id:c.body.id}}),null);await audit('campaign.delete',c.body.id);});
    await run('delete-fallback-extra-success',async()=>{await call('/api/v1/admin/campaigns/'+campaignId,'DELETE',200,{csrf,extra:true},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'});assert.equal(await core.db.adCampaign.findUnique({where:{id:campaignId}}),null);assert.equal(await core.db.adEvent.count({where:{id:{in:owned.eventIds}}}),0);await audit('campaign.delete',campaignId);raw('delete-readback',{id:campaignId,eventCascade:true,fallbackBodyWithExtra:true});});
    await run('logout-token-profiles',async()=>{for(const h of [{Cookie:guestCookie+'; '+adminCookie,'x-csrf-token':csrf},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'},{...both(),'x-csrf-token':'wrong'}]){await call('/api/v1/admin/logout','POST',403,h['x-csrf-token']==='wrong'?{csrf}:undefined,h as any,'CSRF_INVALID');assert.equal(await core.redis.exists(adminKey),1,'failed logout retains token');}});
    await run('logout-fallback-extra-success',async()=>{const r=await call('/api/v1/admin/logout','POST',201,{csrf,extra:true},{Cookie:guestCookie+'; '+adminCookie,Origin:'http://p27.local'});assert.equal(await core.redis.exists(adminKey),0);assert(cookieFlags(r.headers).cleared,'admin clear cookie');raw('logout-readback',{tokenRevoked:true,cookieCleared:true});});
    await run('admin-after-logout',async()=>{for(const path of ['dashboard','settings','campaigns'])await call('/api/v1/admin/'+path,'GET',403,undefined,readonlyAdmin(),'ADMIN_REQUIRED');});
    await run('logout-no-admin-header-extra',async()=>{await call('/api/v1/admin/logout','POST',201,{extra:true},guest());});
    await run('logout-no-admin-body-extra',async()=>{await call('/api/v1/admin/logout','POST',201,{csrf,extra:true},{Cookie:guestCookie,Origin:'http://p27.local'});});
    assert.equal(caseResults.length,cases.length,'entire frozen matrix ran');assert.equal(new Set(caseResults.map(c=>c.name)).size,cases.length);for(const [method,path]of operationSuccess)assert(success.has(method+' '+path),'11operation success coverage');
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
  raw('summary',{passed,failed,result:failed?'FAIL':'PASS',requests,maxRequests,successOperations:[...success].sort(),successCount:success.size,counters,cleanupOk,scope:'real local HTTP admin/ads with own PostgreSQL/Redis; aggregation DB fixtures not lifecycle/media/platform proof'});if(failed)process.exitCode=1;
}
main().catch(e=>{raw('HARNESS_FAIL',{error:safeError(e),scope:'startup/fixture/isolation or final guard, not automatically a production bug'});process.exitCode=1;});
