import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync, readlinkSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';

export const canonical = (v:any):any => Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
export const sha=(p:string)=>createHash('sha256').update(readFileSync(p)).digest('hex');
export const raw=(stage:string,data:any)=>console.log('P25_RAW '+JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...data}));
export async function withLab<T>(httpEnabled:boolean,run:(lab:any)=>Promise<T>):Promise<T>{
  assert.equal(process.env.P25_GUARD,'wed-snap-parser-lab');
  assert.equal(process.env.DATABASE_URL,'postgresql://p25@127.0.0.1:9/wed_snap_parser_unused');
  assert.equal(process.env.REDIS_URL,'redis://127.0.0.1:9/13');
  assert(!process.env.TRUSTED_PROXY_HOSTS,'no DNS from identity middleware');
  const paths=['apps/api/src/openapi.ts','apps/api/src/main.ts','apps/api/src/controllers/session.controller.ts','apps/api/src/controllers/jobs.controller.ts','apps/api/src/controllers/downloads.controller.ts','apps/api/src/controllers/admin.controller.ts','apps/api/src/controllers/ads.controller.ts'];
  const hashes=Object.fromEntries(paths.map(p=>[p,sha(p)]));
  assert.equal(createHash('sha256').update(paths.map(p=>p+':'+hashes[p]).join('|')).digest('hex'),process.env.P25_SOURCE_SHA);
  const req=createRequire(__filename),mod=req('node:module'),net=req('node:net'),http=req('node:http');
  const saved={load:mod._load,connect:net.Socket.prototype.connect,listen:net.Server.prototype.listen};
  const counts={prismaConstructors:0,redisConstructors:0,queueConstructors:0,datastoreCalls:0,allowedDials:0,allowedListens:0,deniedDials:0,deniedListens:0};
  // No fake successful datastore calls; even an accidental read fails isolation.
  const forbidden=(kind:string):any=>new Proxy(function(){}, {
    get(_t,key){if(key==='then'||typeof key==='symbol')return undefined;return forbidden(kind+'.'+String(key));},
    apply(){counts.datastoreCalls++;throw Error('Forbidden datastore '+kind);},
  });
  class NoDatabase {constructor(){counts.prismaConstructors++;return forbidden('Prisma');}}
  class NoRedis {constructor(){counts.redisConstructors++;return forbidden('Redis');}}
  class NoQueue {constructor(){counts.queueConstructors++;return forbidden('Queue');}}
  mod._load=function(name:string,...args:any[]){if(name==='@prisma/client')return {PrismaClient:NoDatabase,Prisma:{}};if(name==='ioredis')return NoRedis;if(name==='bullmq')return {Queue:NoQueue};return saved.load.call(this,name,...args);};
  let port=0,server:any,app:any;
  const clients=new Set<any>(),peers=new Set<any>();
  net.Server.prototype.listen=function(...args:any[]){
    if(!httpEnabled||server||args[0]!==0||args[1]!=='127.0.0.1'||!(this instanceof http.Server)){counts.deniedListens++;throw Error('Forbidden listen');}
    server=this;counts.allowedListens++;return saved.listen.apply(this,args);
  };
  net.Socket.prototype.connect=function(...args:any[]){
    const normalized=Array.isArray(args[0])?args[0]:args;
    const opts=typeof normalized[0]==='object'?normalized[0]:{port:normalized[0],host:normalized[1]};
    if(!httpEnabled||!port||opts.host!=='127.0.0.1'||Number(opts.port)!==port||opts.path){counts.deniedDials++;throw Error('Forbidden dial');}
    counts.allowedDials++;clients.add(this);this.once('close',()=>clients.delete(this));return saved.connect.apply(this,args);
  };
  try{
    const {AppModule}=await import('../../apps/api/src/app.module');
    const {SafeErrors}=await import('../../apps/api/src/filters/safe-errors.filter');
    const {AppError}=await import('../../packages/shared/src/core');
    const {HttpException}=await import('@nestjs/common');
    const {clientIdentityMiddleware}=await import('../../apps/api/src/security/client-ip');
    const api=await import('../../apps/api/src/openapi');
    app=await NestFactory.create(AppModule,{logger:false,abortOnError:false});
    // Same production middleware order/config as main, without running main.ts.
    app.getHttpAdapter().getInstance().set('trust proxy',false);
    app.use(clientIdentityMiddleware());app.use(helmet({contentSecurityPolicy:false}));app.use(cookieParser());
    app.useGlobalFilters(new SafeErrors());
    const doc=api.createOpenApiDocument(app);SwaggerModule.setup('api/docs',app,doc);
    app.use((_request:any,response:any,next:any)=>{response.setHeader('Cache-Control','no-store');next();});
    const controllers=Object.values(await import('../../apps/api/src/controllers/session.controller')).concat(Object.values(await import('../../apps/api/src/controllers/jobs.controller')) as any).concat(Object.values(await import('../../apps/api/src/controllers/downloads.controller')) as any);
    const routes=controllers.flatMap((c:any)=>Object.getOwnPropertyNames(c.prototype).filter(k=>k!=='constructor').map(k=>({controller:c.name,handler:k,base:Reflect.getMetadata('path',c),path:Reflect.getMetadata('path',c.prototype[k]),method:Reflect.getMetadata('method',c.prototype[k])})));
    const validation=await import('../../apps/api/src/validation');
    if(httpEnabled){await app.listen(0,'127.0.0.1');port=server.address().port;assert(port>0);assert.equal(server.address().address,'127.0.0.1');server.on('connection',(s:any)=>{peers.add(s);s.once('close',()=>peers.delete(s));});}
    const versions=Object.fromEntries(['@nestjs/core','@nestjs/platform-express','express','body-parser','router','@nestjs/swagger','typescript','@prisma/client'].map(p=>[p,JSON.parse(readFileSync('node_modules/'+p+'/package.json','utf8')).version]));
    raw('environment',{node:process.version,versions,namespace:readlinkSync('/proc/self/ns/pid'),hashes,sourceSha:process.env.P25_SOURCE_SHA,testSha:sha('tests/p25/matrix.ts'),bootstrapSha:sha('tests/p25/bootstrap.ts'),expectedSha:sha('tests/p25/expectations.ts'),snapshotSha:sha('docs/openapi.json'),docsSha:sha('docs/API.md'),routes,counts,server:{httpEnabled,host:'127.0.0.1',port},stubs:['constructor-only Prisma/Redis/Queue deny BEFORE core','only single loopback server + exact port clients permitted','ArgumentsHost/response recorder for filter unit only; no parser/filter verdict mock']});
    return await run({doc,counts,routes,validation,app,port,server,net,http,SafeErrors,AppError,HttpException});
  }finally{
    // Await native close events, not a guessed number of event-loop turns.
    const closing=[...new Set([...clients,...peers])].map(s=>new Promise<void>((resolve,reject)=>{
      const timer=setTimeout(()=>reject(Error('socket close deadline2s')),2000);
      s.once('close',()=>{clearTimeout(timer);resolve();});s.destroy();
    }));
    await Promise.all(closing);
    if(app)await app.close();
    await new Promise(r=>setImmediate(r));
    const closed=!server||!server.listening;
    mod._load=saved.load;net.Socket.prototype.connect=saved.connect;net.Server.prototype.listen=saved.listen;
    raw('finally',{counts,hooksRestored:true,serverClosed:closed,clientsRemaining:clients.size,peersRemaining:peers.size,noDatastore:counts.datastoreCalls===0});
    assert(closed);assert.equal(counts.datastoreCalls,0,'isolation, not runtime verdict');assert.equal(clients.size,0);assert.equal(peers.size,0);
  }
}
// Contract regression/generator use the same real factory with listen disabled.
export async function generated(){return withLab(false,async({doc,counts,routes,validation})=>({doc,counts,routes,validation}));}
