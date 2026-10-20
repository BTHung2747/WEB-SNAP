// Offline-only fixed numeric upstream. Secrets stay in this process's RAM.
'use strict';
const http=require('node:http'),fs=require('node:fs/promises'),crypto=require('node:crypto'),net=require('node:net'),assert=require('node:assert/strict');
const OUT='/control',ORIGIN='http://127.0.0.1:5206',IP=process.env.API_IPV4;
assert.equal(process.versions.node,'22.22.3');assert.equal(net.isIPv4(IP),true);
assert.equal(process.env.STEP5_OFFLINE_TEST,'1');assert.equal(process.env.STEP5_EXECUTE_SOURCE,undefined);
const start=performance.now(),end=start+390000;
const files=new Map([['/',['index.html','text/html; charset=utf-8']],['/assets/index-UOIc8eun.js',['assets/index-UOIc8eun.js','application/javascript']],['/assets/index-DCfw3VbE.css',['assets/index-DCfw3VbE.css','text/css']]]);
const CSP="default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; font-src 'self'; img-src 'self' data:; object-src 'none'; frame-src 'none'; worker-src 'none'; media-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'";
let cookie='',csrf='',ticket='',jobID='',fault='',server,stopping=false,total=0;const counts={},sockets=new Set();
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const exists=async f=>{try{await fs.access(OUT+'/'+f);return true;}catch{return false;}};
const write=(f,r)=>fs.writeFile(OUT+'/'+f,JSON.stringify(r),{flag:'wx'});
const note=(event,r={})=>fs.appendFile(OUT+'/gateway-events.jsonl',JSON.stringify({event,elapsedMs:Math.round(performance.now()-start),...r})+'\n');
function category(path){
 if(files.has(path))return'STATIC';if(path==='/api/v1/health')return'HEALTH';if(path==='/api/v1/session')return'SESSION';if(path==='/api/v1/ads')return'ADS';if(path==='/api/v1/jobs/analyze')return'ANALYZE';
 if(/^\/api\/v1\/jobs\/[a-f0-9-]{36}$/.test(path))return'JOB';
 const m=/^\/api\/v1\/jobs\/[a-f0-9-]{36}\/(prepare|heartbeat|release|cancel|download-ticket)$/.exec(path);if(m)return m[1].toUpperCase();
 if(/^\/api\/v1\/downloads\/[a-f0-9]{64}$/.test(path))return'DOWNLOAD';return'DENIED';
}
function allowed(kind,method){return kind==='DOWNLOAD'?['GET','HEAD'].includes(method):['SESSION','ADS','JOB','HEALTH','STATIC'].includes(kind)?method==='GET':['ANALYZE','PREPARE','HEARTBEAT','RELEASE','CANCEL','DOWNLOAD-TICKET'].includes(kind)&&method==='POST';}
let stateWrites=Promise.resolve();
function state(){stateWrites=stateWrites.then(async()=>{await fs.writeFile(OUT+'/browser-state.tmp',JSON.stringify({jobID,hasSession:!!cookie&&!!csrf,hasTicket:!!ticket,counts,fault}));await fs.rename(OUT+'/browser-state.tmp',OUT+'/browser-state.json');});return stateWrites;}
async function observe(kind,r,bytes,reqBody){
 if(['STATIC','HEALTH'].includes(kind))return;
 if(kind==='DOWNLOAD'){assert.equal(r.statusCode,200);assert.equal(r.headers['content-type'],'image/jpeg');await note('BROWSER_NATIVE_RESPONSE',{status:r.statusCode,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});return;}
 if(['HEARTBEAT','RELEASE','CANCEL'].includes(kind))return;
 const v=JSON.parse(bytes.toString());
 if(kind==='SESSION'){assert.equal(v.capabilities?.tiktokPhoto,true);csrf=v.csrf;assert.equal(typeof csrf,'string');assert.ok(r.headers['set-cookie']?.length);cookie=r.headers['set-cookie'][0].split(';')[0];await note('BROWSER_SESSION',{capability:true});}
 if(kind==='ADS'){assert.equal(v,null);await note('BROWSER_ADS',{isNull:true});}
 if(kind==='ANALYZE'){assert.equal(r.statusCode,202);assert.match(v.jobId,/^[a-f0-9-]{36}$/);jobID=v.jobId;await note('BROWSER_ANALYZE',{jobID});}
 if(kind==='JOB'){assert.equal(r.statusCode,200);assert.equal(v.id,jobID);assert.equal(v.previewUrl,null);assert.ok(['analyzing','selectable','queued','preparing','ready'].includes(v.state));await note('BROWSER_JOB',{state:v.state,previewNull:true});}
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
  if(kind==='ANALYZE'){assert.ok(await exists('host-ready.json'));assert.equal(req.headers.origin,ORIGIN);}
  res.on('finish',()=>{void note('HTTP',{request:n,kind,method:req.method,status:res.statusCode});});
  if(files.has(url.pathname)){res.setHeader('content-type',files.get(url.pathname)[1]);res.end(await fs.readFile('/build/'+files.get(url.pathname)[0]));return;}
  let size=0;const chunks=[];for await(const b of req){size+=b.length;assert.ok(size<=4096);chunks.push(b);}const body=Buffer.concat(chunks);
  if(kind==='PREPARE'){const v=JSON.parse(body.toString());assert.equal(req.headers.origin,ORIGIN);assert.equal(typeof v.itemId,'string');assert.equal(typeof v.formatId,'string');await write('browser-selection.json',{itemId:v.itemId,formatId:v.formatId});}
  const upstream=http.request({host:IP,port:3000,path:req.url,method:req.method,headers:req.headers,agent:false},r=>{
   let count=0;const response=[];res.statusCode=r.statusCode||502;
   for(const[k,v]of Object.entries(r.headers))if(v!==undefined&&!['connection','transfer-encoding','content-security-policy'].includes(k))res.setHeader(k,v);
   r.on('data',b=>{count+=b.length;if(count>2*1024*1024){fault='RESPONSE_CAP';upstream.destroy();res.destroy();return;}response.push(b);});
   r.on('end',()=>{void observe(kind,r,Buffer.concat(response),body).catch(()=>{fault='RESPONSE_CONTRACT';void state();});});
   r.on('error',()=>{fault='RESPONSE_ERROR';res.destroy();});r.pipe(res);
  });
  upstream.setTimeout(5000,()=>{fault='UPSTREAM_TIMEOUT';upstream.destroy();});upstream.on('error',()=>{fault||='UPSTREAM_ERROR';res.destroy();});upstream.end(body);
 })().catch(()=>{fault||='REQUEST_GUARD';res.statusCode=403;res.end();void state();});
}
async function local(method,path,headers={},body){
 return new Promise((resolve,reject)=>{const r=http.request({host:IP,port:3000,path,method,headers:{...headers,...(body?{'content-length':Buffer.byteLength(body)}:{})},agent:false},res=>{let n=0;const chunks=[];res.on('data',b=>{n+=b.length;if(n>2*1024*1024){r.destroy();return;}chunks.push(b);});res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,bytes:Buffer.concat(chunks)}));res.on('error',reject);});r.setTimeout(5000,()=>r.destroy());r.on('error',reject);if(body)r.write(body);r.end();});
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
 const range=await local('GET',ticket,{cookie,range:'bytes=0-99'});assert.equal(range.status,206);assert.ok(range.bytes.equals(full.bytes.subarray(0,100)));
 await note('API_TRANSFER',{head:200,get:200,range:206,size:full.bytes.length,sha256:sha});
 return{status:'PASS_GATEWAY_FIXTURE',jobID,size:full.bytes.length,sha256:sha,badCSRF:403,wrongSession:404,browserSave:'UNKNOWN',sourceCalls:0};
}
async function cleanup(){
 if(jobID&&cookie&&csrf){const r=await local('POST','/api/v1/jobs/'+jobID+'/cancel',{cookie,origin:ORIGIN,'x-csrf-token':csrf,'content-type':'application/json'},'{}');assert.equal(r.status,200);await note('CANCEL',{status:200,jobID});}
 stopping=true;await new Promise(r=>{server.close(r);server.closeAllConnections();});for(const s of sockets)s.destroy();for(let i=0;sockets.size&&i<20;i++)await sleep(10);cookie='';csrf='';ticket='';assert.equal(sockets.size,0);await write('gateway-cleanup.json',{listenerClosed:!server.listening,sockets:0,secretsCleared:true});
}
async function main(){let result;
 try{
  server=http.createServer(request);server.on('connection',s=>{sockets.add(s);s.on('close',()=>sockets.delete(s));});server.on('connect',(_r,s)=>{fault='CONNECT_DENIED';s.destroy();});server.on('upgrade',(_r,s)=>{fault='UPGRADE_DENIED';s.destroy();});
  await new Promise(r=>server.listen(5206,'0.0.0.0',r));await write('browser.ready',{origin:ORIGIN,fixedUpstream:IP,port:3000,CSP});
  while(!await exists('core-verified.json')){assert.ok(!fault,fault);assert.ok(!await exists('browser-abort'),'BROWSER_ABORT');assert.ok(performance.now()<end,'GATEWAY_DEADLINE');await sleep(50);}
  result=await finish();
 }catch{result={status:'FAIL_GATEWAY',code:fault||'GATEWAY_CONTRACT'};process.exitCode=1;}
 finally{try{await cleanup();}catch{result={...result,status:'FAIL_GATEWAY_CLEANUP'};process.exitCode=1;}await write('gateway-result.json',result);}
}
main().catch(()=>{process.exitCode=1;});
