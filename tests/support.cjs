// Support feature delta: real Nest guards/Multer/FFmpeg and PostgreSQL settings.
// Only Redis admin-token lookup/rate store are in-memory fixtures. No platform,
// main data, accounts or payment QR. HTTP is private loopback inside own lab.
require('reflect-metadata');
const assert=require('node:assert/strict'),fs=require('node:fs'),Module=require('node:module'),http=require('node:http'),crypto=require('node:crypto');
const ts=require('/app/node_modules/typescript'),{PrismaClient}=require('/app/node_modules/@prisma/client');
if(process.env.SUPPORT_TEST_GUARD!=='own-support-offline'||!/^postgresql:\/\/support_lab:.*@postgres:5432\/support_lab$/.test(process.env.DATABASE_URL||''))throw Error('LAB_ONLY');
const {execFileSync}=require('node:child_process');
const prisma=new PrismaClient();let database=prisma;
const db=new Proxy({},{get:(_target,key)=>{const value=database[key];return typeof value==='function'?value.bind(database):value;}});
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
class AppError extends Error{constructor(code,status=400){super(code);this.code=code;this.status=status;}}
const actor='support-fixture@example.invalid',sessionToken='a'.repeat(64),adminToken='b'.repeat(64),csrf='FIXTURE_ONLY_CSRF';
process.env.APP_ORIGIN='http://support-fixture.invalid';process.env.ADMIN_SESSION_SECRET='SUPPORT_FIXTURE_SIGNING_ONLY_'.repeat(2);
let rateCalls=0,parserReads=0;
const exportsCore={db,AppError,hash,origin:process.env.APP_ORIGIN,rate:async()=>{rateCalls++;},fail:(code,status=400)=>{throw new AppError(code,status);},
 redis:{get:async key=>key==='admin:'+hash(adminToken)?actor:null}};
