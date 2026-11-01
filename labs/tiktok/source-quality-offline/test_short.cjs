const assert=require('node:assert/strict'),fs=require('node:fs'),Module=require('node:module');
const {EventEmitter}=require('node:events');
const base='/app',core=base+'/packages/shared/src/core.ts';
class AppError extends Error{constructor(code){super(code);this.code=code;}}
function stub(path,exports){const m=new Module(path);m.loaded=true;m.exports=exports;require.cache[path]=m;}
const settings={enabledPlatforms:['tiktok'],maxDuration:600,maxBytes:209715200,maxInputBytes:262144000,analyzeTimeout:30,prepareTimeout:180,sessionTtl:120,diskStopPercent:80,readyTtl:120};
let current,created;const calls=[];
const db={
  $transaction:async fn=>fn(db),
  downloadJob:{create:async({data})=>(created=data,{id:'job'}),findUnique:async()=>structuredClone(current),findUniqueOrThrow:async()=>structuredClone(current),
    update:async({data})=>(Object.assign(current,data),current),updateMany:async({data})=>(Object.assign(current,data),{count:1})},
  temporaryAsset:{findUnique:async()=>null,upsert:async()=>({}),update:async()=>({})},
  mediaItem:{create:async({data})=>(current.items=[{id:'item',kind:data.kind,formats:data.formats}])},auditLog:{create:async()=>({})},
};
const exportsCore={AppError,db,after:s=>new Date(Date.now()+s*1000),limits:async()=>settings,lockJob:async()=>{},admission:async()=>{},
  ownerExpired:()=>false,metadataDeadline:()=>new Date(Date.now()+120000),secret:()=> 'worker',rate:async()=>{},hash:x=>x,
  enqueue:async()=>{},filePath:id=>'/out/media/'+id,mediaRoot:'/out/media',expireSelectableMetadata:async()=>false,
  fail:code=>{throw new AppError(code);}};
stub(core,exportsCore);
const short=require(base+'/packages/shared/src/tiktok-short.ts');
// Execute the actual validateUrl function with only its pure dependencies supplied.
const ts=require('/app/node_modules/typescript');
const source=ts.createSourceFile('core.ts',fs.readFileSync(core,'utf8'),ts.ScriptTarget.Latest,true);
const fn=source.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='validateUrl');
const output=ts.transpileModule(fn.getText(source),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
function compiledService(path){
 const text=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true}}).outputText;
 const m={exports:{}};new Function('require','module','exports',text)(Module.createRequire(path),m,m.exports);return m.exports;
}
const validateExports={};new Function('exports','fail','normalizeTikTok',output)(validateExports,exportsCore.fail,short.normalizeTikTok);
exportsCore.validateUrl=validateExports.validateUrl;
const id='7678642036060228885',canonical=`https://www.tiktok.com/@fixture/video/${id}`,photo=canonical.replace('/video/','/photo/');
for(const url of [canonical+'/?is_from_webapp=1&sender_device=pc#track',canonical.replace('www.','')+'/?web_id=1'])assert.equal(exportsCore.validateUrl(url).url,canonical);
assert.equal(exportsCore.validateUrl(photo+'/?sender_device=mobile').url,photo);
const inputs=['https://vt.tiktok.com/FAKEcode/','https://vm.tiktok.com/FAKEcode/?x=1',
  'https://www.tiktok.com/t/FAKEcode/#share','https://tiktok.com/t/FAKEcode/'];
for(const url of inputs)assert(short.shortTikTok(exportsCore.validateUrl(url).url));
for(const url of ['https://m.tiktok.com/t/FAKE','https://www.tiktok.com/live','https://www.tiktok.com/t/FAKE/extra','https://user@vt.tiktok.com/FAKE','https://vt.tiktok.com:443/FAKE','tiktok://video/123'])assert.throws(()=>exportsCore.validateUrl(url));
assert.throws(()=>short.checkedResolved({url:canonical,id,kind:'photo'}));
assert.throws(()=>short.checkedResolved({url:canonical+'?token=FAKE',id,kind:'video'}));
Object.assign(process.env,{TIKTOK_ADAPTER_ENABLED:'1',TIKTOK_PHOTO_ENABLED:'1',TIKTOK_VIDEO_ENABLED:'1',
 VERIFIED_PLATFORMS:'tiktok',TIKTOK_EGRESS_POLICY_ENABLED:'1',TIKTOK_EGRESS_CONTROL_SECRET:'a'.repeat(64)});
