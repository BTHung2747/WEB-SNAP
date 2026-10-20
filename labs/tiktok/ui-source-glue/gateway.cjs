// Source lab successor of the accepted gateway. No startup on import.
'use strict';
const http=require('node:http'),fs=require('node:fs/promises'),crypto=require('node:crypto'),net=require('node:net'),assert=require('node:assert/strict');
const {observeJob,createClosure}=require('../ui-observation-fix/failure-path.cjs');
const {createEventWriter}=require('../ui-observation-fix/event-writer.cjs');
const {finalizeSource,publishedGuard,checkedBrowserTransfer,forwardWorkflow}=require('./policy.cjs');
const {runtimeContract,remainingSeconds,readLimited,assertBinding}=require('./contract.cjs');
async function runSourceGateway(){
const contract=await runtimeContract();
assertBinding(contract,JSON.parse(await readLimited('/control/backend.ready')));
const {waitReason,reasonRow}=require('../ui-observation-fix/reasons.cjs');
const closure=createClosure();
const OUT='/control',ORIGIN='http://127.0.0.1:5206',IP=process.env.API_IPV4;
assert.equal(process.versions.node,'22.22.3');assert.equal(net.isIPv4(IP),true);
assert.equal(process.env.APP_ORIGIN,ORIGIN);
const start=performance.now(),end=start+Math.min(390,remainingSeconds(contract))*1000;
const files=new Map([['/',['index.html','text/html; charset=utf-8']],['/assets/index-UOIc8eun.js',['assets/index-UOIc8eun.js','application/javascript']],['/assets/index-DCfw3VbE.css',['assets/index-DCfw3VbE.css','text/css']]]);
const CSP="default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; font-src 'self'; img-src 'self' data:; object-src 'none'; frame-src 'none'; worker-src 'none'; media-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'";
let cookie='',csrf='',ticket='',jobID='',fault='',server,stopping=false,total=0;const counts={},nativeResponses=[];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const exists=async f=>{try{await fs.access(OUT+'/'+f);return true;}catch{return false;}};
const write=(f,r)=>fs.writeFile(OUT+'/'+f,JSON.stringify(r),{flag:'wx'});
const writer=createEventWriter(OUT+'/gateway-events.jsonl',{onFailure:()=>{fault||='EVENT_LOG_FAILED';}});
const note=(event,r={})=>writer.enqueue({event,elapsedMs:Math.round(performance.now()-start),...r});
function category(path){
 if(files.has(path))return'STATIC';if(path==='/api/v1/health')return'HEALTH';if(path==='/api/v1/session')return'SESSION';if(path==='/api/v1/ads')return'ADS';if(path==='/api/v1/jobs/analyze')return'ANALYZE';
 if(/^\/api\/v1\/jobs\/[a-f0-9-]{36}$/.test(path))return'JOB';
 const m=/^\/api\/v1\/jobs\/[a-f0-9-]{36}\/(prepare|heartbeat|release|cancel|download-ticket)$/.exec(path);if(m)return m[1].toUpperCase();
 if(/^\/api\/v1\/downloads\/[a-f0-9]{64}$/.test(path))return'DOWNLOAD';return'DENIED';
}
function allowed(kind,method){return kind==='DOWNLOAD'?['GET','HEAD'].includes(method):['SESSION','ADS','JOB','HEALTH','STATIC'].includes(kind)?method==='GET':['ANALYZE','PREPARE','HEARTBEAT','RELEASE','CANCEL','DOWNLOAD-TICKET'].includes(kind)&&method==='POST';}
let stateWrites=Promise.resolve();
function state(){stateWrites=stateWrites.then(async()=>{await fs.writeFile(OUT+'/browser-state.tmp',JSON.stringify({jobID,hasSession:!!cookie&&!!csrf,hasTicket:!!ticket,counts,fault}));await fs.rename(OUT+'/browser-state.tmp',OUT+'/browser-state.json');});return stateWrites;}
async function observe(kind,r,bytes,reqBody,method){
 if(['STATIC','HEALTH'].includes(kind))return;
 if(kind==='DOWNLOAD'){assert.equal(method,'GET');assert.equal(r.statusCode,200);assert.equal(r.headers['content-type'],'image/jpeg');const sha256=crypto.createHash('sha256').update(bytes).digest('hex');nativeResponses.push({method,status:r.statusCode,size:bytes.length,sha256});assert.equal(nativeResponses.length,1);await note('BROWSER_NATIVE_RESPONSE',{status:r.statusCode,bytes:bytes.length,sha256});return;}
 if(['HEARTBEAT','RELEASE','CANCEL'].includes(kind))return;
 const v=JSON.parse(bytes.toString());
 if(kind==='SESSION'){assert.equal(v.capabilities?.tiktokPhoto,true);csrf=v.csrf;assert.equal(typeof csrf,'string');assert.ok(r.headers['set-cookie']?.length);cookie=r.headers['set-cookie'][0].split(';')[0];await note('BROWSER_SESSION',{capability:true});}
 if(kind==='ADS'){assert.equal(v,null);await note('BROWSER_ADS',{isNull:true});}
 if(kind==='ANALYZE'){assert.equal(r.statusCode,202);assert.match(v.jobId,/^[a-f0-9-]{36}$/);jobID=v.jobId;await note('BROWSER_ANALYZE',{jobID});}
 if(kind==='JOB'){const observation=observeJob(r.statusCode,v,jobID);await note('BROWSER_JOB',observation);if(observation.terminal)fault||=observation.primaryCode;
 if(v.state==='selectable'){while(!await exists('source-selection.json')){assert.ok(performance.now()<end);await sleep(20);}const p=JSON.parse(await readLimited(OUT+'/source-selection.json'));publishedGuard(contract,p);assert.equal(p.jobID,jobID);}}
 if(kind==='DOWNLOAD-TICKET'){assert.equal(r.statusCode,201);assert.match(v.url,/^\/api\/v1\/downloads\/[a-f0-9]{64}$/);ticket=v.url;await note('BROWSER_TICKET',{valid:true});}
 await state();
}
function request(req,res){
 let kind='DENIED';const n=++total;
 res.setHeader('content-security-policy',CSP);res.setHeader('cache-control','no-store');res.setHeader('referrer-policy','no-referrer');res.setHeader('x-content-type-options','nosniff');
 void(async()=>{
  assert.ok(n<=512&&!stopping);assert.equal(req.headers.host,'127.0.0.1:5206');assert.ok(req.url?.startsWith('/')&&!req.url.startsWith('//'));
  const url=new URL(req.url,ORIGIN);assert.equal(url.origin,ORIGIN);kind=category(url.pathname);if(kind==='DENIED'){req.resume();res.statusCode=404;res.end();await note('DENIED',{status:404});return;}assert.ok(allowed(kind,req.method));assert.ok(url.search===''||(kind==='ADS'&&['?placement=banner','?placement=sponsor'].includes(url.search)));
  counts[kind]=(counts[kind]||0)+1;if(['ANALYZE','PREPARE','DOWNLOAD-TICKET'].includes(kind))assert.equal(counts[kind],1);
  if(kind==='ANALYZE'){assertBinding(contract,JSON.parse(await readLimited(OUT+'/host-ready.json')));assert.equal(req.headers.origin,ORIGIN);}
  res.on('finish',()=>{void note('HTTP',{request:n,kind,method:req.method,status:res.statusCode});});
  if(files.has(url.pathname)){res.setHeader('content-type',files.get(url.pathname)[1]);res.end(await fs.readFile('/build/'+files.get(url.pathname)[0]));return;}
  let size=0;const chunks=[];for await(const b of req){size+=b.length;assert.ok(size<=4096);chunks.push(b);}const body=Buffer.concat(chunks);
  if(kind==='ANALYZE'){const v=JSON.parse(body.toString());assert.deepEqual(Object.keys(v),['url']);assert.equal(v.url,contract.approvedURL);}
  let prepareGuard,prepareBody;
  if(kind==='PREPARE'){prepareBody=JSON.parse(body.toString());assert.equal(req.headers.origin,ORIGIN);assert.equal(url.pathname,'/api/v1/jobs/'+jobID+'/prepare');prepareGuard=publishedGuard(contract,JSON.parse(await readLimited(OUT+'/source-selection.json')));}
  if(['JOB','HEARTBEAT','RELEASE','CANCEL','DOWNLOAD-TICKET'].includes(kind))assert.ok(url.pathname==='/api/v1/jobs/'+jobID||url.pathname.startsWith('/api/v1/jobs/'+jobID+'/'));
  const createUpstream=()=>forwardWorkflow(contract,kind,()=>closure.trackRequest(http.request({host:IP,port:3000,path:req.url,method:req.method,headers:req.headers,agent:false},r=>{
   let count=0;const response=[];res.statusCode=r.statusCode||502;
   for(const[k,v]of Object.entries(r.headers))if(v!==undefined&&!['connection','transfer-encoding','content-security-policy'].includes(k))res.setHeader(k,v);
   r.on('data',b=>{count+=b.length;if(count>2*1024*1024){fault||='RESPONSE_CAP';upstream.destroy();res.destroy();return;}response.push(b);});
   r.on('end',()=>{void(async()=>{const bytes=Buffer.concat(response);await observe(kind,r,bytes,body,req.method);res.end(bytes);})().catch(()=>{fault||='RESPONSE_CONTRACT';res.destroy();void state();});});
   r.on('error',()=>{fault||='RESPONSE_ERROR';res.destroy();});
  })));
  if(kind==='PREPARE'){prepareGuard.prepare(jobID,prepareBody,()=>{});await write('browser-selection.json',{itemId:prepareBody.itemId,formatId:prepareBody.formatId});}
  const upstream=kind==='PREPARE'?prepareGuard.prepare(jobID,prepareBody,createUpstream):createUpstream();
  upstream.setTimeout(5000,()=>{fault||='UPSTREAM_TIMEOUT';upstream.destroy();});upstream.on('error',()=>{fault||='UPSTREAM_ERROR';res.destroy();});upstream.end(body);
 })().catch(()=>{fault||='REQUEST_GUARD';res.statusCode=403;res.end();void state();});
}
async function local(method,path,headers={},body){
 return new Promise((resolve,reject)=>{const r=http.request({host:IP,port:3000,path,method,headers:{...headers,...(body?{'content-length':Buffer.byteLength(body)}:{})},agent:false},res=>{let n=0;const chunks=[];res.on('data',b=>{n+=b.length;if(n>2*1024*1024){r.destroy();return;}chunks.push(b);});res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,bytes:Buffer.concat(chunks)}));res.on('error',reject);});closure.trackRequest(r);r.setTimeout(5000,()=>r.destroy());r.on('error',reject);if(body)r.write(body);r.end();});
}
async function finish(){
 assert.ok(cookie&&csrf&&ticket&&jobID&&!fault);
 const foreignSession=await local('GET','/api/v1/session');assert.equal(foreignSession.status,200);const other=foreignSession.headers['set-cookie'][0].split(';')[0];
 const bad=await local('POST','/api/v1/jobs/'+jobID+'/heartbeat',{cookie,origin:ORIGIN,'x-csrf-token':'lab-invalid','content-type':'application/json'},'{}');assert.equal(bad.status,403);assert.equal(JSON.parse(bad.bytes).error.code,'CSRF_INVALID');
 const foreign=await local('GET','/api/v1/jobs/'+jobID,{cookie:other});assert.equal(foreign.status,404);assert.equal(JSON.parse(foreign.bytes).error.code,'JOB_NOT_FOUND');await note('NEGATIVES',{badCSRF:403,wrongSession:404});
 await write('head-before.json',{ready:true});while(!await exists('head-before-ack.json')){assert.ok(performance.now()<end);await sleep(30);}
 const head=await local('HEAD',ticket,{cookie});assert.equal(head.status,200);assert.equal(head.headers['content-type'],'image/jpeg');await write('head-after.json',{status:200});while(!await exists('head-after-ack.json')){assert.ok(performance.now()<end);await sleep(30);}
 const full=await local('GET',ticket,{cookie});assert.equal(full.status,200);assert.equal(full.headers['content-type'],'image/jpeg');assert.equal(full.headers['content-disposition'],'attachment; filename="wed-snap-image.jpg"');
 const expected=JSON.parse(await fs.readFile(OUT+'/core-verified.json','utf8'));const sha=crypto.createHash('sha256').update(full.bytes).digest('hex');assert.equal(sha,expected.sha256);assert.equal(full.bytes.length,expected.size);await fs.writeFile(OUT+'/native-image.jpg',full.bytes,{flag:'wx'});
 const browserNative=checkedBrowserTransfer(nativeResponses,expected);for(const kind of ['ANALYZE','PREPARE','DOWNLOAD-TICKET'])assert.equal(counts[kind],1);
 const range=await local('GET',ticket,{cookie,range:'bytes=0-99'});assert.equal(range.status,206);assert.ok(range.bytes.equals(full.bytes.subarray(0,100)));
 await note('API_TRANSFER',{head:200,get:200,range:206,size:full.bytes.length,sha256:sha});
 return{status:'PASS_GATEWAY_SOURCE',jobID,size:full.bytes.length,sha256:sha,badCSRF:403,wrongSession:404,browserNative,browserSave:'UNKNOWN',sourceAccounting:JSON.parse(await readLimited(OUT+'/source-accounting.json'))};
}
async function cleanup(){
 stopping=true;
 const receipt=await closure.cleanup({server,cancel:jobID&&cookie&&csrf?()=>local('POST','/api/v1/jobs/'+jobID+'/cancel',{cookie,origin:ORIGIN,'x-csrf-token':csrf,'content-type':'application/json'},'{}'):undefined,clearSecrets:()=>{cookie='';csrf='';ticket='';},secretsEmpty:()=>cookie===''&&csrf===''&&ticket==='',limitMs:20000,cancelMs:5000});
 return receipt;
}
async function main(){let result;
 try{
  server=http.createServer(request);server.on('connection',socket=>closure.trackIncoming(socket));server.on('connect',(_r,s)=>{fault||='CONNECT_DENIED';s.destroy();});server.on('upgrade',(_r,s)=>{fault||='UPGRADE_DENIED';s.destroy();});
  await new Promise(r=>server.listen(5206,'0.0.0.0',r));await write('browser.ready',{origin:ORIGIN,fixedUpstream:IP,port:3000,CSP});
  while(!await exists('core-verified.json')){const stop=waitReason('CORE_VERIFIED',{primary:fault,aborted:await exists('browser-abort'),now:performance.now(),end});if(stop)throw stop;await sleep(50);}
  result=await finish();
 }catch(error){result={status:'FAIL_GATEWAY',...reasonRow(error,fault)};process.exitCode=1;}
 finally{let receipt;try{receipt=await cleanup();}catch{receipt={cleanupOK:false,closureOK:false,code:'CLEANUP_RECEIPT_ERROR'};}result=await finalizeSource(result,receipt,writer);if(!receipt.cleanupOK||!result.eventWriter.complete)process.exitCode=1;await write('gateway-cleanup.json',{...receipt,eventWriter:result.eventWriter});await write('gateway-result.json',result);}
}
await main();
}
module.exports={runSourceGateway};
if(require.main===module)runSourceGateway().catch(()=>{process.exitCode=78;});
