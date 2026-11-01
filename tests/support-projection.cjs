// Narrow successor: real Nest/auth/Prisma/PostgreSQL; only Redis/rate are fixtures.
// No upload/decoder suite rerun. Synthetic PNGs and isolated Settings only.
require('reflect-metadata');
const assert=require('node:assert/strict'),fs=require('node:fs'),Module=require('node:module'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process'),ts=require('/app/node_modules/typescript');
const {PrismaClient}=require('/app/node_modules/@prisma/client');
if(process.env.SUPPORT_TEST_GUARD!=='own-support-offline'||!/^postgresql:\/\/support_lab:.*@postgres:5432\/support_lab$/.test(process.env.DATABASE_URL||''))throw Error('LAB_ONLY');
const database=new PrismaClient(),queries=[];let projecting=false;
const db=new Proxy(database,{get(target,key){
 if(key==='$queryRaw')return async(...args)=>{
  assert(Array.isArray(args[0])&&args[0].raw); // Safe tagged template, no unsafe SQL string.
  const rows=await target.$queryRaw(...args);
  queries.push({sql:args[0].join('?'),parameters:args.slice(1),keys:rows.map(r=>Object.keys(r).sort()),bytes:Buffer.byteLength(JSON.stringify(rows))});
  return rows;
 };
 if(key==='settings'&&projecting)return new Proxy(target.settings,{get(model,operation){
  if(operation==='findUnique')return ()=>{throw Error('FULL_ROW_READ_FORBIDDEN');};
  const value=model[operation];return typeof value==='function'?value.bind(model):value;
 }});
 const value=target[key];return typeof value==='function'?value.bind(target):value;
}});
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
class AppError extends Error{constructor(code,status=400){super(code);this.code=code;this.status=status;}}
const actor='support-fixture@example.invalid',sessionToken='a'.repeat(64),adminToken='b'.repeat(64),csrf='FIXTURE_ONLY_CSRF';
process.env.APP_ORIGIN='http://support-fixture.invalid';process.env.ADMIN_SESSION_SECRET='SUPPORT_FIXTURE_SIGNING_ONLY_'.repeat(2);
const core='/app/packages/shared/src/core.ts',m=new Module(core);m.loaded=true;m.exports={db,AppError,hash,origin:process.env.APP_ORIGIN,
 rate:async()=>{},fail:(code,status=400)=>{throw new AppError(code,status);},redis:{get:async key=>key==='admin:'+hash(adminToken)?actor:null}};require.cache[core]=m;
function compiled(path){const source=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true}}).outputText;const m=new Module(path);m.exports={};m.loaded=true;require.cache[path]=m;new Function('require','module','exports',source)(Module.createRequire(path),m,m.exports);return m.exports;}
const base='/app/apps/api/src/';compiled(base+'auth/session.ts');
const common=new Module(base+'common.ts');common.loaded=true;common.exports={...require(base+'auth/session.ts'),...require(base+'validation.ts')};require.cache[base+'common.ts']=common;
const contract=compiled(base+'services/support-contract.ts');compiled(base+'services/support-image.ts');
const upload=compiled(base+'security/support-upload.ts');
const {SupportService}=compiled(base+'services/support.service.ts'),{SupportController}=compiled(base+'controllers/support.controller.ts');
const {SafeErrors}=compiled(base+'filters/safe-errors.filter.ts');
const {NestFactory}=require('/app/node_modules/@nestjs/core'),{Module:NestModule}=require('/app/node_modules/@nestjs/common'),cookieParser=require('/app/node_modules/cookie-parser');
class TestModule{};NestModule({controllers:[SupportController],providers:[SupportService,upload.SupportUploadGuard,upload.SupportUploadInterceptor]})(TestModule);
let app,port,stage='INIT';const cases=[];
const cookies=`ws_session=${sessionToken}; ws_admin=${adminToken}.${require(base+'auth/session.ts').sign(adminToken)}`;
async function call(path,method='GET',body,privateRequest=false){
 const r=await fetch(`http://127.0.0.1:${port}/api/v1/`+path,{method,headers:{...(privateRequest?{cookie:cookies,origin:process.env.APP_ORIGIN,'x-csrf-token':csrf}:{}),'content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(10000)});
 const data=Buffer.from(await r.arrayBuffer());let json;try{json=JSON.parse(data);}catch{}return {status:r.status,headers:r.headers,data,json};
}
async function projected(path,expectedStatus=200,privateRequest=false){
 const start=queries.length;projecting=true;let r;try{r=await call(path,'GET',undefined,privateRequest);}finally{projecting=false;}
 assert.equal(r.status,expectedStatus);const current=queries.slice(start);assert.equal(current.length,1);
 assert.equal(current[0].parameters[0],contract.supportId);return {r,q:current[0]};
}
function png(color){return execFileSync('ffmpeg',['-v','error','-nostdin','-f','lavfi','-i',`color=${color}:s=32x32`,'-frames:v','1','-threads','1','-c:v','png','-f','image2pipe','pipe:1'],{timeout:8000,stdio:['ignore','pipe','ignore']});}
const config={...contract.supportDefaults,title:'Fixture support',message:'Voluntary fixture'};
async function putRow(qr,pending,enabled){await database.settings.upsert({where:{id:contract.supportId},create:{id:contract.supportId,value:{version:1,config:{...config,enabled},qr,pending}},update:{value:{version:1,config:{...config,enabled},qr,pending}}});}
function image(data){return {id:hash(data),png:data.toString('base64'),width:32,height:32};}
(async()=>{
 await database.session.create({data:{id:hash(sessionToken),csrf,expiresAt:new Date(Date.now()+3600000)}});
 await database.settings.create({data:{id:'main',value:{fixtureSentinel:'DO_NOT_CHANGE'}}});
 app=await NestFactory.create(TestModule,{logger:false});app.use(cookieParser());app.useGlobalFilters(new SafeErrors());await app.listen(0,'127.0.0.1');port=app.getHttpServer().address().port;
 stage='MISSING';assert.deepEqual((await projected('support')).r.json,{enabled:false});
 stage='MAX_ROW_PROJECTION';const a=image(png('white')),b=image(png('black'));
 const largeA=image(Buffer.concat([Buffer.from(a.png,'base64'),Buffer.alloc(contract.qrLimit-Buffer.from(a.png,'base64').length)]));
 const largeB=image(Buffer.concat([Buffer.from(b.png,'base64'),Buffer.alloc(contract.qrLimit-Buffer.from(b.png,'base64').length)]));
 // Padding is a DB-size fixture, not proof of decoder acceptance for these PNGs.
 await putRow(largeA,{qr:largeB},false);
 const off=await projected('support');assert.deepEqual(off.r.json,{enabled:false});assert.deepEqual(off.q.keys,[['config','qrId','version']]);assert(off.q.bytes<1024);
 assert.deepEqual((await projected('support/qr/'+largeA.id,404)).q.keys,[]);
 await putRow(largeA,{qr:largeB},true);
 const on=await projected('support');assert.equal(on.r.json.qrUrl,'/api/v1/support/qr/'+largeA.id);assert(on.q.bytes<1024);
 assert.deepEqual((await projected('support/qr/'+largeB.id,404)).q.keys,[]);
 assert.deepEqual((await projected('support/qr/'+'f'.repeat(64),404)).q.keys,[]);
 cases.push({case:'max-two-slots-metadata-off-on-and-mismatch-no-binary',base64Chars:largeA.png.length+largeB.png.length,offProjectionBytes:off.q.bytes,onProjectionBytes:on.q.bytes});
 stage='PENDING_SAVE';await putRow(a,{qr:b},true);
 assert.equal((await projected('support')).r.json.qrUrl,'/api/v1/support/qr/'+a.id);
 assert.deepEqual((await projected('support/qr/'+a.id)).r.data,Buffer.from(a.png,'base64'));
 assert.deepEqual((await projected('support/qr/'+b.id,404)).q.keys,[]);
 const noAdmin=await call('admin/support/qr/'+b.id);assert.equal(noAdmin.status,403);
 assert.deepEqual((await projected('admin/support/qr/'+b.id,200,true)).r.data,Buffer.from(b.png,'base64'));
 await projected('admin/support/qr/'+a.id,404,true);
 assert.equal((await call('admin/support','PUT',{...config,enabled:true},true)).status,200);
 await projected('support/qr/'+a.id,404);
 const saved=await projected('support/qr/'+b.id);assert.deepEqual(saved.r.data,Buffer.from(b.png,'base64'));
 assert.deepEqual(saved.q.keys,[['image']]);assert(saved.q.sql.includes("value#>'{config,enabled}'='true'::jsonb")&&saved.q.sql.includes("value#>>'{qr,id}'=?"));
 assert.equal(saved.q.parameters[1],b.id);assert.equal(saved.r.headers.get('cache-control'),'private, no-store');
 assert.deepEqual((await projected('admin/support/qr/'+b.id,200,true)).r.data,saved.r.data);
 cases.push('pending-is-private-atomic-save-retires-oldID-single-query-enabled-and-ID-predicate');
 stage='DELETE_OFF';assert.equal((await call('admin/support/qr','DELETE',undefined,true)).status,200);
 await projected('support/qr/'+b.id);await projected('admin/support/qr/'+b.id,404,true);
 assert.equal((await call('admin/support','PUT',{...config,enabled:false},true)).status,200);
 assert.deepEqual((await projected('support')).r.json,{enabled:false});await projected('support/qr/'+b.id,404);
 await putRow(a,{qr:b},false);await projected('support/qr/'+a.id,404);await projected('admin/support/qr/'+b.id,200,true);
 const count=queries.length;assert.equal((await call('support/qr/not-an-id')).status,404);assert.equal(queries.length,count);
 cases.push('staged-delete-preserves-public-until-save-off-hides-saved-private-remains-authenticated');
 stage='CONFIG_SOURCE';const caddy=fs.readFileSync('/fixture/Caddyfile','utf8'),source=fs.readFileSync(base+'security/support-upload.ts','utf8');
 assert(caddy.includes('import api_proxy @supportQRUpload 25s')&&caddy.includes('import api_proxy @otherAPI 10s'));
 assert(caddy.includes('response_header_timeout {args[1]}')&&caddy.includes('reverse_proxy {args[0]} api:3000'));
 for(const line of ['method POST','path /api/v1/admin/support/qr','max_size 2162688','max_size 64KB','header_up -Forwarded','header_up -X-Real-IP','header_up X-Forwarded-For {http.request.remote.host}','header_up X-Forwarded-Host {http.request.host}','header_up X-Forwarded-Proto https','flush_interval 100ms','dial_timeout 3s','compression off'])assert(caddy.includes(line));
 assert(!/headerPairs\s*:/.test(source));cases.push('static-Caddy-shared-policy-and-exact-route-timeout-config-not-native-validation');
 stage='ISOLATION';assert.deepEqual((await database.settings.findUnique({where:{id:'main'}})).value,{fixtureSentinel:'DO_NOT_CHANGE'});assert.equal(await database.downloadJob.count(),0);
 const audit=await database.auditLog.findMany();assert.equal(audit.length,3);for(const log of audit)assert.deepEqual(Object.keys(log.detail).sort(),['enabled','hasQR','pending']);
 fs.writeFileSync('/out/projection-result.json',JSON.stringify({status:'PASS',group:'support-projection-successor',cases,queries,realNestAuthPrismaPostgres:true,redisRate:'fixture',sourceRequests:0,caddyNative:'NOT_RUN',decoderSuite:'REUSED_NOT_RERUN'},null,2));
 console.log('PASS support projection successor');
})().catch(error=>{console.error('SUPPORT_PROJECTION_FAILED '+stage+' '+(error.code||error.constructor.name));process.exitCode=1;})
.finally(async()=>{await app?.close();await database.$disconnect();});
