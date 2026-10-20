import assert from 'node:assert/strict';
import { randomUUID,createHash } from 'node:crypto';
import { readFile,writeFile,mkdir,access } from 'node:fs/promises';
import { after,db,redis,queue,defaults } from '/app/packages/shared/src/core';
const ORIGIN='http://tiktok-app-fixture.invalid',BASE='http://127.0.0.1:3000/api/v1/';
assert.equal(process.env.APP_ORIGIN,ORIGIN);
assert.ok(process.env.DATABASE_URL?.endsWith('/tiktok_app_fixture'));
assert.equal(process.env.REDIS_URL,'redis://redis:6379/7');
const sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms)),outcomes:any[]=[];
async function request(c:any,path:string,body?:any,override?:any){
 const r=await fetch(BASE+path,{method:body===undefined?'GET':'POST',
 headers:{cookie:c.cookie,origin:ORIGIN,'x-csrf-token':c.csrf,'content-type':'application/json',...override},
 body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(5000)});
 return {status:r.status,data:await r.json()};
}
async function client(){
 const r=await fetch(BASE+'session');const d:any=await r.json();
 return {cookie:r.headers.get('set-cookie')!.split(';')[0],csrf:d.csrf};
}
async function state(c:any,id:string,wanted:string){
 const end=Date.now()+30000;
 while(Date.now()<end){
  const r=await request(c,'jobs/'+id);
  if(r.data.state===wanted)return r.data;
  if(['failed','expired','cancelled'].includes(r.data.state)&&r.data.state!==wanted)throw new Error('Fixture unexpected terminal '+r.data.state);
  await sleep(100);
 }
 throw new Error('Fixture wait timeout '+wanted);
}
async function events(id:string){try{return (await readFile('/control/'+id+'/events.jsonl','utf8')).trim().split('\n').map(s=>JSON.parse(s));}catch{return [];}}
async function config(id:string,mode:string){await mkdir('/control/'+id,{recursive:true});await writeFile('/control/'+id+'/mode.json',JSON.stringify({mode}));}
async function analyze(c:any){
 const r=await request(c,'jobs/analyze',{url:'https://www.tiktok.com/@fixture/video/7692288554839313682'});
 assert.equal(r.status,202);return {id:r.data.jobId,j:await state(c,r.data.jobId,'selectable')};
}
async function prepare(c:any,id:string,j:any){
 const selection={itemId:j.items[0].id,formatId:j.items[0].formats[0].id,idempotencyKey:randomUUID()};
 assert.equal((await request(c,'jobs/'+id+'/prepare',selection)).status,202);return selection;
}
async function absent(path:string){try{await access(path);return false;}catch{return true;}}
async function main(){
 let healthy=false;
 for(let i=0;i<100;i++){try{if((await fetch(BASE+'health')).ok){healthy=true;break;}}catch{}await sleep(100);}
 assert.ok(healthy);
 const limits={...defaults,enabledPlatforms:['youtube','tiktok'],sessionTtl:120,analyzeTimeout:10,prepareTimeout:40,sweepSeconds:1};
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:limits},update:{value:limits}});
 const c=await client(),other=await client();
 assert.equal((await request(c,'jobs/analyze',{url:'https://www.tiktok.com/@fixture/video/7692288554839313682'},{'x-csrf-token':'invalid'})).status,403);
 outcomes.push({case:'CSRF',status:403});
 const {id,j}=await analyze(c);
 assert.ok(j.items[0].formats[0].id.startsWith('tt1_'));assert.equal(await absent('/media/'+id+'/media.mp4'),true);
 const analyzePid=(await events(id)).find(e=>e.event==='child_begin')!.pid;
 assert.equal(await absent('/proc/'+analyzePid),true,'Analyze exited before selectable');
 assert.equal((await request(other,'jobs/'+id)).status,404);
 const selection=await prepare(c,id,j);await state(c,id,'ready');
 assert.equal((await request(c,'jobs/'+id+'/prepare',selection)).status,202);
 const all=await events(id),begins=all.filter(e=>e.event==='child_begin');
 assert.equal(begins.length,2);assert.notEqual(begins[0].pid,begins[1].pid);assert.ok(begins.every(e=>e.pgid===e.pid));
 assert.equal(all.filter(e=>e.event==='metadata_GET').length,4);assert.equal(all.filter(e=>e.event==='MP4_GET').length,1);
 const job=await db.downloadJob.findUniqueOrThrow({where:{id},include:{items:true,asset:true}});
 assert.equal(job.sourceUrl,null);assert.equal(job.workerToken,null);assert.equal(job.asset!.path,id+'/media.mp4');
 assert.ok(!/FAKE|token=|https:/.test(JSON.stringify({title:job.title,formats:job.items[0].formats})));
 const ticket=await request(c,'jobs/'+id+'/download-ticket',{});assert.equal(ticket.status,201);
 const file=await readFile('/media/'+id+'/media.mp4'),input=await readFile('/control/input.mp4');
 assert.equal(createHash('sha256').update(file).digest('hex'),createHash('sha256').update(input).digest('hex'));
 const full=await fetch('http://127.0.0.1:3000'+ticket.data.url,{headers:{cookie:c.cookie},signal:AbortSignal.timeout(5000)});
 assert.equal(full.status,200);assert.equal((await full.arrayBuffer()).byteLength,file.length);
 const range=await fetch('http://127.0.0.1:3000'+ticket.data.url,{headers:{cookie:c.cookie,range:'bytes=0-99'},signal:AbortSignal.timeout(5000)});
 assert.equal(range.status,206);assert.equal((await range.arrayBuffer()).byteLength,100);
 assert.equal((await fetch('http://127.0.0.1:3000'+ticket.data.url,{headers:{cookie:other.cookie}})).status,410);
 await sleep(100);const leases=await db.transferLease.findMany({where:{assetId:job.asset!.id}});
 assert.equal(leases.length,2);assert.ok(leases.every(l=>l.state==='server_finished'));
 outcomes.push({case:'two-child-native-full-Range-lease',metadataGET:4,MP4GET:1,distinctChildren:true,bytes:file.length,leases:2});
 const cc=await client(),changed=await analyze(cc);await config(changed.id,'format-change');await prepare(cc,changed.id,changed.j);
 assert.equal((await state(cc,changed.id,'failed')).errorCode,'FORMAT_UNAVAILABLE');
 assert.equal((await events(changed.id)).filter(e=>e.event==='MP4_GET').length,0);
 outcomes.push({case:'fresh-format-changed-no-fallback'});
 for(const mode of ['cancel','expired','deadline']){
  const ac=await client(),x=await analyze(ac);await config(x.id,'hang');
  if(mode==='deadline')await db.settings.update({where:{id:'main'},data:{value:{...limits,prepareTimeout:10}}});
  await prepare(ac,x.id,x.j);
  for(let i=0;i<100;i++){if((await events(x.id)).some(e=>e.event==='helper_started'))break;await sleep(100);}
  const started=(await events(x.id)).find(e=>e.event==='helper_started');assert.ok(started);
  if(mode==='cancel')assert.equal((await request(ac,'jobs/'+x.id+'/cancel',{})).status,201);
  if(mode==='expired')await db.downloadJob.update({where:{id:x.id},data:{ownerUntil:after(-1)}});
  await state(ac,x.id,mode==='cancel'?'cancelled':mode==='expired'?'expired':'failed');
  for(let i=0;i<100;i++){const v=await db.downloadJob.findUniqueOrThrow({where:{id:x.id}});if(!v.workerToken&&await absent('/media/'+x.id))break;await sleep(100);}
  const v=await db.downloadJob.findUniqueOrThrow({where:{id:x.id}});
  assert.equal(v.workerToken,null);assert.equal(v.processUntil,null);assert.equal(await absent('/media/'+x.id),true);
  const live=async(pid:number)=>{try{const s=await readFile('/proc/'+pid+'/stat','utf8');return !['Z','X'].includes(s.split(') ')[1].split(' ')[0]);}catch{return false;}};
  assert.equal(await live(started.pid),false);assert.equal(await live(started.helperPid),false);
  outcomes.push({case:mode+'-ProcessGroup-child-helper-cleanup',state:v.state,error:v.errorCode,groupLive:0});
 }
 await writeFile('/control/api-result.json',JSON.stringify({status:'PASS',sourceCalls:0,environment:'own fixture API/worker/DB/Redis',outcomes},null,2));
 console.log('PASS API/worker fixture separate phases/fresh metadata/CSRF/ownership/native full-Range leases/cancel-expired-deadline processgroup cleanup; no source');
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async()=>{console.error('FIXTURE_API_TEST_FAILED');await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;});
