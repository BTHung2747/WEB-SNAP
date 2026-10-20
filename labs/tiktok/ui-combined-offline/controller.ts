// Lab orchestration only: production API/processor/media stay unchanged.
import assert from 'node:assert/strict';
import {spawn,ChildProcess} from 'node:child_process';
import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
import {appendFileSync} from 'node:fs';
import {db,redis,queue,defaults} from '/app/packages/shared/src/core';
import {choose} from '/lab/selection';
const OUT='/control', ORIGIN='http://127.0.0.1:5206', TARGET='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const mono=()=>Number(process.hrtime.bigint())/1e9,sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
const read=async(p:string)=>JSON.parse(await readFile(OUT+'/'+p,'utf8'));
const exists=async(p:string)=>{try{await access(p);return true;}catch{return false;}};
let jobID='', worker:ChildProcess|undefined,workerReady=false,fault='';
let consumerExit:number|null=null,consumerSignal:string|null=null;
const events:any[]=[];const end=mono()+280;
function note(event:string,row:any={}){const r={event,elapsed:280-(end-mono()),...row};events.push(r);assert.ok(events.length<=256);appendFileSync(OUT+'/controller.jsonl',JSON.stringify(r)+'\n');}
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

 await writeFile(OUT+'/startup.ready','ready');await writeFile(OUT+'/backend.ready','ready');
}
async function finish(){
 const state=await read('browser-state.json');assert.ok(state.hasSession&&state.hasTicket&&!state.fault);jobID=state.jobID;assert.match(jobID,/^[a-f0-9-]{36}$/);
 const rows=(await readFile(OUT+'/worker.jsonl','utf8')).trim().split('\n').map(JSON.parse);
 for(const phase of ['analyze','prepare']){
  assert.ok(rows.some((r:any)=>r.event==='adapter_parent_closed'&&r.phase===phase&&r.actualExit===0&&r.actualSignal===null&&r.groupLive===0));
  assert.ok(rows.some((r:any)=>r.event==='proxy_phase_gate'&&r.phase===phase&&r.accepted===true));
  const d=await read('cases/happy/'+phase+'.diagnostics.json');assert.equal(d.complete,true);assert.equal(d.metadataAttempts,2);assert.equal(d.imageAttempts,phase==='prepare'?1:0);
  const native=await read('cases/happy/'+phase+'.native.json');assert.equal(native.coreExit,0);
 }
 const p=await read('cases/happy/prepare.diagnostics.json');assert.equal(p.operations.filter((r:any)=>r.operation==='FFPROBE'&&r.event==='END'&&r.returncode===0).length,2);assert.equal(p.operations.filter((r:any)=>r.operation==='DECODE'&&r.event==='END'&&r.returncode===0).length,1);
 const j=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{asset:true}});assert.equal(j.state,'ready');

 const publicJob=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{items:true}});
 const expected=JSON.parse(await readFile('/offline/expectation.json','utf8'));
 const selection=choose({items:publicJob.items},expected.summary),sent=await read('browser-selection.json');
 assert.deepEqual(sent,selection);assert.equal(publicJob.formatId,selection.formatId);
 note('BROWSER_SELECTION_CONFIRMED',{index:2});
 const native=await read('cases/happy/prepare.native.json');
 await writeFile(OUT+'/core-verified.json',JSON.stringify({jobID,size:Number(j.asset!.size),sha256:native.sha256}),{flag:'wx'});
 let before:number|undefined;
 while(!(await exists(OUT+'/gateway-result.json'))){
  assert.ok(mono()<end,'TRANSFER_DEADLINE');
  if(await exists(OUT+'/head-before.json')&&!await exists(OUT+'/head-before-ack.json')){before=await db.transferLease.count({where:{assetId:j.asset!.id}});await writeFile(OUT+'/head-before-ack.json',JSON.stringify({count:before}),{flag:'wx'});}
  if(await exists(OUT+'/head-after.json')&&!await exists(OUT+'/head-after-ack.json')){const after=await db.transferLease.count({where:{assetId:j.asset!.id}});assert.equal(after,before);await writeFile(OUT+'/head-after-ack.json',JSON.stringify({count:after,headLeaseUnchanged:true}),{flag:'wx'});}
  await sleep(30);
 }
 const g=await read('gateway-result.json');assert.equal(g.status,'PASS_GATEWAY_FIXTURE');assert.equal(g.sha256,native.sha256);
 return {status:'PASS_UI_BACKEND_FIXTURE_PENDING_CLEANUP',jobID,selectedIndex:2,size:g.size,sha256:g.sha256,browserSave:'UNKNOWN',sourceCalls:0};
}
async function cleanup(){
 const until=mono()+15;
 if(!jobID&&await exists(OUT+'/browser-state.json'))jobID=(await read('browser-state.json')).jobID;
 if(jobID){
  while(mono()<until){const j=await db.downloadJob.findUnique({where:{id:jobID}});if(j?.cancelRequested&&!j.workerToken&&!await exists('/media/'+jobID))break;await sleep(80);}
  const j=await db.downloadJob.findUniqueOrThrow({where:{id:jobID}});assert.equal(j.cancelRequested,true);assert.equal(j.workerToken,null);assert.equal(await exists('/media/'+jobID),false);
 }
 if(worker&&consumerExit===null){
  await new Promise<void>((resolve,reject)=>{const timer=setTimeout(()=>{worker!.kill('SIGKILL');reject(Error('CONSUMER_CLOSE'));},Math.max(1,(until-mono())*1000));worker!.once('close',()=>{clearTimeout(timer);resolve();});worker!.kill('SIGTERM');});
 }
 assert.equal(consumerExit,0);assert.equal(consumerSignal,null);assert.equal(await db.transferLease.count({where:{state:'started'}}),0);
 await queue.close();redis.disconnect();await db.$disconnect();note('CLEANUP_COMPLETE',{consumerExit,consumerSignal,hadJob:!!jobID,mediaRemoved:!!jobID,workerTokenReleased:!!jobID,startedLeases:0});
}
async function main(){let result:any;
 try{
  await start();while(!await exists(OUT+'/browser-accepted')){assert.ok(mono()<end,'BROWSER_DEADLINE');assert.ok(!await exists(OUT+'/browser-abort'),'BROWSER_ABORT');if(await exists(OUT+'/browser-state.json'))assert.equal((await read('browser-state.json')).fault,'');await sleep(50);}
  result=await finish();
 }catch(e){result={status:'FAIL_STOPPED',code:e instanceof assert.AssertionError?'ASSERTION':e instanceof Error&&/^[A-Z_]{1,70}$/.test(e.message)?e.message:'UNKNOWN'};process.exitCode=1;await writeFile(OUT+'/browser-abort','abort');}
 finally{try{await cleanup();if(result.status==='PASS_UI_BACKEND_FIXTURE_PENDING_CLEANUP')result.status='PASS_UI_BACKEND_FIXTURE_OFFLINE';}catch{result={...result,status:'FAIL_CLEANUP_UNKNOWN'};process.exitCode=1;}await writeFile(OUT+'/result.json',JSON.stringify(result),{flag:'wx'});}
}
main().catch(()=>{process.exitCode=1;});
