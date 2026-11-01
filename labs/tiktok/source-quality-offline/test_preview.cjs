// Real parent/process group, Python extractor/FFmpeg and API/cache services.
// DB, source HTTP and egress proof channel remain explicit offline doubles.
const assert=require('node:assert/strict'),fs=require('node:fs'),Module=require('node:module'),crypto=require('node:crypto');
const {EventEmitter}=require('node:events'),ts=require('/app/node_modules/typescript');
const ROOT='/out/media',base='/app',ID='7678642036060228885',photo=`https://www.tiktok.com/@fixture/photo/${ID}`,video=photo.replace('/photo/','/video/');
class AppError extends Error{constructor(code){super(code);this.code=code;}}
function stub(path,exports){const m=new Module(path);m.loaded=true;m.exports=exports;require.cache[path]=m;}
function compiled(path){const output=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,experimentalDecorators:true,emitDecoratorMetadata:true,esModuleInterop:true}}).outputText;const m={exports:{}};new Function('require','module','exports',output)(Module.createRequire(path),m,m.exports);return m.exports;}
let current,expired=false,cancelled=false,mode='ok',rejectPreview=false;const packets=[];
const db={
 $transaction:async fn=>fn(db),
 session:{findUnique:async({where})=>({id:where.id==='a'.repeat(64)?'owner':'other',expiresAt:new Date(Date.now()+60000)})},
 downloadJob:{findUnique:async()=>{if(cancelled)current.cancelRequested=true;return structuredClone(current);},findUniqueOrThrow:async()=>structuredClone(current),findFirst:async({where})=>where.id===current.id&&where.sessionId==='owner'?structuredClone(current):null,updateMany:async()=>({count:1})},
 mediaItem:{findMany:async()=>structuredClone(current.items)},
};
stub(base+'/packages/shared/src/core.ts',{AppError,db,after:s=>new Date(Date.now()+s*1000),ownerExpired:()=>false,filePath:id=>ROOT+'/'+id,mediaRoot:ROOT,hash:x=>x,
 fail:code=>{throw new AppError(code);},lockJob:async()=>{},expireSelectableMetadata:async()=>expired,expiredMetadataJob:()=>expired});
