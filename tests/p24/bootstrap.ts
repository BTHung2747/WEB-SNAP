import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFileSync, readlinkSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export const canonical = (value: any): any => Array.isArray(value) ? value.map(canonical) :
  value && typeof value === 'object' ? Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])])) : value;
export const sha = (p: string) => createHash('sha256').update(readFileSync(p)).digest('hex');
export const raw = (stage: string, value: object) => console.log('P24_RAW '+JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...value}));
export async function generated() {
  assert.equal(process.env.P24_GUARD, 'wed-snap-openapi-lab');
  assert.equal(process.env.DATABASE_URL, 'postgresql://p24@127.0.0.1:9/wed_snap_openapi_unused');
  assert.equal(process.env.REDIS_URL, 'redis://127.0.0.1:9/13');
  const paths=['apps/api/src/openapi.ts','apps/api/src/main.ts','apps/api/src/controllers/session.controller.ts','apps/api/src/controllers/jobs.controller.ts','apps/api/src/controllers/downloads.controller.ts','apps/api/src/controllers/admin.controller.ts','apps/api/src/controllers/ads.controller.ts'];
  const hashes=Object.fromEntries(paths.map(p=>[p,sha(p)]));
  assert.equal(createHash('sha256').update(paths.map(p=>p+':'+hashes[p]).join('|')).digest('hex'),process.env.P24_SOURCE_SHA);
  const req=createRequire(__filename), moduleClass=req('node:module'), net=req('node:net'), http=req('node:http');
  const load=moduleClass._load, connect=net.Socket.prototype.connect, listen=http.Server.prototype.listen;
  const counts={prismaConstructors:0,redisConstructors:0,queueConstructors:0,datastoreCalls:0,dials:0,listens:0};
  const forbidden=(kind:string) => new Proxy({}, {get(_t,key){if(key==='then')return undefined;if(typeof key==='symbol')return undefined;return (..._args:any[])=>{counts.datastoreCalls++;throw new Error('Forbidden offline datastore call '+kind+'.'+String(key));};}});
  class NoDatabase {constructor(){counts.prismaConstructors++;return forbidden('Prisma');}}
  class NoRedis {constructor(){counts.redisConstructors++;return forbidden('Redis');}}
  class NoQueue {constructor(){counts.queueConstructors++;return forbidden('BullMQ');}}
  // Constructor I/O doubles installed BEFORE AppModule/services/core are loaded.
  // Never substitute route/controller/Swagger/verdict logic; any datastore method fails.
  moduleClass._load=function(name:string,...args:any[]){
    if(name==='@prisma/client') return {PrismaClient:NoDatabase,Prisma:{}};
    if(name==='ioredis')return NoRedis;
    if(name==='bullmq')return {Queue:NoQueue};
    return load.call(this,name,...args);
  };
  net.Socket.prototype.connect=function(){counts.dials++;throw new Error('Offline contract attempted socket dial');};
  http.Server.prototype.listen=function(){counts.listens++;throw new Error('Offline contract attempted HTTP listen');};
  let app:any;
  try {
    const {AppModule}=await import('../../apps/api/src/app.module');
    const api=await import('../../apps/api/src/openapi');
    app=await NestFactory.create(AppModule,{logger:false});
    // Baseline uses the original production pipeline verbatim. After extraction,
    // main and this generator both call the exported production factory.
    const doc=(api as any).createOpenApiDocument ? (api as any).createOpenApiDocument(app) : SwaggerModule.createDocument(app,
      new DocumentBuilder().setTitle('WED SNAP').setVersion('0.1.0').addCookieAuth('ws_session').addApiKey({type:'apiKey',in:'header',name:'x-csrf-token'},'csrf').build());
    if(!(api as any).createOpenApiDocument)api.describeContracts(doc);
    const controllers=Object.values(await import('../../apps/api/src/controllers/session.controller'))
      .concat(Object.values(await import('../../apps/api/src/controllers/jobs.controller')) as any)
      .concat(Object.values(await import('../../apps/api/src/controllers/downloads.controller')) as any);
    const routes=controllers.flatMap((controller:any)=>Object.getOwnPropertyNames(controller.prototype).filter(k=>k!=='constructor').map(k=>({
      controller:controller.name,handler:k,base:Reflect.getMetadata('path',controller),path:Reflect.getMetadata('path',controller.prototype[k]),method:Reflect.getMetadata('method',controller.prototype[k]),
    })));
    const validation=await import('../../apps/api/src/validation');
    raw('environment',{node:process.version,typescript:JSON.parse(readFileSync('node_modules/typescript/package.json','utf8')).version,swagger:JSON.parse(readFileSync('node_modules/@nestjs/swagger/package.json','utf8')).version,prisma:JSON.parse(readFileSync('node_modules/@prisma/client/package.json','utf8')).version,namespace:readlinkSync('/proc/self/ns/pid'),hashes,testSha:sha('tests/p24/contracts.ts'),bootstrapSha:sha('tests/p24/bootstrap.ts'),snapshotSha:sha('docs/openapi.json'),routes,counts,stubs:['Prisma/Redis/BullMQ constructor-only deny doubles before load','Socket.connect/Server.listen deny','no database/Redis service/HTTP/worker/business methods; network none hard fence']});
    await app.close();app=null;
    assert.deepEqual(counts,{prismaConstructors:1,redisConstructors:1,queueConstructors:1,datastoreCalls:0,dials:0,listens:0});
    return {doc,counts,routes,validation};
  } finally {
    if(app)await app.close();moduleClass._load=load;net.Socket.prototype.connect=connect;http.Server.prototype.listen=listen;
    raw('finally',{counts,hooksRestored:true,noListen:counts.listens===0,noDatastore:counts.datastoreCalls===0,noDial:counts.dials===0});
  }
}
