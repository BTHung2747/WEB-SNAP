import 'reflect-metadata';
import assert from 'node:assert/strict';
import {createHash,randomBytes,randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {readFileSync,readlinkSync,writeFileSync} from 'node:fs';
const digest=(s:string)=>createHash('sha256').update(s).digest('hex');
const privateValues=new Set<string>();
const protect=(s:string)=>{if(s.length>=12)privateValues.add(s);return s;};
function raw(stage:string,data:any){const line=JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...data},(_k,v)=>typeof v==='bigint'?String(v):v);for(const s of privateValues)assert(!line.includes(s),'secret in evidence');console.log('P29_RAW '+line);}
async function main(){
 assert.equal(process.env.P29_GUARD,'wed-snap-admin-browser-lab');assert.equal(process.env.DATABASE_URL,'postgresql://p29@db:5432/wed_snap_admin_browser_test');assert.equal(process.env.REDIS_URL,'redis://redis:6379/13');assert.equal(process.env.APP_ORIGIN,'http://p29.localhost:5179');assert.equal(process.env.MEDIA_ROOT,'/tmp/p29-no-media');assert.equal(process.env.COOKIE_SECURE,'false');assert.equal(process.env.TRUSTED_PROXY_HOSTS,'');assert.equal(process.env.ADMIN_SESSION_SECRET,'p29-unused-sentinel-replaced-in-memory');
 const coordinates=JSON.parse(readFileSync('/tmp/p29/coordinates.json','utf8'));
 const hashes=Object.fromEntries(coordinates.sources.map((p:string)=>[p,digest(readFileSync(p,'utf8'))]));
 assert.equal(digest(coordinates.sources.map((p:string)=>p+':'+hashes[p]).join('|')),coordinates.sourceSHA);assert.equal(coordinates.sourceSHA,process.env.P29_SOURCE_SHA);
 process.env.ADMIN_SESSION_SECRET=protect(randomBytes(32).toString('hex'));
 const req=createRequire(__filename),net=req('node:net');const savedConnect=net.Socket.prototype.connect,savedListen=net.Server.prototype.listen;
 const counters={redisDials:0,allowedListens:0,deniedDials:0,deniedListens:0};let server:any;
 net.Socket.prototype.connect=function(...args:any[]){const a=Array.isArray(args[0])?args[0]:args,o=typeof a[0]==='object'?a[0]:{port:a[0],host:a[1]};if(Number(o.port)!==6379||!['redis',coordinates.redisIP].includes(o.host)){counters.deniedDials++;throw Error('Foreign socket denied');}counters.redisDials++;return savedConnect.apply(this,args);};
 net.Server.prototype.listen=function(...args:any[]){const o=typeof args[0]==='object'?args[0]:{port:args[0],host:args[1]};if(server||Number(o.port)!==3000||o.host!=='0.0.0.0'){counters.deniedListens++;throw Error('Foreign listener denied');}server=this;counters.allowedListens++;return savedListen.apply(this,args);};
 const IORedis=req('ioredis');const inspector=new IORedis(process.env.REDIS_URL,{maxRetriesPerRequest:1});
 assert(/\bdb=13\b/.test(String(await inspector.client('INFO'))));const redisInfo=String(await inspector.info('server'));assert(redisInfo.includes('run_id:'+coordinates.redisRun));assert.deepEqual(await inspector.keys('*'),[]);
 const {PrismaClient}=await import('@prisma/client');const preflight=new PrismaClient();
 try{const rows:any[]=await preflight.$queryRaw`SELECT current_database() AS database,host(inet_server_addr()) AS host,version() AS version,(SELECT system_identifier::text FROM pg_control_system()) AS cluster`;assert.equal(rows[0].database,'wed_snap_admin_browser_test');assert.equal(rows[0].host,coordinates.dbIP);assert.equal(rows[0].cluster,coordinates.cluster);raw('datastore-identity',{database:rows[0].database,addressMatches:true,clusterMatches:true,postgres:rows[0].version,redisDb:13,redisRunMatches:true,redisVersion:/redis_version:([^\r\n]+)/.exec(redisInfo)?.[1],keysBefore:0});}finally{await preflight.$disconnect();}
 const core=await import('../../packages/shared/src/core');
 const counts=async()=>({session:await core.db.session.count(),admin:await core.db.adminUser.count(),campaign:await core.db.adCampaign.count(),event:await core.db.adEvent.count(),audit:await core.db.auditLog.count(),job:await core.db.downloadJob.count(),item:await core.db.mediaItem.count(),asset:await core.db.temporaryAsset.count(),lease:await core.db.transferLease.count(),ticket:await core.db.downloadTicket.count()});
 assert(Object.values(await counts()).every(v=>v===0),'Only empty own lab can seed');const settingsBefore=await core.db.settings.findMany(),budgetBefore=await core.db.egressBudget.findMany();assert.deepEqual(settingsBefore,[]);assert.deepEqual(budgetBefore,[]);
 const email='p29-'+randomUUID()+'@example.invalid',password=protect(randomBytes(32).toString('hex')),adminId=randomUUID(),campaignIds=new Set<string>(),sessionIds=new Set<string>();
 await core.db.adminUser.create({data:{id:adminId,email,passwordHash:core.passwordHash(password)}});
 const {NestFactory}=await import('@nestjs/core');const {AppModule}=await import('../../apps/api/src/app.module');const {SafeErrors}=await import('../../apps/api/src/filters/safe-errors.filter');const {clientIdentityMiddleware}=await import('../../apps/api/src/security/client-ip');
 const cookieParser=req('cookie-parser'),helmet=req('helmet');const app=await NestFactory.create(AppModule,{logger:false});app.getHttpAdapter().getInstance().set('trust proxy',false);app.use(clientIdentityMiddleware());app.use(helmet({contentSecurityPolicy:false}));app.use(cookieParser());app.useGlobalFilters(new SafeErrors());app.use((_r:any,res:any,next:any)=>{res.set('Cache-Control','no-store');next();});
 const records:any[]=[];let requestCount=0,order=0,cleanupStarted=false;
 const state=async()=>({counts:await counts(),settings:await core.db.settings.findMany(),effective:await core.limits(),budget:await core.db.egressBudget.findMany(),campaigns:await core.db.adCampaign.findMany({orderBy:{startsAt:'desc'}}),audit:(await core.db.auditLog.findMany({orderBy:{createdAt:'asc'}})).map(r=>({id:r.id,action:r.action,actorMatches:r.actor===email,actorHash:digest(r.actor),detail:r.detail,createdAt:r.createdAt})),queue:{waiting:await core.queue.getWaitingCount(),active:await core.queue.getActiveCount()},requests:records,counters,sourceSHA:coordinates.sourceSHA});
 async function cleanup(){
  if(cleanupStarted)throw Error('Cleanup already started');cleanupStarted=true;
  const before=await counts();assert.equal(before.admin,1);assert.equal(before.job+before.item+before.asset+before.lease+before.ticket+before.event,0);assert.equal(before.session,sessionIds.size);assert.equal(before.campaign,campaignIds.size);
  assert.equal(await core.db.auditLog.count({where:{actor:{not:email}}}),0,'No foreign audit row');
  const writtenSettings=await core.db.settings.findMany();assert(writtenSettings.every(r=>r.id==='main'));assert.deepEqual(await core.db.egressBudget.findMany(),budgetBefore,'Charged untouched');
  raw('cleanup-before',{counts:before,settingsBefore,settingsCurrent:writtenSettings,budgetUnchanged:true,sessionIds:[...sessionIds],campaignIds:[...campaignIds]});
  assert.equal(settingsBefore.length,0,'Boot guard permits only empty own settings baseline');
  await core.db.$transaction(async tx=>{await tx.adCampaign.deleteMany({where:{id:{in:[...campaignIds]}}});await tx.auditLog.deleteMany({where:{actor:email}});await tx.session.deleteMany({where:{id:{in:[...sessionIds]}}});await tx.adminUser.delete({where:{id:adminId}});await tx.settings.deleteMany({where:{id:'main'}});});
  await core.queue.close();const ownKeys=(await core.redis.keys('*')).sort();assert(ownKeys.every(k=>/^(rate:|admin:|bull:media:)/.test(k)),'Only known lab-created key prefixes');if(ownKeys.length)await core.redis.del(...ownKeys);
  assert.deepEqual(await core.db.settings.findMany(),settingsBefore);assert.deepEqual(await core.db.egressBudget.findMany(),budgetBefore);assert.deepEqual(await core.redis.keys('*'),[]);assert(Object.values(await counts()).every(v=>v===0));
  assert.equal(counters.deniedDials+counters.deniedListens,0);raw('cleanup-pass',{counts:await counts(),settingsDeepEqual:true,budgetDeepEqual:true,chargedUnchanged:true,ownedKeysRemoved:ownKeys.length,knownPrefixesOnly:true,requestCount,counters});
  setTimeout(async()=>{await app.close();await core.redis.quit();await inspector.quit();await core.db.$disconnect();net.Socket.prototype.connect=savedConnect;net.Server.prototype.listen=savedListen;raw('close-pass',{serverClosed:true,datastoreClientsClosed:true,hooksRestored:true});writeFileSync('/tmp/p29/closed','PASS');},100);
 }
 app.use(async(r:any,res:any,next:any)=>{
  if(r.url.startsWith('/__p29/')){try{
   if(r.method==='GET'&&r.url==='/__p29/credentials'){res.json({email,password});return;}
   if(r.method==='GET'&&r.url==='/__p29/state'){res.json(await state());return;}
   if(r.method==='POST'&&r.url==='/__p29/cleanup'){await cleanup();res.json({ok:true});return;}
   if(r.method==='POST'&&r.url==='/__p29/record'){let body='';r.on('data',(c:Buffer)=>{body+=c;if(Buffer.byteLength(body)>131072)r.destroy();});r.on('end',()=>{try{const data=JSON.parse(body);raw('browser',data);res.json({ok:true});}catch{res.status(400).json({error:'record rejected'});}});return;}
   res.status(404).end();return;
  }catch{raw('diagnostic-fail',{path:r.url,details:'suppressed'});res.status(500).json({error:'lab diagnostic failure'});return;}}
  if(!/^\/api\/v1\/(session$|admin\/(login|logout|dashboard|settings|campaigns(?:\/[0-9a-f-]+)?)$)/.test(r.url)){res.status(403).end();return;}
  if(++requestCount>150){res.status(503).end();return;}
  const num=requestCount,startOrder=++order,start=performance.now(),out:any={};const realJson=res.json.bind(res);res.json=(value:any)=>{out.body=value;return realJson(value);};
  res.on('finish',()=>{
   const cookies=(res.getHeader('set-cookie')||[]) as string[];const cookieText=Array.isArray(cookies)?cookies.join(';'):String(cookies);
   for(const c of Array.isArray(cookies)?cookies:[cookies]){const token=String(c).split(';')[0].split('=').slice(1).join('=');if(token)protect(decodeURIComponent(token));if(String(c).startsWith('ws_session=')&&token)sessionIds.add(core.hash(token));}
   if(typeof out.body?.csrf==='string')protect(out.body.csrf);
   if(r.method==='POST'&&r.url==='/api/v1/admin/campaigns'&&res.statusCode===201&&typeof out.body?.id==='string')campaignIds.add(out.body.id);
   if(r.method==='DELETE'&&res.statusCode===200)campaignIds.delete(r.url.split('/').pop());
   const record={num,startOrder,finishOrder:++order,method:r.method,path:r.url,status:res.statusCode,ms:Math.round((performance.now()-start)*1000)/1000,bodyKeys:r.body&&typeof r.body==='object'?Object.keys(r.body):[],responseKeys:out.body&&typeof out.body==='object'?Object.keys(out.body):[],bodyBytes:Buffer.byteLength(JSON.stringify(out.body||null)),code:out.body?.error?.code||null,role:r.cookies?.ws_admin?(r.cookies?.ws_session?'admin+guest':'admin-only'):(r.cookies?.ws_session?'guest':'none'),csrfHeader:!!r.get('x-csrf-token'),origin:r.get('origin')===core.origin?'own':r.get('origin')?'foreign':'missing',noStore:res.getHeader('cache-control')==='no-store',nosniff:res.getHeader('x-content-type-options')==='nosniff',cookieFlags:{present:!!cookieText,httpOnly:/HttpOnly/i.test(cookieText),lax:/SameSite=Lax/i.test(cookieText),pathApi:/Path=\/api(?:;|$)/i.test(cookieText),secure:/\bSecure\b/i.test(cookieText),cleared:/Expires=Thu, 01 Jan 1970/i.test(cookieText)},response:r.url==='/api/v1/session'?{...out.body,csrf:'[REDACTED]'}:out.body};records.push(record);raw('http',record);
  });next();
 });
 raw('environment',{hashes,sourceSHA:coordinates.sourceSHA,node:process.version,namespace:readlinkSync('/proc/self/ns/pid'),versions:Object.fromEntries(['@nestjs/core','@prisma/client','ioredis','bullmq','typescript'].map(p=>[p,req(p+'/package.json').version])),bootstrap:'Production AppModule/clientIdentity/helmet/cookieParser/SafeErrors/no-store; same-origin proxy; one internal API listener; no main.ts/worker/business doubles',stubs:[],prismaNative:'DB numeric address/cluster guarded; JS fence only covers JS sockets, not native engine',settingsBefore,budgetBefore,counters});
 await app.listen(3000,'0.0.0.0');writeFileSync('/tmp/p29/ready','PASS');raw('ready',{seed:{adminCount:1,actorHash:digest(email)},passwordHashProduction:true,counters});
}
main().catch((e)=>{let message=String(e?.message||'failure');for(const s of privateValues)message=message.split(s).join('[REDACTED]');message=message.replace(/(?:postgresql|redis):\/\/\S+/g,'[DATASTORE URL REDACTED]');raw('bootstrap-fail',{type:e?.constructor?.name,message:message.slice(0,2000)});process.exitCode=1;});
