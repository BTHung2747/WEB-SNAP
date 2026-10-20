import {spawn,ChildProcess} from 'node:child_process';
import {readFile,writeFile,mkdir,access,rename} from 'node:fs/promises';
import {appendFileSync} from 'node:fs';
import {randomUUID,createHash} from 'node:crypto';
import {db,redis,queue,defaults} from '/app/packages/shared/src/core';
import {choose} from './selection';
const ROOT='/control',BASE='http://127.0.0.1:3000/api/v1/',ORIGIN='http://step5-executor.invalid';
const TARGET='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';
const mono=()=>Number(process.hrtime.bigint())/1e9,sleep=(n:number)=>new Promise(r=>setTimeout(r,n));
async function json(path:string){return JSON.parse(await readFile(path,'utf8'));}
async function exists(path:string){try{await access(path);return true;}catch{return false;}}
export async function runWorkflow(cfg:any){
 const source=cfg.mode==='source';
 if(source?(process.env.STEP5_EXECUTE_SOURCE!=='1'||cfg.url!==TARGET||cfg.expectation!=='/lab/expectation-source.json'):(cfg.mode!=='offline'||process.env.STEP5_OFFLINE_TEST!=='1'||!cfg.expectation.startsWith('/offline/')))throw Error('EXECUTION_DISABLED');
 if(!/^[a-z][a-z-]{0,30}$/.test(cfg.case))throw Error('CASE_INVALID');
 const expected=await json(cfg.expectation),summary=expected.summary;
 const dir=ROOT+'/cases/'+cfg.case;await mkdir(dir,{recursive:true});
 const rows:any[]=[];let worker:ChildProcess|undefined,client:any,id='',cleaned=false,localEnd=Infinity,eventCount=0;
 const end=mono()+250;let stage='STARTUP',failure='UNKNOWN';
 const active={case:cfg.case,mode:cfg.mode,url:cfg.url,end,wallEnd:Date.now()+250000};
 await writeFile(ROOT+'/active.tmp',JSON.stringify(active));await rename(ROOT+'/active.tmp',ROOT+'/active.json');
 function bounded(max=5,cleanup=false){const left=Math.min(max,cleanup?20:end-mono(),cleanup?20:localEnd-mono());if(left<=0)throw Error('ABSOLUTE_DEADLINE');return Math.max(1,Math.floor(left*1000));}
 function record(event:string,data:any={}){rows.push({event,stage,elapsedSeconds:250-(end-mono()),...data});if(rows.length>128)throw Error('EVENT_CAP');}
 async function request(path:string,body?:any,cap=5,cleanup=false){
  const r=await fetch(BASE+path,{method:body===undefined?'GET':'POST',headers:{cookie:client?.cookie||'',origin:ORIGIN,'x-csrf-token':client?.csrf||'','content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(bounded(cap,cleanup))});return r;
 }
 async function api(path:string,body?:any,cap=5,cleanup=false){const r=await request(path,body,cap,cleanup);const value:any=await r.json();if(!r.ok){record('API_ERROR',{httpStatus:r.status});throw Error('API_STATUS');}return {status:r.status,data:value};}
 function capture(line:string){
  const r=JSON.parse(line),allow=['LAB_CONSUMER_READY','QUEUE_ERROR','adapter_parent_closed','proxy_phase_gate','adapter_group_stopped','worker_complete','worker_failed'];
  if(!allow.includes(r.event))return;
  const row:any={event:r.event};for(const k of ['id','phase','actualExit','actualSignal','groupLive','registryProtected','accepted','connections','code','inputBytes','workerMs','concurrency','maxStalledCount','maxStartedAttempts']){
   const v=r[k];if(v===undefined)continue;if(v===null||typeof v==='number'||typeof v==='boolean'||(k==='id'&&/^[a-f0-9-]{36}$/.test(v))||(k==='phase'&&['analyze','prepare'].includes(v))||(k==='actualSignal'&&['SIGTERM','SIGKILL'].includes(v))||(k==='code'&&/^[A-Z_]{1,50}$/.test(v)))row[k]=v;
  }
  if(++eventCount>128)throw Error('WORKER_EVENT_CAP');appendFileSync(dir+'/worker.jsonl',JSON.stringify(row)+'\n');
 }
 async function startWorker(){
  worker=spawn('/app/node_modules/.bin/tsx',['/lab/worker.ts'],{cwd:'/app',env:process.env,stdio:['ignore','pipe','pipe']});let buffer='';let ready=false;
  worker.stdout!.on('data',b=>{buffer+=b;if(buffer.length>65536){worker!.kill('SIGTERM');return;}let n;while((n=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,n);buffer=buffer.slice(n+1);try{capture(line);if(JSON.parse(line).event==='LAB_CONSUMER_READY')ready=true;}catch{worker!.kill('SIGTERM');}}});worker.stderr!.on('data',()=>{});
  const until=mono()+10;while(!ready){if(mono()>=until||worker.exitCode!==null)throw Error('CONSUMER_START');await sleep(30);}
 }
 async function state(target:string,phase:string){
  const queueEnd=mono()+10,phaseEnd=Math.min(end,mono()+(phase==='analyze'?30:180));let heartbeat=mono()+15;
  for(;;){const started=await exists(dir+'/'+phase+'.consumer-once');const cap=started?5:Math.min(5,queueEnd-mono());if(cap<=0)throw Error('QUEUE_DEADLINE');const r=await api('jobs/'+id,undefined,Math.min(cap,phaseEnd-mono()));if(r.data.state===target)return r.data;
   if(['failed','expired','cancelled'].includes(r.data.state))throw Error('JOB_TERMINAL');if(mono()>=phaseEnd)throw Error('PHASE_DEADLINE');if(mono()>=heartbeat){await api('jobs/'+id+'/heartbeat',{});heartbeat=mono()+15;}await sleep(80);}
 }
 async function receipt(phase:string){
  const d=await json(dir+'/'+phase+'.diagnostics.json');if(!d.complete||d.metadataAttempts>2||d.imageAttempts>(phase==='prepare'?1:0)||d.wireGET!=='UNKNOWN')throw Error('DIAGNOSTICS_INCOMPLETE');
  record('PHASE_ACCOUNTING',{phase,attempts:d.attempts,observedResponses:d.observedResponses,decodedBytes:d.diagnostics.inputBytes,wireGET:'UNKNOWN'});return d;
 }
 async function cleanup(){
  stage='CLEANUP';const until=mono()+20;
  let uncertain=false;
  if(id){await api('jobs/'+id+'/cancel',{},Math.min(5,until-mono()),true).catch(()=>{});
   while(mono()<until){const job=await db.downloadJob.findUnique({where:{id}});if(!job?.workerToken&&!(await exists('/media/'+id))){cleaned=true;break;}await sleep(80);}
   if(!cleaned)uncertain=true;
  }else cleaned=true;
  if(worker){const p=worker;worker=undefined;let code=p.exitCode;
   if(code===null){const closed=new Promise<number|null>(r=>p.once('close',r));p.kill('SIGTERM');let timer:NodeJS.Timeout|undefined;code=await Promise.race([closed,new Promise<number>(r=>{timer=setTimeout(()=>{p.kill('SIGKILL');r(91);},Math.max(1,Math.min(6000,(until-mono())*1000)));})]);if(timer)clearTimeout(timer);}
   record('CONSUMER_EXIT',{actualExit:code});if(code!==0)uncertain=true;
  }
  if(uncertain)throw Error('CLEANUP_UNKNOWN');
 }
 let result:any;
 try{
  const startup=mono()+60;for(;;){try{if((await fetch(BASE+'health',{signal:AbortSignal.timeout(1000)})).ok)break;}catch{}if(mono()>=startup)throw Error('STARTUP_DEADLINE');await sleep(80);}
  await writeFile(ROOT+'/startup.ready','ready');
  await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}},update:{value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}}});
  const session=await fetch(BASE+'session',{signal:AbortSignal.timeout(bounded())});if(!session.ok)throw Error('SESSION_STATUS');const s:any=await session.json();if(s.capabilities?.tiktokPhoto!==true)throw Error('CAPABILITY_FALSE');const cookie=session.headers.get('set-cookie');if(!cookie)throw Error('SESSION_COOKIE');client={cookie:cookie.split(';')[0],csrf:s.csrf};
  await startWorker();stage='ANALYZE';const analyzed=await api('jobs/analyze',{url:cfg.url});if(analyzed.status!==202)throw Error('ANALYZE_STATUS');id=analyzed.data.jobId;record('ANALYZE_ACCEPTED',{jobId:id});
  const selectable=await state('selectable','analyze'),a=await receipt('analyze');stage='SELECTION';const selected=choose(selectable,summary);record('SELECTION_MATCH',{index:2,imageCount:summary.imageCount,snapshotKey:summary.snapshotKey});
  stage='PREPARE';const prepared=await api('jobs/'+id+'/prepare',{...selected,idempotencyKey:randomUUID()});if(prepared.status!==202)throw Error('PREPARE_STATUS');await state('ready','prepare');const d=await receipt('prepare');
  if(a.attempts+d.attempts>5||d.imageAttempts!==1)throw Error('WORKFLOW_ATTEMPTS');
  const core=await json(dir+'/prepare.native.json');if(core.coreExit!==0||!core.fileExists||!core.sha256)throw Error('NATIVE_UNKNOWN');
  const ops=d.operations||[];if(ops.filter((r:any)=>r.operation==='FFPROBE'&&r.event==='END'&&r.returncode===0).length!==2||ops.filter((r:any)=>r.operation==='DECODE'&&r.event==='END'&&r.returncode===0).length!==1)throw Error('FILE_CONTRACT');
  stage='LOCAL_DOWNLOAD';localEnd=Math.min(end,mono()+20);const ticket=await api('jobs/'+id+'/download-ticket',{}),url=ticket.data.url;
  if(ticket.status!==201||!/^\/api\/v1\/downloads\/[a-f0-9]{64}$/.test(url))throw Error('TICKET_POLICY');
  const job=await db.downloadJob.findUniqueOrThrow({where:{id},include:{asset:true}});const leases=await db.transferLease.count({where:{assetId:job.asset!.id}});
  const local=(method:string,range?:string)=>fetch('http://127.0.0.1:3000'+url,{method,headers:{cookie:client.cookie,...(range?{range}:{})},signal:AbortSignal.timeout(bounded(20))});
  const head=await local('HEAD');if(head.status!==200||head.headers.get('content-type')!=='image/jpeg'||head.headers.get('content-disposition')!=='attachment; filename="wed-snap-image.jpg"'||await db.transferLease.count({where:{assetId:job.asset!.id}})!==leases)throw Error('LOCAL_HEAD');
  const response=await local('GET');if(response.status!==200||response.headers.get('content-type')!=='image/jpeg')throw Error('LOCAL_GET');const parts:Buffer[]=[];let size=0;for await(const chunk of response.body as any){size+=chunk.length;if(size>16*1024*1024||mono()>=localEnd)throw Error('LOCAL_CAP');parts.push(Buffer.from(chunk));}const bytes=Buffer.concat(parts),sha=createHash('sha256').update(bytes).digest('hex');
  if(sha!==core.sha256||bytes[0]!==255||bytes[1]!==216||bytes.length!==Number(job.asset!.size))throw Error('FILE_SHA');await writeFile(dir+'/native-image.jpg',bytes,{flag:'wx'});
  record('NATIVE_FILE',{size:bytes.length,sha256:sha,mime:'image/jpeg',localHEAD:1,localGET:1});
  if(source&&sha!==expected.historicalFileIndex2.sha256)throw Error('HISTORICAL_BYTES_DIFFER_NEEDS_REVIEW');
  const range=await local('GET','bytes=0-99');if(range.status!==206||!Buffer.from(await range.arrayBuffer()).equals(bytes.subarray(0,100)))throw Error('LOCAL_RANGE');
  record('LOCAL_RANGE',{status:206,bytes:100});localEnd=Infinity;
  result={status:'PASS_TECHNICAL_NEEDS_VISUAL_REVIEW',mode:cfg.mode,jobId:id,selectedIndex:2,attempts:a.attempts+d.attempts,metadataAttempts:a.metadataAttempts+d.metadataAttempts,imageAttempts:1,wireGET:'UNKNOWN',sha256:sha,size,sourceExecutionStarted:source,sourceCalls:source?'SEE_ATTEMPTS_RESPONSE_ACCOUNTING':0,visual:'NEEDS_VISUAL_REVIEW',browserCombined:'NOT_RUN'};
 }catch(e){failure=e instanceof Error&&/^[A-Z_]{1,70}$/.test(e.message)?e.message:'UNKNOWN';record('WORKFLOW_FAIL',{code:failure});result={status:'FAIL_STOPPED',mode:cfg.mode,jobId:id||null,failedStage:stage,code:failure,wireGET:'UNKNOWN',sourceExecutionStarted:source,sourceCalls:source?'UNKNOWN_OR_OBSERVED_ATTEMPTS':0};}
 finally{
  try{await cleanup();record('CLEANUP_COMPLETE',{ownedMediaRemoved:cleaned});}catch{result={...result,status:'FAIL_CLEANUP_UNKNOWN',cleanup:'UNKNOWN'};}
  result.events=rows;await writeFile(dir+'/result.json',JSON.stringify(result,null,2));
 }
 return result;
}
export async function closeConnections(){await queue.close();redis.disconnect();await db.$disconnect();}