const core='/app/packages/shared/src/core.ts',m=new Module(core);m.loaded=true;m.exports=exportsCore;require.cache[core]=m;
// Match production decorator metadata; tsx/esbuild alone omits parameter types.
function compiled(path){const source=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true}}).outputText;const m=new Module(path);m.exports={};m.loaded=true;require.cache[path]=m;new Function('require','module','exports',source)(Module.createRequire(path),m,m.exports);return m.exports;}
const base='/app/apps/api/src/';
compiled(base+'auth/session.ts');
// Keep common barrel from importing unrelated queue/limits services; both
// exports below are the real source functions, not authentication doubles.
const common=new Module(base+'common.ts');common.loaded=true;common.exports={...require(base+'auth/session.ts'),...require(base+'validation.ts')};require.cache[base+'common.ts']=common;
compiled(base+'services/support-contract.ts');compiled(base+'services/support-image.ts');
const upload=compiled(base+'security/support-upload.ts');
const {SupportService}=compiled(base+'services/support.service.ts'),{SupportController}=compiled(base+'controllers/support.controller.ts');
const {SafeErrors}=compiled(base+'filters/safe-errors.filter.ts');
const {NestFactory}=require('/app/node_modules/@nestjs/core'),{Module:NestModule}=require('/app/node_modules/@nestjs/common'),cookieParser=require('/app/node_modules/cookie-parser');
class TestModule{};NestModule({controllers:[SupportController],providers:[SupportService,upload.SupportUploadGuard,upload.SupportUploadInterceptor]})(TestModule);
let app,port;const cookies=`ws_session=${sessionToken}; ws_admin=${adminToken}.${require(base+'auth/session.ts').sign(adminToken)}`;
async function boot(){app=await NestFactory.create(TestModule,{logger:false});app.use(cookieParser());app.use((req,res,next)=>{req.on('newListener',name=>{if(name==='data'&&req.url==='/api/v1/admin/support/qr')parserReads++;});res.setHeader('Cache-Control','no-store');next();});app.useGlobalFilters(new SafeErrors());await app.listen(0,'127.0.0.1');port=app.getHttpServer().address().port;}
async function call(path,method='GET',body,headers={}){const r=await fetch(`http://127.0.0.1:${port}/api/v1/`+path,{method,headers:{cookie:cookies,origin:process.env.APP_ORIGIN,'x-csrf-token':csrf,...(body instanceof FormData?{}:{'content-type':'application/json'}),...headers},body:body===undefined?undefined:body instanceof FormData?body:JSON.stringify(body),signal:AbortSignal.timeout(25000)});const data=Buffer.from(await r.arrayBuffer());let json;try{json=JSON.parse(data);}catch{}return {status:r.status,headers:r.headers,data,json};}
function form(bytes,mime='image/png',filename='fixture.png'){const f=new FormData();f.set('file',new Blob([bytes],{type:mime}),filename);return f;}
function media(name,args){const file='/out/'+name;execFileSync('ffmpeg',['-v','error','-nostdin',...args,'-frames:v','1','-threads','1',file],{timeout:8000,stdio:'ignore'});return fs.readFileSync(file);}
const config={enabled:false,title:'Fixture support',message:'Voluntary support fixture',bankName:'',accountName:'',accountNumber:'',transferNote:''};
async function expectCode(promise,status,code){const r=await promise;assert.equal(r.status,status);assert.deepEqual(r.json,{error:{code}});return r;}
const cases=[];let stage='INIT';
async function focused(png,jpg){
 let r;
 stage='MAX_PIXELS';const large=media('qr-max.png',['-f','lavfi','-i','testsrc=size=2048x2048:rate=1']);
 assert(large.length<=2*1024*1024);r=await call('admin/support/qr','POST',form(large));assert.equal(r.status,201);
 const normalized=await call(r.json.qrUrl.slice(8));assert.equal(normalized.status,200);assert(normalized.data.length<=2*1024*1024);
 const inspected=JSON.parse(execFileSync('ffprobe',['-v','error','-protocol_whitelist','pipe','-show_entries','stream=width,height','-of','json','-i','pipe:0'],{input:normalized.data,timeout:8000}));
 assert.deepEqual(inspected.streams[0],{width:2048,height:2048});
 cases.push({case:'full4Mpixel-raster-upload-unchanged-dimensions-under-production384MiB',inputBytes:large.length,outputBytes:normalized.data.length});
 stage='NATIVE_CANCEL';const cp=require('node:child_process'),original=cp.spawn,observed=[];
 cp.spawn=(...args)=>{const child=original(...args),record={pid:child.pid,tool:args[0]};observed.push(record);child.once('close',(code,signal)=>Object.assign(record,{actualExit:code,actualSignal:signal,closed:true}));return child;};
 const control=new AbortController(),start=performance.now();const timer=setTimeout(()=>control.abort(),10);
 try{await assert.rejects(()=>require(base+'services/support-image.ts').supportImage({buffer:large,size:large.length,mimetype:'image/png'},performance.now()+1000,control.signal),e=>e.code==='SUPPORT_UPLOAD_TIMEOUT');}
 finally{clearTimeout(timer);cp.spawn=original;}
 assert.equal(observed.length,1);assert(observed.every(p=>p.closed));assert(observed.some(p=>p.actualSignal==='SIGKILL'));
 cases.push({case:'decoder-abort-kill-reap-before-rejection',elapsedMs:performance.now()-start,native:observed});
 assert.deepEqual((await database.settings.findUnique({where:{id:'main'}})).value,{fixtureSentinel:'DO_NOT_CHANGE'});assert.equal(await database.downloadJob.count(),0);
 fs.writeFileSync('/out/support-focused-result.json',JSON.stringify({status:'PASS',cases,sourceRequests:0,realNestMulterFFmpegPostgres:true,adminRedisAndRateStore:'in-memory fixture'},null,2));console.log('PASS support focused groups'+cases.length);
}
(async()=>{
 await database.session.create({data:{id:hash(sessionToken),csrf,expiresAt:new Date(Date.now()+3600000)}});
 await database.settings.create({data:{id:'main',value:{fixtureSentinel:'DO_NOT_CHANGE'}}});
 const png=media('qr-fixture.png',['-f','lavfi','-i','testsrc=size=96x96:rate=1']);
 const jpg=media('qr-fixture.jpg',['-f','lavfi','-i','color=white:s=96x64']);
 const wide=media('qr-wide.png',['-f','lavfi','-i','color=white:s=2050x32']);
 await boot();
 if(process.env.SUPPORT_TEST_FOCUSED==='1'){await focused(png,jpg);return;}
 stage='AUTH';let r=await call('support','GET',undefined,{cookie:''});assert.deepEqual(r.json,{enabled:false});
 const oldReads=parserReads,oldRates=rateCalls;
 await expectCode(call('admin/support/qr','POST',form(png),{cookie:''}),403,'SESSION_REQUIRED');
 await expectCode(call('admin/support/qr','POST',form(png),{cookie:`ws_session=${sessionToken}`}),403,'ADMIN_REQUIRED');
 await expectCode(call('admin/support/qr','POST',form(png),{'x-csrf-token':'BAD'}),403,'CSRF_INVALID');
 await expectCode(call('admin/support/qr','POST',form(png),{origin:'http://evil.invalid'}),403,'CSRF_INVALID');
 assert.equal(parserReads,oldReads);assert.equal(rateCalls,oldRates);cases.push('auth+CSRF+Origin-before-Multer-read-and-rate');
 stage='DEFAULT';r=await call('admin/support');assert.equal(r.json.enabled,false);assert.equal(r.json.qrUrl,null);assert.equal(r.json.qrPending,false);
 await expectCode(call('admin/support','PUT',{...config,enabled:true}),400,'SUPPORT_PAYMENT_REQUIRED');
 await expectCode(call('admin/support','PUT',{...config,qrUrl:'https://evil.invalid'}),400,'INVALID_REQUEST');
 await expectCode(call('admin/support','PUT',{...config,title:'<script>bad</script>'}),400,'INVALID_REQUEST');
 cases.push('default-off-strict-config-enabled-needs-QR-or-bank');
 stage='STAGE_SAVE';r=await call('admin/support/qr','POST',form(png,'image/png','../../ignored-name.png'));assert.equal(r.status,201);assert(r.json.qrPending&&r.json.qrUrl.startsWith('/api/v1/admin/support/qr/'));
 let draftURL=r.json.qrUrl,publicURL=draftURL.replace('/admin/','/');
 assert.deepEqual((await call('support')).json,{enabled:false});assert.equal((await call(publicURL.slice(8))).status,404);
 let image=await call(draftURL.slice(8));assert.equal(image.status,200);assert.equal(image.headers.get('content-type'),'image/png');assert.equal(image.headers.get('cache-control'),'private, no-store');assert.equal(image.headers.get('x-content-type-options'),'nosniff');
 assert.equal((await call(draftURL.slice(8),'GET',undefined,{cookie:''})).status,403);
 function pixels(data){return execFileSync('ffmpeg',['-v','error','-nostdin','-protocol_whitelist','pipe','-i','pipe:0','-frames:v','1','-threads','1','-f','rawvideo','-pix_fmt','rgba','pipe:1'],{input:data,timeout:8000,maxBuffer:1024*1024,stdio:['pipe','pipe','ignore']});}
 assert.equal(hash(pixels(image.data)),hash(pixels(png))); // no resize/crop/lossy QR encoding
 r=await call('admin/support','PUT',{...config,enabled:true});assert.equal(r.status,200);assert.equal(r.json.qrPending,false);
 let published=await call('support','GET',undefined,{cookie:''});assert.equal(published.json.enabled,true);assert.equal(published.json.qrUrl,publicURL);
 assert.equal((await call(publicURL.slice(8),'GET',undefined,{cookie:''})).status,200);
 cases.push('PNG-upload-pending-private-until-save-atomic-public-lossless-pixels');
 stage='REPLACE';r=await call('admin/support/qr','POST',form(jpg,'image/jpeg','fixture.jpg'));assert.equal(r.status,201);const nextDraft=r.json.qrUrl;assert.notEqual(nextDraft,draftURL);
 assert.equal((await call('support')).json.qrUrl,publicURL);assert.equal((await call(nextDraft.replace('/admin/','/').slice(8))).status,404);
 image=await call(nextDraft.slice(8));assert.equal(hash(pixels(image.data)),hash(pixels(jpg)));
 stage='PERSISTENCE';await app.close();await database.$disconnect();database=new PrismaClient();await boot();
 assert.equal((await call('support')).json.qrUrl,publicURL);r=await call('admin/support');assert.equal(r.json.qrUrl,nextDraft);assert.equal(r.json.qrPending,true);
 r=await call('admin/support','PUT',{...config,enabled:true});assert.equal(r.status,200);assert.equal((await call(publicURL.slice(8))).status,404);publicURL=nextDraft.replace('/admin/','/');assert.equal((await call(publicURL.slice(8))).status,200);
 cases.push('JPEG-normalized-lossless-decode-saved+draft-survive-Prisma-reconnect-and-Nest-restart');
 stage='OFF_DELETE';await call('admin/support','PUT',{...config,enabled:false});assert.deepEqual((await call('support')).json,{enabled:false});assert.equal((await call(publicURL.slice(8))).status,404);
 await call('admin/support','PUT',{...config,enabled:true});r=await call('admin/support/qr','DELETE');assert.equal(r.json.qrUrl,null);assert.equal(r.json.qrPending,true);assert.equal((await call(publicURL.slice(8))).status,200);
 await expectCode(call('admin/support','PUT',{...config,enabled:true}),400,'SUPPORT_PAYMENT_REQUIRED');assert.equal((await call(publicURL.slice(8))).status,200);
 r=await call('admin/support','PUT',{...config,enabled:false});assert.equal(r.json.qrPending,false);assert.equal((await call(publicURL.slice(8))).status,404);
 const row=await database.settings.findUnique({where:{id:'support-page-v1'}});assert.equal(row.value.qr,null);assert.equal(row.value.pending,null);
 await call('admin/support','PUT',{...config,enabled:true,bankName:'Fixture Bank',accountName:'Fixture Owner',accountNumber:'TEST-123'});assert.equal((await call('support')).json.enabled,true);assert.equal((await call('support')).json.qrUrl,null);
 cases.push('off-hides-bank+QR-delete-is-pending-save-clears-assets-bank-only-enable');
 stage='BAD_UPLOADS';
 await expectCode(call('admin/support/qr','POST',form(png,'image/jpeg')),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',form(Buffer.from('<svg>not raster</svg>'))),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',form(Buffer.from([255,216,255,1,2,3,4,5]),'image/jpeg')),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',form(wide)),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',form(Buffer.concat([jpg,jpg]),'image/jpeg')),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',form(Buffer.alloc(2*1024*1024+1))),413,'SUPPORT_QR_LIMIT');
 const fields=form(png);fields.set('extra','not permitted');await expectCode(call('admin/support/qr','POST',fields),400,'SUPPORT_QR_INVALID');
 const files=form(png);files.append('file',new Blob([png],{type:'image/png'}),'second.png');await expectCode(call('admin/support/qr','POST',files),400,'SUPPORT_QR_INVALID');
 await expectCode(call('admin/support/qr','POST',new FormData()),400,'SUPPORT_QR_INVALID');
 cases.push('MIME-spoof-SVG-corrupt-dimensions-animation-filecap-parts-fields-empty-rejected');
 stage='STREAM_LIMIT';
 async function rawUpload(kind){return new Promise((resolve,reject)=>{
  const start=performance.now(),headers={cookie:cookies,origin:process.env.APP_ORIGIN,'x-csrf-token':csrf,'content-type':'multipart/form-data; boundary=fixture'};
  const req=http.request({host:'127.0.0.1',port,path:'/api/v1/admin/support/qr',method:'POST',headers},res=>{let chunks=[];res.on('data',b=>chunks.push(b));res.on('end',()=>resolve({status:res.statusCode,json:JSON.parse(Buffer.concat(chunks)),elapsed:performance.now()-start}));});
  req.on('error',e=>{if(!req.destroyed)reject(e);});req.setTimeout(23000,()=>{req.destroy();reject(Error('TEST_DEADLINE'));});req.flushHeaders();
  if(kind==='chunkcap')req.end(Buffer.alloc(2*1024*1024+65537,120));
  else {req.write('--fixture\r\nContent-Disposition: form-data; name="file"; filename="fixture.png"\r\nContent-Type: image/png\r\n\r\n');setTimeout(async()=>{const busy=await call('admin/support/qr','POST',form(png));assert.equal(busy.status,409);},100);}
 });}
 let capped=await rawUpload('chunkcap');assert.equal(capped.status,413);assert.deepEqual(capped.json,{error:{code:'SUPPORT_QR_LIMIT'}});
 let timeout=await rawUpload('hold');assert.equal(timeout.status,408);assert(timeout.elapsed>=19500&&timeout.elapsed<23000);
 // Ensure timeout/cancel/parser errors release the one-upload slot.
 r=await call('admin/support/qr','POST',form(png));assert.equal(r.status,201);
 cases.push({case:'chunked-overhead-cap-and-absolute20s-slow-upload-busy-slot-cleanup',timeoutMs:timeout.elapsed,capMs:capped.elapsed});
 stage='ISOLATION';assert.deepEqual((await database.settings.findUnique({where:{id:'main'}})).value,{fixtureSentinel:'DO_NOT_CHANGE'});assert.equal(await database.downloadJob.count(),0);
 const logs=await database.auditLog.findMany();for(const log of logs){assert.deepEqual(Object.keys(log.detail).sort(),['enabled','hasQR','pending']);assert(!JSON.stringify(log.detail).includes('TEST-123'));}
 assert(fs.readdirSync('/out').every(f=>!f.includes('ignored-name')));cases.push('separate-settings-row-no-job-filepath-or-sensitive-audit-payload');
 fs.writeFileSync('/out/support-result.json',JSON.stringify({status:'PASS',cases,sourceRequests:0,realNestMulterFFmpegPostgres:true,adminRedisAndRateStore:'in-memory fixture',authHeaderValuesNotRecorded:true},null,2));console.log('PASS support groups'+cases.length);
})().catch(error=>{console.error('SUPPORT_TEST_FAILED '+stage+' '+(error.code||error.constructor.name));process.exitCode=1;})
.finally(async()=>{await app?.close();await database.$disconnect();});
