// Lab orchestration only: production API/processor/media stay unchanged.
import assert from 'node:assert/strict';
import {waitReason,reasonRow} from '../ui-observation-fix/reasons.cjs';
import {spawn,ChildProcess} from 'node:child_process';
import {readFile,writeFile,mkdir,access} from 'node:fs/promises';
import {appendFileSync} from 'node:fs';
import {runtimeContract,remainingSeconds,binding} from './contract.cjs';
import {createSelectionGuard,selectionRecord,phaseAccounting,startPassive,closePassive,stopConsumer} from './policy.cjs';
export async function runSourceController(){
const contract=await runtimeContract();
const photos=await import('/app/packages/shared/src/tiktok-photo');
assert.equal(photos.photoPostId(contract.approvedURL),contract.expectedPostID);
const {db,redis,queue,defaults}=await import('/app/packages/shared/src/core');
const guard=createSelectionGuard(contract,photos);
let selectionPublished=false;
const OUT='/control', ORIGIN='http://127.0.0.1:5206', TARGET=contract.approvedURL;
const mono=()=>Number(process.hrtime.bigint())/1e9,sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
const read=async(p:string)=>JSON.parse(await readFile(OUT+'/'+p,'utf8'));
const exists=async(p:string)=>{try{await access(p);return true;}catch{return false;}};
let jobID='', worker:ChildProcess|undefined,workerReady=false,fault='';
let consumerExit:number|null=null,consumerSignal:string|null=null;
const events:any[]=[];const end=mono()+Math.min(280,remainingSeconds(contract));
function note(event:string,row:any={}){const r={event,remainingSeconds:Math.max(0,end-mono()),...row};events.push(r);assert.ok(events.length<=256);appendFileSync(OUT+'/controller.jsonl',JSON.stringify(r)+'\n');}
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
 assert.equal(process.env.APP_ORIGIN,ORIGIN);
 assert.equal(process.versions.node,'22.22.3');
 await writeFile(OUT+'/versions.json',JSON.stringify({node:process.versions.node,transport:'node:http',dependencyAdded:false}));
 for(let i=0;;i++){assert.ok(mono()<end,'STARTUP_DEADLINE');try{if((await fetch('http://127.0.0.1:3000/api/v1/health',{signal:AbortSignal.timeout(Math.max(1,Math.min(1000,Math.floor((end-mono())*1000))))})).ok)break;}catch{}assert.ok(i<150,'API_STARTUP');await sleep(100);}
 await startPassive(contract,{seed:async()=>{
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}},update:{value:{...defaults,enabledPlatforms:['tiktok'],analyzeTimeout:30,prepareTimeout:180,sweepSeconds:1}}});
 assert.equal(await db.adCampaign.count(),0);await mkdir(OUT+'/cases/source',{recursive:true});
 // Source delegate consumes active.json; no fixture mode or expectation is mounted.
 await writeFile(OUT+'/active.json',JSON.stringify({case:'source',mode:'source',url:TARGET,end,wallEnd:Date.now()+Math.max(1,(end-mono())*1000)}),{flag:'wx'});
 },startConsumer:async()=>{
 worker=spawn('/app/node_modules/.bin/tsx',['/lab/worker.ts'],{cwd:'/app',env:process.env,stdio:['ignore','pipe','pipe']});
 worker.once('close',(code,signal)=>{consumerExit=code;consumerSignal=signal;});
 let buffer='';worker.stdout!.on('data',b=>{buffer+=b;if(buffer.length>65536){fault='WORKER_OUTPUT_CAP';return;}let at;while((at=buffer.indexOf('\n'))>=0){workerLine(buffer.slice(0,at));buffer=buffer.slice(at+1);}});worker.stderr!.on('data',()=>{});
 const readyEnd=mono()+10;while(!workerReady){assert.ok(mono()<readyEnd&&worker.exitCode===null,'CONSUMER_START');await sleep(30);}

 },ready:async()=>{await writeFile(OUT+'/startup.ready','ready',{flag:'wx'});await writeFile(OUT+'/backend.ready',JSON.stringify(binding(contract)),{flag:'wx'});}});
}
async function finish(){
 const state=await read('browser-state.json');assert.ok(state.hasSession&&state.hasTicket&&!state.fault);jobID=state.jobID;assert.match(jobID,/^[a-f0-9-]{36}$/);
 const rows=(await readFile(OUT+'/worker.jsonl','utf8')).trim().split('\n').map(JSON.parse);
 for(const phase of ['analyze','prepare']){
  assert.ok(rows.some((r:any)=>r.event==='adapter_parent_closed'&&r.phase===phase&&r.actualExit===0&&r.actualSignal===null&&r.groupLive===0));
  assert.ok(rows.some((r:any)=>r.event==='proxy_phase_gate'&&r.phase===phase&&r.accepted===true));
  const d=await read('cases/source/'+phase+'.diagnostics.json');assert.equal(d.complete,true);assert.ok(Number.isInteger(d.metadataAttempts)&&d.metadataAttempts>=1&&d.metadataAttempts<=2);assert.equal(d.imageAttempts,phase==='prepare'?1:0);
  const native=await read('cases/source/'+phase+'.native.json');assert.equal(native.coreExit,0);
 }
 const p=await read('cases/source/prepare.diagnostics.json');assert.equal(p.operations.filter((r:any)=>r.operation==='FFPROBE'&&r.event==='END'&&r.returncode===0).length,2);assert.equal(p.operations.filter((r:any)=>r.operation==='DECODE'&&r.event==='END'&&r.returncode===0).length,1);
 const j=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{asset:true}});assert.equal(j.state,'ready');

 const publicJob=await db.downloadJob.findUniqueOrThrow({where:{id:jobID},include:{items:true}});
 const chosen=guard.verify(publicJob.items,publicJob.formatId||'');const selection=guard.selection,sent=await read('browser-selection.json');
 assert.deepEqual(sent,{itemId:selection!.itemId,formatId:selection!.formatId});assert.equal(publicJob.formatId,chosen.id);
 const accounting=phaseAccounting(await read('cases/source/analyze.diagnostics.json'),await read('cases/source/prepare.diagnostics.json'));
 await writeFile(OUT+'/source-accounting.json',JSON.stringify(accounting),{flag:'wx'});
 note('BROWSER_SELECTION_CONFIRMED',{index:contract.selectedIndex});
 const native=await read('cases/source/prepare.native.json');
 await writeFile(OUT+'/core-verified.json',JSON.stringify({jobID,size:Number(j.asset!.size),sha256:native.sha256}),{flag:'wx'});
 let before:number|undefined;
 while(!(await exists(OUT+'/gateway-result.json'))){
  assert.ok(mono()<end,'TRANSFER_DEADLINE');
  if(await exists(OUT+'/head-before.json')&&!await exists(OUT+'/head-before-ack.json')){before=await db.transferLease.count({where:{assetId:j.asset!.id}});await writeFile(OUT+'/head-before-ack.json',JSON.stringify({count:before}),{flag:'wx'});}
  if(await exists(OUT+'/head-after.json')&&!await exists(OUT+'/head-after-ack.json')){const after=await db.transferLease.count({where:{assetId:j.asset!.id}});assert.equal(after,before);await writeFile(OUT+'/head-after-ack.json',JSON.stringify({count:after,headLeaseUnchanged:true}),{flag:'wx'});}
  await sleep(30);
 }
 const g=await read('gateway-result.json');assert.equal(g.status,'PASS_GATEWAY_SOURCE');assert.equal(g.sha256,native.sha256);
 return {status:'PASS_UI_BACKEND_SOURCE_PENDING_CLEANUP',jobID,selectedIndex:contract.selectedIndex,size:g.size,sha256:g.sha256,browserSave:'UNKNOWN',sourceAccounting:accounting};
}
async function cleanup(){
 const limitMs=Math.max(0,Math.min(15000,remainingSeconds(contract,'cleanup')*1000));
 const receipt=await closePassive({job:async context=>{
 context.check();
 if(!jobID){const present=await exists(OUT+'/browser-state.json');context.check();if(present){const state=await read('browser-state.json');context.check();jobID=state.jobID;}}
 if(jobID){
  while(true){context.check();const j=await db.downloadJob.findUnique({where:{id:jobID}});context.check();const media=await exists('/media/'+jobID);context.check();if(j?.cancelRequested&&!j.workerToken&&!media)break;await context.sleep(80);}
  const j=await db.downloadJob.findUniqueOrThrow({where:{id:jobID}});context.check();assert.equal(j.cancelRequested,true);assert.equal(j.workerToken,null);const media=await exists('/media/'+jobID);context.check();assert.equal(media,false);
 }
 },consumer:async context=>{if(worker&&consumerExit===null)await stopConsumer(worker,context);
 context.check();if(worker){assert.equal(consumerExit,0);assert.equal(consumerSignal,null);}const leases=await db.transferLease.count({where:{state:'started'}});context.check();assert.equal(leases,0);
 },queue:()=>queue.close(),redis:()=>redis.disconnect(),db:()=>db.$disconnect()},{limitMs});
 note('CLEANUP_COMPLETE',{consumerExit,consumerSignal,hadJob:!!jobID,...receipt});assert.equal(receipt.cleanupOK,true);
}
async function main(){let result:any;
 try{
  await start();while(!await exists(OUT+'/browser-accepted')){
   if(!selectionPublished&&await exists(OUT+'/browser-state.json')){const state=await read('browser-state.json');if(state.jobID){const j=await db.downloadJob.findUniqueOrThrow({where:{id:state.jobID},include:{items:true}});if(j.state==='selectable'){const selection=guard.selectable(j);await writeFile(OUT+'/source-selection.json',JSON.stringify(selectionRecord(contract,selection)),{flag:'wx'});selectionPublished=true;}}}const primary=await exists(OUT+'/browser-state.json')?(await read('browser-state.json')).fault:'';const stop=waitReason('BROWSER_ACCEPTED',{primary,aborted:await exists(OUT+'/browser-abort'),now:mono(),end});if(stop)throw stop;await sleep(50);}
  result=await finish();
 }catch(e){result={status:'FAIL_STOPPED',...reasonRow(e,'')};process.exitCode=1;await writeFile(OUT+'/browser-abort','abort');}
 finally{try{await cleanup();if(result.status==='PASS_UI_BACKEND_SOURCE_PENDING_CLEANUP')result.status='PASS_UI_BACKEND_SOURCE';}catch{result={...result,status:'FAIL_CLEANUP_UNKNOWN'};process.exitCode=1;}await writeFile(OUT+'/result.json',JSON.stringify(result),{flag:'wx'});}
}
await main();
}
if(process.argv[1]?.endsWith('/controller.ts'))runSourceController().catch(()=>{process.exitCode=78;});