stub(base+'/apps/api/src/common.ts',{csrf:async()=>({id:'session'}),parse:(_schema,value)=>value,admission:async()=>{},inputSchema:{}});
const {JobsService}=compiledService(base+'/apps/api/src/services/jobs.service.ts');
stub(base+'/apps/worker/src/lifecycle.ts',{diskAvailable:async()=>true});
let expectedKind='video';
stub(base+'/apps/worker/src/adapter.ts',{runAdapter:async(_id,phase,url)=>{
  calls.push({phase,url});
  if(phase==='analyze')return JSON.parse(fs.readFileSync('/out/'+expectedKind+'-metadata.json'));
  return {file:'media.mp4',size:123,inputBytes:200};
}});
const {processJob}=compiledService(base+'/apps/worker/src/processor.ts');
const http=require('node:http');let tamper=false,profileRequests=[];
http.request=(_options,callback)=>{
 const req=new EventEmitter();req.destroy=()=>{};req.end=body=>{
  const p=JSON.parse(body);profileRequests.push(p);
  const reply={v:p.v||1,id:p.id,job:p.job,phase:p.phase,epoch:'e'.repeat(64),state:p.op==='open'?'OPEN':'ACCEPTED',connections:p.op==='open'?0:p.profile==='tiktok-short-analyze'?4:p.phase==='analyze'?2:3,
   ...(p.v===2?{profile:p.profile,selection:tamper?'ts1_'+'0'.repeat(64):p.selection}:{}),...(p.op==='open'?{connectKey:'f'.repeat(64)}:{})};
  process.nextTick(()=>{const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{};callback(res);res.emit('data',Buffer.from(JSON.stringify(reply)));res.emit('end');});
 };return req;
};
const {ProxyPhase}=require(base+'/apps/worker/src/proxy-phase.ts');
let stage='API_ADMISSION';
(async()=>{
 const service=new JobsService();const response={status(code){assert.equal(code,202);return this;},json(value){assert.equal(value.jobId,'job');}};
 await service.analyze({socket:{remoteAddress:'127.0.0.1'},headers:{}}, {url:inputs[0]},response);assert.equal(created.sourceUrl,'https://vt.tiktok.com/FAKEcode');
 stage='PROFILE_BINDING';
 const transfer=short.shortTransfer(created.sourceUrl);
 const phase=await ProxyPhase.open('analyze','job','worker',performance.now()+30000,transfer);
 assert.equal(await phase.finish(()=>false),4);assert.equal(phase.childEnv().WED_MEDIA_SELECTION,transfer.selection);
 const {createHmac}=require('node:crypto');const p=profileRequests[0];
 assert.equal(p.job,createHmac('sha256','a'.repeat(64)).update(JSON.stringify(['job','worker','analyze',p.id,transfer.profile,transfer.selection])).digest('hex'));
 tamper=true;await assert.rejects(()=>ProxyPhase.open('analyze','job','worker',performance.now()+30000,transfer));tamper=false;
 await assert.rejects(()=>ProxyPhase.open('prepare','job','worker',performance.now()+30000,transfer));
 const canonicalPhase=await ProxyPhase.open('analyze','canonical','worker',performance.now()+30000);assert.equal(await canonicalPhase.finish(()=>false),2);
 stage='WORKER_BINDING';
 for(expectedKind of ['video','photo']){
  current={id:'job',state:'analyzing',platform:'tiktok',sourceUrl:created.sourceUrl,workerToken:null,cancelRequested:false,items:[]};
  await processJob({data:{id:'job'},name:'analyze'});
  assert.equal(current.state,'selectable');assert.equal(current.sourceUrl,expectedKind==='video'?canonical:photo);
  assert.equal(current.items[0].kind,expectedKind);
  if(expectedKind==='video'){
   current.state='queued';current.formatId=current.items[0].formats[0].id;
   await processJob({data:{id:'job'},name:'prepare'});
   assert.equal(current.state,'ready');assert.equal(calls.at(-1).url,canonical);assert.equal(calls.at(-1).phase,'prepare');
  }
 }
 fs.writeFileSync('/out/short-ts-result.json',JSON.stringify({status:'PASS',sourceRequests:0,
  groups:['desktop-app-normalization-and-invalid-routes','API-admission-stored-short','worker-canonical-ID-kind-binding-before-prepare','short-profile-HMAC-reply-tamper-and-canonical-cap2'],
  dbSessionAdapterHTTPDoubles:true,prepareCanonical:true},null,2));
 console.log('PASS short-link TS admission / worker canonical binding / profile groups4');
})().catch(error=>{console.error('SHORT_TS_FAILED '+stage+' '+(error.code||error.constructor.name));process.exitCode=1;});