stub(base+'/apps/worker/src/lifecycle.ts',{diskAvailable:async()=>true});
Object.assign(process.env,{TIKTOK_ADAPTER_ENABLED:'1',TIKTOK_PHOTO_ENABLED:'1',TIKTOK_VIDEO_ENABLED:'1',VERIFIED_PLATFORMS:'tiktok',TIKTOK_EGRESS_POLICY_ENABLED:'1',TIKTOK_EGRESS_CONTROL_SECRET:'a'.repeat(64),TIKTOK_PREVIEW_ENABLED:'1',ADMIN_SESSION_SECRET:'FAKE_NOT_A_SECRET_'.repeat(3)});
const http=require('node:http');
http.request=(opts,callback)=>{
 assert.equal(opts.hostname,'egress');assert.equal(opts.path,'/_wed/phase');
 const req=new EventEmitter();req.destroy=()=>{};
 req.end=body=>{
  const p=JSON.parse(body);packets.push(p);const optional=p.profile==='tiktok-preview-cache';
  if(optional&&mode==='hold'&&p.op==='open')setTimeout(()=>{cancelled=true;},10);
  const reply={v:p.v||1,id:p.id,job:p.job,phase:p.phase,epoch:'e'.repeat(64),state:p.op==='open'?'OPEN':optional&&rejectPreview?'REJECTED':optional&&mode==='proof-stall'?'PENDING':'ACCEPTED',connections:p.op==='open'?0:1,
   ...(p.v===2?{profile:p.profile,selection:p.selection}:{}),...(p.op==='open'?{connectKey:'f'.repeat(64)}:{})};
  process.nextTick(()=>{const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{};callback(res);res.emit('data',Buffer.from(JSON.stringify(reply)));res.emit('end');});
 };return req;
};
const cp=require('node:child_process'),realSpawn=cp.spawn;
cp.spawn=(cmd,args,options)=>{assert.equal(cmd,'python3');return realSpawn(cmd,['/fixture/test_preview.py','--child',...args.slice(1)],{...options,env:{...options.env,FAKE_PREVIEW_MODE:mode}});};
const {runAdapter}=compiled(base+'/apps/worker/src/adapter.ts');
const l={enabledPlatforms:['tiktok'],maxDuration:600,maxBytes:209715200,maxInputBytes:262144000,analyzeTimeout:30,prepareTimeout:180,diskStopPercent:80};
function job(url=photo){const id=crypto.randomUUID();current={id,state:'analyzing',sessionId:'owner',platform:'tiktok',sourceUrl:url,workerToken:'worker',cancelRequested:false,items:[],title:'Fixture'};cancelled=false;expired=false;return id;}
async function analyze(url=photo){const id=job(url);const data=await runAdapter(id,'analyze',url,null,l,'worker');current.state='selectable';current.items=[{kind:data.kind==='photo'?'photo':'video',formats:data.formats}];return {id,data};}
const digest=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const cases=[];let stage='pipeline';
(async()=>{
 const success=await analyze();const key=success.data.formats[0].id,dir=ROOT+'/'+success.id;
 assert(fs.existsSync(dir+'/previews.json'));assert(!fs.existsSync(dir+'/previews.pending.json'));
 const entry=JSON.parse(fs.readFileSync(dir+'/previews.json')).entries[0];assert.equal(entry.key,key);assert(entry.normalizedSha256);
 const receipt=JSON.parse(fs.readFileSync(`/out/${success.id}-analyze-receipt.json`));assert.deepEqual(receipt.gets,['metadata','image']);assert(receipt.allClosed&&receipt.cookiesCleared);
 const profile=packets.find(p=>p.profile==='tiktok-preview-cache'&&p.op==='open');assert(/^pv1_1_[a-f0-9]{64}$/.test(profile.selection));
 // API retains real session/owner validation, route/cache and DB state doubles.
 stage='API';const auth=compiled(base+'/apps/api/src/auth/session.ts');
 stub(base+'/apps/api/src/common.ts',{own:auth.own});
 const {JobsService}=compiled(base+'/apps/api/src/services/jobs.service.ts'),service=new JobsService();
 const request={cookies:{ws_session:'a'.repeat(64)}};
 function response(){return {code:200,headers:{},body:null,status(n){this.code=n;return this;},setHeader(k,v){this.headers[k]=v;},end(data){this.body=data;return this;}};}
 let status=await service.status(request,success.id);assert.equal(status.items[0].formats[0].previewUrl,`/api/v1/jobs/${success.id}/preview/${key}`);assert.equal(status.previewUrl,null);
 let res=response();await service.preview(request,success.id,res,key);assert.equal(res.code,200);assert.equal(res.headers['Content-Type'],'image/jpeg');assert.equal(res.headers['Cache-Control'],'private, no-store');assert.equal(res.headers['X-Content-Type-Options'],'nosniff');assert.equal(res.body.length,entry.bytes);
 await assert.rejects(()=>service.preview({},success.id,response(),key),e=>e.code==='SESSION_REQUIRED');
 await assert.rejects(()=>service.preview({cookies:{ws_session:'b'.repeat(64)}},success.id,response(),key),e=>e.code==='JOB_NOT_FOUND');
 res=response();await service.preview(request,success.id,res,'ttp1_01_'+'0'.repeat(64));assert.equal(res.code,404);
 current.cancelRequested=true;await assert.rejects(()=>service.preview(request,success.id,response(),key),e=>e.code==='JOB_EXPIRED');current.cancelRequested=false;
 expired=true;await assert.rejects(()=>service.preview(request,success.id,response(),key),e=>e.code==='JOB_EXPIRED');expired=false;
 const preview=dir+'/preview-'+key+'.jpg',bytes=fs.readFileSync(preview);fs.writeFileSync(preview,Buffer.from('<html>FAKE</html>'));res=response();await service.preview(request,success.id,res,key);assert.equal(res.code,404);
 fs.unlinkSync(preview);fs.symlinkSync('/out/fixture.jpg',preview);res=response();await service.preview(request,success.id,res,key);assert.equal(res.code,404);fs.unlinkSync(preview);fs.writeFileSync(preview,bytes);
 cases.push('actual-API-owner-expiry-cancel-snapshot-SHA-MIME-symlink-private-cache-only');
 stage='prepare';current.state='preparing';current.formatId=key;
 const prepared=await runAdapter(success.id,'prepare',photo,key,l,'worker');assert.equal(prepared.file,'image.jpg');assert.equal(digest(dir+'/image.jpg'),digest('/out/fixture.jpg'));assert.equal(prepared.contract.fullDecode,'PASS');
 assert.deepEqual(JSON.parse(fs.readFileSync(`/out/${success.id}-prepare-receipt.json`)).gets,['metadata','image']);
 cases.push('real-parent-extractor-parser-preview-fresh-prepare-JPEG-original-SHA-decode');
 stage='album-order';mode='album';const album=await analyze(),adir=ROOT+'/'+album.id,entries=JSON.parse(fs.readFileSync(adir+'/previews.json')).entries;
 assert.equal(entries.length,2);assert.deepEqual(entries.map(e=>e.key),album.data.formats.map(f=>f.id));assert.notEqual(entries[0].normalizedSha256,entries[1].normalizedSha256);
 assert(packets.some(p=>p.profile==='tiktok-preview-cache'&&/^pv1_2_/.test(p.selection)));
 current.state='preparing';current.formatId=album.data.formats[1].id;await runAdapter(album.id,'prepare',photo,current.formatId,l,'worker');assert.equal(digest(adir+'/image.jpg'),digest('/out/changed.jpg'));mode='ok';
 cases.push('two-photo-order-index-counted-cap-and-second-selection-original');
 // Existing structural format key remains identical for two same-size images;
 // the accepted preview digest rejects a fresh changed original and cleans it.
 const changed=await analyze();mode='changed';current.state='preparing';current.formatId=changed.data.formats[0].id;
 await assert.rejects(()=>runAdapter(changed.id,'prepare',photo,current.formatId,l,'worker'));
 assert(!fs.existsSync(ROOT+'/'+changed.id+'/image.jpg')&&!fs.existsSync(ROOT+'/'+changed.id+'/image.jpg.part'));mode='ok';
 cases.push('same-dimensions-reorder-content-rejected-and-owned-image-removed');
 stage='optional';
 for(const scenario of ['redirect','oversize','timeout','html','proof-reject']){
  mode=scenario==='proof-reject'?'ok':scenario;rejectPreview=scenario==='proof-reject';const result=await analyze();
  assert(result.data.formats.length>0);assert(!fs.readdirSync(ROOT+'/'+result.id).some(n=>n.startsWith('preview')));
  const r=JSON.parse(fs.readFileSync(`/out/${result.id}-analyze-receipt.json`));assert(r.allClosed&&r.cookiesCleared&&r.gets.length===2);
 }
 mode='ok';rejectPreview=false;cases.push('optional-redirect-byte-timeout-HTML-proof-fail-preserve-metadata');
 stage='optional-proof-stall';mode='proof-stall';const stalled=await analyze();assert(stalled.data.formats.length>0);assert(!fs.readdirSync(ROOT+'/'+stalled.id).some(n=>n.startsWith('preview')));mode='ok';
 cases.push('optional-PENDING-proof-expires-before-metadata-deadline-no-false-FAIL');
 stage='optional-no-time';const noTime=job(),short=await runAdapter(noTime,'analyze',photo,null,{...l,analyzeTimeout:8},'worker');assert(short.formats.length>0);assert.deepEqual(JSON.parse(fs.readFileSync(`/out/${noTime}-analyze-receipt.json`)).gets,['metadata']);
 cases.push('insufficient-optional-time-preserves-metadata-no-source-image-GET');
 stage='worker-exit';mode='exit20';const failed=job();await assert.rejects(()=>runAdapter(failed,'analyze',photo,null,l,'worker'));
 assert(!fs.readdirSync(ROOT+'/'+failed).some(n=>n.startsWith('preview')));mode='ok';cases.push('packet-PASS-native-exit20-fails-no-cache-publish');
 stage='cancel';mode='hold';const killed=job();await assert.rejects(()=>runAdapter(killed,'analyze',photo,null,l,'worker'));
 assert(!fs.readdirSync(ROOT+'/'+killed).some(n=>n.startsWith('preview')));mode='ok';cancelled=false;cases.push('cancel-real-child-group-reap-no-cache');
 stage='video';const poster=await analyze(video);assert(fs.existsSync(ROOT+'/'+poster.id+'/previews.json'));assert.equal(JSON.parse(fs.readFileSync(ROOT+'/'+poster.id+'/previews.json')).entries[0].key,'video');
 status=await service.status(request,poster.id);assert.equal(status.previewUrl,`/api/v1/jobs/${poster.id}/preview`);res=response();await service.preview(request,poster.id,res);assert.equal(res.code,200);assert(res.body.length>0);cases.push('video-pinned-extractor-cover-to-same-origin-poster');
 stage='default-off';delete process.env.TIKTOK_PREVIEW_ENABLED;const before=packets.length,off=await analyze();assert(!fs.existsSync(ROOT+'/'+off.id+'/previews.json'));assert(!packets.slice(before).some(p=>p.profile==='tiktok-preview-cache'));assert.deepEqual(JSON.parse(fs.readFileSync(`/out/${off.id}-analyze-receipt.json`)).gets,['metadata']);
 cases.push('default-off-no-capability-no-extra-GET-old-metadata-role');
 fs.writeFileSync('/out/preview-ts-result.json',JSON.stringify({status:'PASS',sourceRequests:0,cases,fixtureProofChannel:true,actualPythonChildren:true,realProcessGroup:true},null,2));console.log('PASS preview parent/API groups'+cases.length);
})().catch(e=>{console.error('PREVIEW_TEST_FAILED '+stage+' '+(e.code||e.constructor.name));process.exitCode=1;});
