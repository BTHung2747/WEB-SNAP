// Lab orchestration only: production API/processor/media stay unchanged.
import assert from 'node:assert/strict';
import http from 'node:http';
import {spawn,ChildProcess} from 'node:child_process';
import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
import {appendFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {db,redis,queue,defaults} from '/app/packages/shared/src/core';
import {choose} from '/lab/selection';
const OUT='/control', ORIGIN='http://127.0.0.1:5206', TARGET='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const mono=()=>Number(process.hrtime.bigint())/1e9,sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
const read=async(p:string)=>JSON.parse(await readFile(OUT+'/'+p,'utf8'));
const exists=async(p:string)=>{try{await access(p);return true;}catch{return false;}};
const CSP="default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; font-src 'self'; img-src 'self' data:; object-src 'none'; frame-src 'none'; worker-src 'none'; media-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'";
const files=new Map([['/',['index.html','text/html; charset=utf-8']],['/assets/index-UOIc8eun.js',['assets/index-UOIc8eun.js','application/javascript']],['/assets/index-DCfw3VbE.css',['assets/index-DCfw3VbE.css','text/css']]]);
let jobID='', browserCookie='',browserCSRF='',ticket='', worker:ChildProcess|undefined,workerReady=false,fault='',stopping=false;
let gateway:http.Server,consumerExit:number|null=null,consumerSignal:string|null=null;
let requestNumber=0; const events:any[]=[];const counts:Record<string,number>={};const end=mono()+250;
function note(event:string,row:any={}){const r={event,elapsed:250-(end-mono()),...row};events.push(r);assert.ok(events.length<=256);appendFileSync(OUT+'/controller.jsonl',JSON.stringify(r)+'\n');}
function category(path:string){
 if(files.has(path))return 'STATIC';if(path==='/api/v1/session')return 'SESSION';if(path==='/api/v1/ads')return 'ADS';
 if(path==='/api/v1/jobs/analyze')return 'ANALYZE';
 if(/^\/api\/v1\/jobs\/[a-f0-9-]{36}$/.test(path))return 'JOB';
 const m=/^\/api\/v1\/jobs\/[a-f0-9-]{36}\/(prepare|heartbeat|release|cancel|download-ticket)$/.exec(path);
 if(m)return m[1].toUpperCase();if(/^\/api\/v1\/downloads\/[a-f0-9]{64}$/.test(path))return 'DOWNLOAD';return 'DENIED';
}
function workerLine(line:string){
 let r:any;try{r=JSON.parse(line);}catch{return;}
 if(!['LAB_CONSUMER_READY','QUEUE_ERROR','adapter_parent_closed','proxy_phase_gate','adapter_group_stopped','worker_complete','worker_failed'].includes(r.event))return;
 const safe:any={event:r.event};
 for(const k of ['id','phase','actualExit','actualSignal','groupLive','registryProtected','accepted','connections','code','inputBytes']){
  const v=r[k];if(v===null||typeof v==='number'||typeof v==='boolean'||(k==='id'&&/^[a-f0-9-]{36}$/.test(v))||(k==='phase'&&['analyze','prepare'].includes(v))||(k==='actualSignal'&&['SIGTERM','SIGKILL'].includes(v))||(k==='code'&&/^[A-Z_]{1,50}$/.test(v)))safe[k]=v;
 }
 appendFileSync(OUT+'/worker.jsonl',JSON.stringify(safe)+'\n');
 if(r.event==='LAB_CONSUMER_READY')workerReady=true;if(r.event==='QUEUE_ERROR')fault='QUEUE_ERROR';
}
async function start(){
 assert.equal(process.env.STEP5_EXECUTE_SOURCE,undefined);assert.equal(process.env.STEP5_OFFLINE_TEST,'1');assert.equal(process.env.APP_ORIGIN,ORIGIN);
 assert.equal(process.versions.node,'22.22.3');
 await writeFile(OUT+'/versions.json',JSON.stringify({node:process.versions.node,transport:'node:http',dependencyAdded:false}));
 for(let i=0;;i++){try{if((await fetch('http://127.0.0.1:3000/api/v1/health',{signal:AbortSignal.timeout(1000)})).ok)break;}catch{}assert.ok(i<150,'API_STARTUP');await sleep(100);}
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}},update:{value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}}});
 assert.equal(await db.adCampaign.count(),0);await mkdir(OUT+'/cases/happy',{recursive:true});
 await writeFile(OUT+'/mode.json',JSON.stringify({mode:'happy'}));
 await writeFile(OUT+'/active.json',JSON.stringify({case:'happy',mode:'offline',url:TARGET,end,wallEnd:Date.now()+Math.max(1,(end-mono())*1000)}));
 worker=spawn('/app/node_modules/.bin/tsx',['/lab/worker.ts'],{cwd:'/app',env:process.env,stdio:['ignore','pipe','pipe']});
 worker.once('close',(code,signal)=>{consumerExit=code;consumerSignal=signal;});
 let buffer='';worker.stdout!.on('data',b=>{buffer+=b;if(buffer.length>65536){fault='WORKER_OUTPUT_CAP';return;}let at;while((at=buffer.indexOf('\n'))>=0){workerLine(buffer.slice(0,at));buffer=buffer.slice(at+1);}});worker.stderr!.on('data',()=>{});
 const readyEnd=mono()+10;while(!workerReady){assert.ok(mono()<readyEnd&&worker.exitCode===null,'CONSUMER_START');await sleep(30);}
 gateway=http.createServer(async(req,res)=>{
  const n=++requestNumber;let path='',kind='DENIED';
  res.setHeader('content-security-policy',CSP);res.setHeader('cache-control','no-store');res.setHeader('referrer-policy','no-referrer');res.setHeader('x-content-type-options','nosniff');
  try{
   assert.ok(n<=256&&!stopping);assert.equal(req.headers.host,'127.0.0.1:5206');assert.ok(req.url?.startsWith('/')&&!req.url.startsWith('//'));
   path=new URL(req.url!,ORIGIN).pathname;kind=category(path);assert.notEqual(kind,'DENIED');
   counts[kind]=(counts[kind]||0)+1;
   if(kind==='ANALYZE'||kind==='PREPARE'||kind==='DOWNLOAD-TICKET')assert.equal(counts[kind],1,'BROWSER_ONCE');
   res.on('finish',()=>appendFileSync(OUT+'/gateway.jsonl',JSON.stringify({request:n,kind,method:req.method,status:res.statusCode,elapsed:250-(end-mono()),originGuard:true})+'\n'));
   if(files.has(path)){assert.equal(req.method,'GET');const [f,type]=files.get(path)!;res.setHeader('content-type',type);res.end(await readFile('/build/'+f));return;}
   const chunks:Buffer[]=[];let input=0;for await(const b of req){input+=b.length;assert.ok(input<=4096);chunks.push(Buffer.from(b));}const body=Buffer.concat(chunks);
   if(kind==='PREPARE'){
    const publicJob=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{items:true}});
    const expected=await readFile('/offline/expectation.json','utf8');
    const selection=choose({items:publicJob.items.map((i:any)=>({...i,formats:i.formats}))},JSON.parse(expected).summary);
    const sent=JSON.parse(body.toString());assert.equal(sent.itemId,selection.itemId);assert.equal(sent.formatId,selection.formatId);note('BROWSER_SELECTED',{index:2});
   }
   const upstream=http.request({host:'127.0.0.1',port:3000,path:req.url,method:req.method,headers:req.headers,agent:false},r=>{
    let size=0;const response:Buffer[]=[];res.statusCode=r.statusCode||502;
    for(const [key,v] of Object.entries(r.headers))if(v!==undefined&& !['connection','transfer-encoding','content-security-policy'].includes(key))res.setHeader(key,v);
    r.on('data',(b:Buffer)=>{size+=b.length;if(size>2*1024*1024){fault='GATEWAY_RESPONSE_CAP';upstream.destroy();return;}if(kind!=='DOWNLOAD')response.push(Buffer.from(b));});
    r.on('end',()=>{try{
     if(kind==='DOWNLOAD'){note('BROWSER_MEDIA_RESPONSE',{status:r.statusCode,bytes:size});return;}
     const value=JSON.parse(Buffer.concat(response).toString());
     if(kind==='SESSION'){assert.equal(value.capabilities?.tiktokPhoto,true);browserCSRF=value.csrf;const c=r.headers['set-cookie'];assert.ok(c?.length);browserCookie=c![0].split(';')[0];note('BROWSER_SESSION',{capability:true});}
     if(kind==='ADS')assert.equal(value,null);
     if(kind==='ANALYZE'){assert.equal(r.statusCode,202);assert.match(value.jobId,/^[a-f0-9-]{36}$/);jobID=value.jobId;note('BROWSER_ANALYZE',{jobID});}
     if(kind==='JOB'){assert.equal(value.previewUrl,null);assert.ok(['analyzing','selectable','queued','preparing','ready','failed','cancelled','expired'].includes(value.state));if(['failed','expired'].includes(value.state))fault='JOB_TERMINAL';note('BROWSER_JOB',{state:value.state});}
     if(kind==='DOWNLOAD-TICKET'){assert.equal(r.statusCode,201);assert.match(value.url,/^\/api\/v1\/downloads\/[a-f0-9]{64}$/);ticket=value.url;note('BROWSER_TICKET',{valid:true});}
    }catch{fault='GATEWAY_CONTRACT';}});
    r.on('error',()=>{fault='GATEWAY_RESPONSE';res.destroy();});r.pipe(res);
   });
   upstream.setTimeout(5000,()=>{fault='GATEWAY_TIMEOUT';upstream.destroy();});upstream.on('error',()=>{fault||='GATEWAY_UPSTREAM';res.destroy();});upstream.end(body);
  }catch{fault||='GATEWAY_GUARD';res.statusCode=403;res.end();note('GATEWAY_DENIED',{request:n,kind});}
 });
 gateway.on('connect',(_r,s)=>{fault='GATEWAY_CONNECT_DENIED';s.destroy();});
 gateway.on('upgrade',(_r,s)=>{fault='GATEWAY_UPGRADE_DENIED';s.destroy();});
 await new Promise<void>(r=>gateway.listen(5206,'0.0.0.0',r));
 await writeFile(OUT+'/startup.ready','ready');await writeFile(OUT+'/browser.ready',JSON.stringify({origin:ORIGIN,fixtureURL:TARGET,CSP,outsideOriginInterception:'UNAVAILABLE',blockedOutsideOriginCount:'UNKNOWN'}));
}
async function finish(){
 assert.ok(jobID&&browserCookie&&browserCSRF&&ticket,'BROWSER_INCOMPLETE');
 const rows=(await readFile(OUT+'/worker.jsonl','utf8')).trim().split('\n').map(JSON.parse);
 for(const phase of ['analyze','prepare']){
  assert.ok(rows.some((r:any)=>r.event==='adapter_parent_closed'&&r.phase===phase&&r.actualExit===0&&r.actualSignal===null&&r.groupLive===0));
  assert.ok(rows.some((r:any)=>r.event==='proxy_phase_gate'&&r.phase===phase&&r.accepted===true));
  const d=await read('cases/happy/'+phase+'.diagnostics.json');assert.equal(d.complete,true);assert.equal(d.metadataAttempts,2);assert.equal(d.imageAttempts,phase==='prepare'?1:0);
  const native=await read('cases/happy/'+phase+'.native.json');assert.equal(native.coreExit,0);
 }
 const p=await read('cases/happy/prepare.diagnostics.json');assert.equal(p.operations.filter((r:any)=>r.operation==='FFPROBE'&&r.event==='END'&&r.returncode===0).length,2);assert.equal(p.operations.filter((r:any)=>r.operation==='DECODE'&&r.event==='END'&&r.returncode===0).length,1);
 const j=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{asset:true}});assert.equal(j.state,'ready');
 // Control probes only after the browser workflow; no extra analyze or prepare.
 const negSession=await fetch('http://127.0.0.1:3000/api/v1/session',{signal:AbortSignal.timeout(5000)});assert.equal(negSession.status,200);const otherCookie=negSession.headers.get('set-cookie')!.split(';')[0];await negSession.arrayBuffer();
 const bad=await fetch('http://127.0.0.1:3000/api/v1/jobs/'+jobID+'/heartbeat',{method:'POST',headers:{cookie:browserCookie,origin:ORIGIN,'x-csrf-token':'lab-invalid','content-type':'application/json'},body:'{}',signal:AbortSignal.timeout(5000)});
 const badValue:any=await bad.json();assert.equal(bad.status,403);assert.equal(badValue.error.code,'CSRF_INVALID');note('BAD_CSRF',{status:403,code:'CSRF_INVALID'});
 const foreign=await fetch('http://127.0.0.1:3000/api/v1/jobs/'+jobID,{headers:{cookie:otherCookie},signal:AbortSignal.timeout(5000)});const f:any=await foreign.json();assert.equal(foreign.status,404);assert.equal(f.error.code,'JOB_NOT_FOUND');note('WRONG_SESSION',{status:404,code:'JOB_NOT_FOUND'});
 const local=async(method:string,range?:string)=>fetch('http://127.0.0.1:3000'+ticket,{method,headers:{cookie:browserCookie,...(range?{range}:{})},signal:AbortSignal.timeout(5000)});
 const leases=await db.transferLease.count({where:{assetId:j.asset!.id}});const head=await local('HEAD');assert.equal(head.status,200);assert.equal(head.headers.get('content-type'),'image/jpeg');assert.equal(await db.transferLease.count({where:{assetId:j.asset!.id}}),leases);
 const response=await local('GET');assert.equal(response.status,200);assert.equal(response.headers.get('content-disposition'),'attachment; filename="wed-snap-image.jpg"');const bytes=Buffer.from(await response.arrayBuffer());assert.ok(bytes.length<=16*1024*1024);const sha=createHash('sha256').update(bytes).digest('hex');assert.equal(sha,(await read('cases/happy/prepare.native.json')).sha256);assert.equal(bytes.length,Number(j.asset!.size));await writeFile(OUT+'/native-image.jpg',bytes,{flag:'wx'});
 const range=await local('GET','bytes=0-99');assert.equal(range.status,206);assert.ok(Buffer.from(await range.arrayBuffer()).equals(bytes.subarray(0,100)));
 note('API_TRANSFER',{head:200,headLeaseUnchanged:true,get:200,range:206,size:bytes.length,sha256:sha});
 return {status:'PASS_UI_BACKEND_FIXTURE_PENDING_CLEANUP',selectedIndex:2,jobID,size:bytes.length,sha256:sha,fixtureMetadataRequests:4,fixtureImageRequests:1,badCSRF:403,wrongSession:404,browserDownload:'SEE_BROWSER_OBSERVATIONS',deviceSaved:'UNKNOWN',outsideOriginInterception:'UNAVAILABLE',blockedOutsideOriginCount:'UNKNOWN',sourceRequests:0,publicDNSQueries:0,claimsCreated:0};
}
async function cleanup(){
 stopping=true;const until=mono()+20;
 if(gateway){await new Promise<void>(r=>gateway.close(()=>r()));gateway.closeAllConnections();}
 if(jobID&&browserCookie){const r=await fetch('http://127.0.0.1:3000/api/v1/jobs/'+jobID+'/cancel',{method:'POST',headers:{cookie:browserCookie,origin:ORIGIN,'x-csrf-token':browserCSRF,'content-type':'application/json'},body:'{}',signal:AbortSignal.timeout(5000)});assert.equal(r.status,200);await r.arrayBuffer();
  while(mono()<until){const j=await db.downloadJob.findUnique({where:{id:jobID}});if(!j?.workerToken&&!(await exists('/media/'+jobID)))break;await sleep(80);}assert.equal(await exists('/media/'+jobID),false);assert.equal((await db.downloadJob.findUnique({where:{id:jobID}}))?.workerToken,null);
 }
 if(worker){const closed=new Promise<void>(r=>worker!.once('close',()=>r()));if(consumerExit===null){worker.kill('SIGTERM');await Promise.race([closed,sleep(Math.max(1,(until-mono())*1000)).then(()=>{worker!.kill('SIGKILL');throw Error('CONSUMER_CLOSE');})]);}assert.equal(consumerExit,0);assert.equal(consumerSignal,null);}
 assert.equal(await db.transferLease.count({where:{state:'started'}}),0);await queue.close();redis.disconnect();await db.$disconnect();
 note('CLEANUP_COMPLETE',{consumerExit,consumerSignal,mediaRemoved:true,workerTokenReleased:true,startedLeases:0});browserCookie='';browserCSRF='';ticket='';
}
async function main(){let result:any;
 try{await start();while(!(await exists(OUT+'/browser-complete.json'))){assert.ok(!fault,fault);assert.ok(mono()<end,'BROWSER_WORKFLOW_DEADLINE');assert.ok(!(await exists(OUT+'/browser-fail.json')),'BROWSER_ORIGIN_GUARD');await sleep(100);}assert.equal(fault,'');result=await finish();}
 catch(e){result={status:'FAIL_STOPPED',code:e instanceof assert.AssertionError?'ASSERTION':e instanceof Error&&/^[A-Z_]{1,70}$/.test(e.message)?e.message:'UNKNOWN'};process.exitCode=1;}
 finally{try{await cleanup();if(result.status==='PASS_UI_BACKEND_FIXTURE_PENDING_CLEANUP')result.status='PASS_UI_BACKEND_FIXTURE_OFFLINE';}catch{result={...result,status:'FAIL_CLEANUP_UNKNOWN'};process.exitCode=1;}await writeFile(OUT+'/result.json',JSON.stringify({...result,counts,sourceRequests:0,publicDNSQueries:0,claimsCreated:0,outsideOriginInterception:'UNAVAILABLE',blockedOutsideOriginCount:'UNKNOWN'},null,2));}
}
main().catch(()=>{process.exitCode=1;});
