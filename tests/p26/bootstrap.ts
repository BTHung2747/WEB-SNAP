import 'reflect-metadata';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,readlinkSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {NestFactory} from '@nestjs/core';
import ts from 'typescript';
import {z} from 'zod';

export const canonical=(v:any):any=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
export const sha=(p:string)=>createHash('sha256').update(readFileSync(p)).digest('hex');
export const raw=(stage:string,data:any)=>console.log('P26_RAW '+JSON.stringify({stage,utc:new Date().toISOString(),vn:new Date(Date.now()+25200000).toISOString().replace('Z','+07:00'),...data}));
function expression(path:string,method:string,find:(node:ts.Node)=>ts.Node|undefined){
  const file=ts.createSourceFile(path,readFileSync(path,'utf8'),ts.ScriptTarget.Latest,true);let found:ts.Node|undefined;
  const walk=(node:ts.Node)=>{if(ts.isMethodDeclaration(node)&&node.name.getText(file)===method){const scan=(child:ts.Node)=>{const x=find(child);if(x){assert(!found,'ambiguous expression');found=x;}ts.forEachChild(child,scan);};scan(node);}else ts.forEachChild(node,walk);};walk(file);assert(found,'production expression missing');
  const text=found.getText(file);raw('production-expression',{path,method,sourceSha:sha(path),expression:text,expressionSha:createHash('sha256').update(text).digest('hex'),scope:'AST extracts exact production pure expression; no service/auth/datastore call, no rewritten validator'});return text;
}
export async function generated(){
  assert.equal(process.env.P26_GUARD,'wed-snap-contract-admin-lab');assert.equal(process.env.DATABASE_URL,'postgresql://p26@127.0.0.1:9/wed_snap_admin_contract_unused');assert.equal(process.env.REDIS_URL,'redis://127.0.0.1:9/13');
  const paths=['apps/api/src/openapi.ts','apps/api/src/main.ts','apps/api/src/controllers/session.controller.ts','apps/api/src/controllers/jobs.controller.ts','apps/api/src/controllers/downloads.controller.ts','apps/api/src/controllers/admin.controller.ts','apps/api/src/controllers/ads.controller.ts'];const hashes=Object.fromEntries(paths.map(p=>[p,sha(p)]));assert.equal(createHash('sha256').update(paths.map(p=>p+':'+hashes[p]).join('|')).digest('hex'),process.env.P26_SOURCE_SHA);
  const req=createRequire(__filename),mod=req('node:module'),net=req('node:net');const saved={load:mod._load,connect:net.Socket.prototype.connect,listen:net.Server.prototype.listen};
  const counts={prismaConstructors:0,redisConstructors:0,queueConstructors:0,datastoreCalls:0,dials:0,listens:0};
  const forbidden=(kind:string):any=>new Proxy(function(){},{get(_t,key){if(key==='then'||typeof key==='symbol')return undefined;return forbidden(kind+'.'+String(key));},apply(){counts.datastoreCalls++;throw Error('Forbidden datastore '+kind);}});
  class NoDatabase{constructor(){counts.prismaConstructors++;return forbidden('Prisma');}}class NoRedis{constructor(){counts.redisConstructors++;return forbidden('Redis');}}class NoQueue{constructor(){counts.queueConstructors++;return forbidden('Queue');}}
  net.Socket.prototype.connect=function(){counts.dials++;throw Error('Forbidden offline dial');};net.Server.prototype.listen=function(){counts.listens++;throw Error('Forbidden offline listen');};
  // Load generated Prisma metadata without constructing a client; deny I/O first.
  const prisma=req('@prisma/client');
  mod._load=function(name:string,...args:any[]){if(name==='@prisma/client')return {PrismaClient:NoDatabase,Prisma:prisma.Prisma};if(name==='ioredis')return NoRedis;if(name==='bullmq')return {Queue:NoQueue};return saved.load.call(this,name,...args);};
  let app:any;
  try{
    const {AppModule}=await import('../../apps/api/src/app.module');const api=await import('../../apps/api/src/openapi');app=await NestFactory.create(AppModule,{logger:false,abortOnError:false});const doc=api.createOpenApiDocument(app);
    const controllers=Object.values(await import('../../apps/api/src/controllers/admin.controller')).concat(Object.values(await import('../../apps/api/src/controllers/ads.controller')) as any);
    const routes=controllers.flatMap((c:any)=>Object.getOwnPropertyNames(c.prototype).filter(k=>k!=='constructor').map(k=>({controller:c.name,handler:k,base:Reflect.getMetadata('path',c),path:Reflect.getMetadata('path',c.prototype[k]),method:Reflect.getMetadata('method',c.prototype[k]),httpCode:Reflect.getMetadata('__httpCode__',c.prototype[k])})));
    const validation=await import('../../apps/api/src/validation'),core=await import('../../packages/shared/src/core');
    const eventText=expression('apps/api/src/services/ads.service.ts','adEvent',n=>ts.isCallExpression(n)&&n.expression.getText()==='parse'?n.arguments[0]:undefined);
    const eventSchema=Function('z','uuid','return ('+eventText+')')(z,validation.uuid);
    const enabledText=expression('apps/api/src/services/admin.service.ts','saveSettings',n=>ts.isIfStatement(n)&&n.expression.getText().includes('enabledPlatforms.some')?n.expression:undefined);
    const enabledRejected=(value:any,verified:string[])=>Function('value','verified','return ('+enabledText+')')(value,verified);
    const placementText=expression('apps/api/src/services/ads.service.ts','ads',n=>ts.isVariableDeclaration(n)&&n.name.getText()==='placement'?n.initializer:undefined);
    const placement=(value:any)=>Function('req','return ('+placementText+')')({query:{placement:value}});
    const {RouterResponseController}=req('@nestjs/core/router/router-response-controller');const framework=new RouterResponseController({});
    // Actual Nest status selection runs before manual @Res handlers too.
    const routerSource=readFileSync('node_modules/@nestjs/core/router/router-execution-context.js','utf8');assert(routerSource.includes('this.responseController.setStatus(res, httpStatusCode)'));
    const versions=Object.fromEntries(['@nestjs/core','@nestjs/platform-express','express','@nestjs/swagger','typescript','@prisma/client','zod'].map(p=>[p,JSON.parse(readFileSync('node_modules/'+p+'/package.json','utf8')).version]));
    raw('environment',{node:process.version,versions,namespace:readlinkSync('/proc/self/ns/pid'),hashes,sourceSha:process.env.P26_SOURCE_SHA,testSha:sha('tests/p26/matrix.ts'),bootstrapSha:sha('tests/p26/bootstrap.ts'),expectedSha:sha('tests/p26/expectations.ts'),snapshotSha:sha('docs/openapi.json'),prismaSchemaSha:sha('prisma/schema.prisma'),frameworkSourceSha:sha('node_modules/@nestjs/core/router/router-execution-context.js'),routes,counts,stubs:['Prisma/Redis/Queue constructor-only deny BEFORE core; nested methods throw/count','all Socket.connect/Server.listen denied; network none','schema/output fixtures + production AST pure expression extraction, no copied validator or business methods']});
    await app.close();app=null;return {doc,counts,routes,validation,core,eventSchema,enabledRejected,placement,framework,models:prisma.Prisma.dmmf.datamodel.models};
  }finally{if(app)await app.close();mod._load=saved.load;net.Socket.prototype.connect=saved.connect;net.Server.prototype.listen=saved.listen;raw('finally',{counts,hooksRestored:true,noDatastore:counts.datastoreCalls===0,noDial:counts.dials===0,noListen:counts.listens===0});assert.equal(counts.datastoreCalls,0);assert.equal(counts.dials,0);assert.equal(counts.listens,0);}
}
