import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { after, db, redis, queue, defaults } from '/app/packages/shared/src/core';
import { photoPostId, requirePhotoEnabled, checkedPhotoMetadata, checkedPhotoFormats, checkedPhotoFile, selectedPhoto, assetDescriptor, photoLimits } from '/app/packages/shared/src/tiktok-photo';
import { processJob } from '/app/apps/worker/src/processor';
import { runAdapter } from '/app/apps/worker/src/adapter';
import { sweep } from '/app/apps/worker/src/lifecycle';
import { ProcessGroup } from '/app/apps/worker/src/process-group';
import { liveProcesses } from '/app/apps/worker/src/process-registry';
const ORIGIN='http://photo-step2-fixture.invalid', BASE='http://127.0.0.1:3000/api/v1/';
const URL='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const sleep=(n:number)=>new Promise(r=>setTimeout(r,n)),cases:any[]=[];
const baseLimits={...defaults,enabledPlatforms:['youtube','tiktok'],sessionTtl:120,prepareTimeout:40,sweepSeconds:30};
async function settings(extra:any={}){const value={...baseLimits,...extra};await db.settings.upsert({where:{id:'main'},create:{id:'main',value},update:{value}});}
async function request(c:any,path:string,body?:any,headers:any={}){
 const r=await fetch(BASE+path,{method:body===undefined?'GET':'POST',headers:{cookie:c.cookie,origin:ORIGIN,'x-csrf-token':c.csrf,'content-type':'application/json',...headers},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(5000)});
 return {status:r.status,data:await r.json()};
}
async function client(){const r=await fetch(BASE+'session');const d:any=await r.json();return {cookie:r.headers.get('set-cookie')!.split(';')[0],csrf:d.csrf};}
async function state(c:any,id:string,wanted:string){
 for(let i=0;i<400;i++){const r=await request(c,'jobs/'+id);if(r.data.state===wanted)return r.data;
  if(['failed','expired','cancelled'].includes(r.data.state)&&r.data.state!==wanted)throw new Error('Unexpected terminal '+r.data.state+':'+r.data.errorCode);await sleep(100);}
 throw new Error('State timeout '+wanted);
}
async function events(id:string){try{return (await readFile('/control/'+id+'/events.jsonl','utf8')).trim().split('\n').map(s=>JSON.parse(s));}catch{return [];}}
async function config(id:string,mode:string){await mkdir('/control/'+id,{recursive:true});await writeFile('/control/'+id+'/mode.json',JSON.stringify({mode}));}
async function analyze(c:any){const r=await request(c,'jobs/analyze',{url:URL});assert.equal(r.status,202,JSON.stringify(r));return {id:r.data.jobId,j:await state(c,r.data.jobId,'selectable')};}
const selection=(j:any,index=1)=>({itemId:j.items[0].id,formatId:j.items[0].formats[index].id,idempotencyKey:randomUUID()});
async function prepared(c:any,x:any,mode='normal'){
 await config(x.id,mode);const s=selection(x.j);const r=await request(c,'jobs/'+x.id+'/prepare',s);assert.equal(r.status,202,JSON.stringify(r));return s;
}
async function absent(path:string){try{await access(path);return false;}catch{return true;}}
async function clean(id:string){for(let i=0;i<100;i++){const j=await db.downloadJob.findUniqueOrThrow({where:{id}});if(!j.workerToken&&await absent('/media/'+id))return j;await sleep(100);}throw new Error('Cleanup timeout');}
function rejects(fn:()=>unknown){assert.throws(fn);}
async function main(){
 assert.ok(process.env.DATABASE_URL?.endsWith('/tiktok_photo_step2'));assert.equal(process.env.APP_ORIGIN,ORIGIN);
 for(let i=0;i<100;i++){try{if((await fetch(BASE+'health')).ok)break;}catch{}await sleep(100);}
 await settings();const c=await client(),other=await client();
 // Dynamic function gates, plus API and worker gates against a real lab DB below.
 const original={photo:process.env.TIKTOK_PHOTO_ENABLED,adapter:process.env.TIKTOK_ADAPTER_ENABLED,verified:process.env.VERIFIED_PLATFORMS};
 for(const value of [undefined,'0','true']){if(value===undefined)delete process.env.TIKTOK_PHOTO_ENABLED;else process.env.TIKTOK_PHOTO_ENABLED=value;rejects(()=>requirePhotoEnabled(['tiktok']));}
 process.env.TIKTOK_PHOTO_ENABLED='1';process.env.TIKTOK_ADAPTER_ENABLED='0';rejects(()=>requirePhotoEnabled(['tiktok']));process.env.TIKTOK_ADAPTER_ENABLED='1';process.env.VERIFIED_PLATFORMS='youtube';rejects(()=>requirePhotoEnabled(['tiktok']));
 process.env.VERIFIED_PLATFORMS=original.verified;requirePhotoEnabled(['tiktok']);rejects(()=>requirePhotoEnabled(['youtube']));
 rejects(()=>photoPostId(URL+'?secret=x'));rejects(()=>photoPostId(URL+'#x'));assert.equal(photoPostId(URL),'7000000000000000001');
 assert.equal(photoLimits(baseLimits).maxBytes,16*1024*1024);assert.equal(photoLimits({...baseLimits,maxBytes:1024}).maxBytes,1024);
 cases.push({case:'public-flags-url-and-limit-glue',sourceCalls:0});
 assert.equal((await request(c,'jobs/analyze',{url:URL},{'x-csrf-token':'wrong'})).status,403);
 const x=await analyze(c);assert.equal(x.j.items[0].kind,'photo');assert.equal(x.j.duration,null);assert.equal(x.j.previewUrl,null);
 assert.equal((await request(other,'jobs/'+x.id)).status,404);
 assert.equal((await request(other,'jobs/'+x.id+'/prepare',selection(x.j))).status,404);
 assert.equal((await request(c,'jobs/'+x.id+'/prepare',{...selection(x.j),url:'https://fake.invalid/'})).status,400);
 const rows=x.j.items[0].formats;checkedPhotoFormats(rows);
 const summary={version:'tt-photo-album-v1',id:rows[0].contentId,type:'photo',imageCount:rows.length,images:rows.map(({index,width,height,itemKey}:any)=>({index,width,height,itemKey})),snapshotKey:rows[0].snapshotKey};
 const packet={kind:'photo',title:'Album TikTok',duration:null,summary,formats:rows};checkedPhotoMetadata(packet,summary.id);
 for(const bad of [{...packet,url:'https://fake.invalid/'},{...packet,duration:0},{...packet,kind:'video'},{...packet,summary:{...summary,id:'7000000000000000002'}}])rejects(()=>checkedPhotoMetadata(bad,summary.id));
 for(const mutate of [(r:any)=>r[0].index=2,(r:any)=>r[0].contentId='7000000000000000002',(r:any)=>r[0].width=32,(r:any)=>r[0].url='https://fake.invalid/',(r:any)=>r[0].snapshotKey='0'.repeat(64),(r:any)=>r[0].imageCount=3]){const r=structuredClone(rows);mutate(r);rejects(()=>checkedPhotoFormats(r));}
 rejects(()=>assetDescriptor(x.id,[{kind:'unknown',formats:rows}],{path:x.id+'/image.jpg'},rows[1].id));
 const s=await prepared(c,x);await state(c,x.id,'ready');
 assert.equal((await request(c,'jobs/'+x.id+'/prepare',s)).status,202);
 assert.equal((await request(c,'jobs/'+x.id+'/prepare',{...s,formatId:rows[0].id})).status,409);
 const job=await db.downloadJob.findUniqueOrThrow({where:{id:x.id},include:{items:true,asset:true}});
 assert.equal(job.sourceUrl,null);assert.equal(job.asset!.path,x.id+'/image.jpg');assert.equal(job.workerToken,null);
 const log=await events(x.id),begins=log.filter(e=>e.event==='child_begin');assert.equal(begins.length,2);assert.notEqual(begins[0].pid,begins[1].pid);assert.ok(begins.every(e=>e.pid===e.pgid));
 assert.equal(log.filter(e=>e.event==='metadata_GET').length,4);assert.equal(log.filter(e=>e.event==='JPEG_GET').length,1);
 assert.equal(log.filter(e=>e.event==='session_final').length,2);assert.ok(log.filter(e=>e.event==='session_final').every(e=>e.cookiesRemaining===0&&e.responsesClosed));
 assert.ok(begins.every(e=>+e.maxInput===36*1024*1024&&+e.maxOutput===16*1024*1024));
 assert.ok(!/FAKE|https:|cookie|token=/i.test(JSON.stringify(job.items[0].formats)));
 assert.equal(await absent('/proc/'+begins[0].pid),true);assert.equal(await absent('/proc/'+begins[1].pid),true);
 const file=await readFile('/media/'+x.id+'/image.jpg'),input=await readFile('/control/input.jpg');assert.deepEqual(file,input);
 const sha=createHash('sha256').update(file).digest('hex');
 const ticket=await request(c,'jobs/'+x.id+'/download-ticket',{});assert.equal(ticket.status,201);const download='http://127.0.0.1:3000'+ticket.data.url;
 const before=await db.transferLease.count({where:{assetId:job.asset!.id}});
 for(const range of [undefined,'bytes=0-99']){
  const r=await fetch(download,{method:'HEAD',headers:{cookie:c.cookie,...(range?{range}:{})}});assert.equal(r.status,range?206:200);assert.equal(r.headers.get('content-type'),'image/jpeg');assert.equal(r.headers.get('content-disposition'),'attachment; filename="wed-snap-image.jpg"');assert.equal(+r.headers.get('content-length')!,range?100:file.length);
 }
 assert.equal(await db.transferLease.count({where:{assetId:job.asset!.id}}),before);
 for(const range of [undefined,'bytes=0-99','bytes=-20']){
  const r=await fetch(download,{headers:{cookie:c.cookie,...(range?{range}:{})}});assert.equal(r.status,range?206:200);assert.equal(r.headers.get('content-type'),'image/jpeg');const b=Buffer.from(await r.arrayBuffer());assert.deepEqual(b,range==='bytes=0-99'?file.subarray(0,100):range?file.subarray(file.length-20):file);
 }
 assert.equal((await fetch(download,{headers:{cookie:other.cookie}})).status,410);
 assert.equal((await fetch(download,{headers:{cookie:c.cookie,range:'bytes=999999999-'}})).status,416);
 await sleep(100);const leases=await db.transferLease.findMany({where:{assetId:job.asset!.id}});assert.equal(leases.length,3);assert.ok(leases.every(v=>v.state==='server_finished'));
 cases.push({case:'real-CLI-worker-API-image2-two-child-fresh-JPEG-HEAD-GET-Range-lease',metadataGET:4,JPEGGET:1,sha256:sha,size:file.length,leases:3,headLeases:0});
 // Fail closed on stored kind/path mismatch even for HEAD, restore only lab data.
 await db.temporaryAsset.update({where:{jobId:x.id},data:{path:x.id+'/media.mp4'}});
 assert.ok((await fetch(download,{method:'HEAD',headers:{cookie:c.cookie}})).status>=400);
 await db.temporaryAsset.update({where:{jobId:x.id},data:{path:x.id+'/image.jpg'}});
 // Active transfer lease is retained by the actual sweeper despite expired/cancelled job.
 const lease=await db.transferLease.create({data:{assetId:job.asset!.id,expiresAt:after(60),reserved:0n,month:new Date().toISOString().slice(0,7)}});
 await db.downloadJob.update({where:{id:x.id},data:{cancelRequested:true,state:'cancelled'}});await sweep();assert.equal(await absent('/media/'+x.id+'/image.jpg'),false);
 await db.transferLease.update({where:{id:lease.id},data:{state:'disconnected',expiresAt:after(-1)}});await sweep();assert.equal(await absent('/media/'+x.id),true);
 cases.push({case:'stored-path-fail-closed-and-active-lease-preserved'});
 // Two clients suffice; analyze session/IP quotas remain real. No Redis reset.
 for(const mode of ['wrong-body','dimension-change','count-change','wrong-mime','false-jpeg','packet-path','packet-size','packet-contract','packet-secret','packet-kind']){
  const clientForCase=mode.startsWith('packet')?other:c;const q=await analyze(clientForCase);await prepared(clientForCase,q,mode);const failed=await state(clientForCase,q.id,'failed');await clean(q.id);
  if(['wrong-body','dimension-change','count-change'].includes(mode))assert.equal((await events(q.id)).filter(e=>e.event==='JPEG_GET').length,0);
  cases.push({case:mode,errorCode:failed.errorCode,outputAbsent:true});
 }
 // TTL does not renew on heartbeat; descriptor tamper rejected before queue/GET.
 const stale=await analyze(other);await db.downloadJob.update({where:{id:stale.id},data:{metadataAcceptedAt:after(-130),metadataExpiresAt:after(-1)}});
 assert.equal((await request(other,'jobs/'+stale.id+'/heartbeat',{})).status,410);assert.equal((await request(other,'jobs/'+stale.id+'/prepare',selection(stale.j))).status,410);
 const tampered=await analyze(other);const broken=structuredClone(tampered.j.items[0].formats);broken[0].itemKey='0'.repeat(64);
 await db.mediaItem.update({where:{id:tampered.j.items[0].id},data:{formats:broken}});assert.equal((await request(other,'jobs/'+tampered.id+'/prepare',selection(tampered.j))).status,400);
 assert.equal((await events(tampered.id)).filter(e=>e.event==='JPEG_GET').length,0);
 cases.push({case:'stale-heartbeat-no-renew-stored-tamper-no-queue'});
 // Worker/parent gates read flags again; no subprocess created.
 process.env.TIKTOK_PHOTO_ENABLED='0';const queuedId=randomUUID();const sessionId=job.sessionId;
 await db.downloadJob.create({data:{id:queuedId,sessionId,platform:'tiktok',sourceUrl:URL,ownerUntil:after(120)}});
 await processJob({name:'analyze',data:{id:queuedId}});assert.equal((await db.downloadJob.findUniqueOrThrow({where:{id:queuedId}})).errorCode,'UNSUPPORTED_PLATFORM');
 await assert.rejects(runAdapter(randomUUID(),'analyze',URL,null,{...baseLimits},'fixture-token'));
 assert.equal((await events(queuedId)).length,0);process.env.TIKTOK_PHOTO_ENABLED='1';cases.push({case:'queued-worker-and-parent-flag-recheck-no-child'});
 // Fault injection at CLI result boundary still uses the real core first.
 for(const mode of ['analyze-pass-exit20','analyze-pass-hang']){
  const id=randomUUID();await config(id,mode);await db.downloadJob.create({data:{id,sessionId,platform:'tiktok',sourceUrl:URL,ownerUntil:after(120)}});
  await settings({analyzeTimeout:5});await processJob({name:'analyze',data:{id}});assert.equal((await db.downloadJob.findUniqueOrThrow({where:{id}})).state,'failed');assert.equal(await absent('/media/'+id),true);cases.push({case:mode,rejected:true});
  assert.ok((await events(id)).some(e=>e.event==='child_result'&&e.actualCoreExit===0));
  assert.ok((await events(id)).some(e=>e.event===(mode.endsWith('exit20')?'injected_exit20':'packet_pass_hang')));
 }
 await settings();
 // Actual parent quarantine branch with a controlled public group-observer fault.
 const quarantined=randomUUID();await db.downloadJob.create({data:{id:quarantined,sessionId,platform:'tiktok',sourceUrl:URL,ownerUntil:after(120)}});
 await processJob({name:'analyze',data:{id:quarantined}});
 const qi=await db.mediaItem.findFirstOrThrow({where:{jobId:quarantined}}),qf=(qi.formats as any[])[1].id;
 await db.downloadJob.update({where:{id:quarantined},data:{state:'queued',formatId:qf,prepareKey:randomUUID()}});
 const originalMembers=ProcessGroup.prototype.members;
 try{ProcessGroup.prototype.members=function(){throw new Error('OFFLINE_OBSERVER_UNCONFIRMED');};await processJob({name:'prepare',data:{id:quarantined}});}
 finally{ProcessGroup.prototype.members=originalMembers;}
 const qj=await db.downloadJob.findUniqueOrThrow({where:{id:quarantined}});assert.ok(qj.workerToken&&liveProcesses.has(qj.workerToken));assert.equal(await absent('/media/'+quarantined+'/image.jpg'),false);
 // Physical children really exited before releasing the synthetic uncertainty.
 const qe=await events(quarantined);for(const e of qe.filter(e=>e.event==='child_begin'))assert.equal(await absent('/proc/'+e.pid),true);
 liveProcesses.delete(qj.workerToken!);await db.downloadJob.update({where:{id:quarantined},data:{processUntil:after(-1)}});await sweep();assert.equal(await absent('/media/'+quarantined),true);
 cases.push({case:'observer-fault-quarantine-retains-token-and-file-until-closure-confirmed',faultInjection:true,afterConfirmedCleanup:true});
 // A stricter app cap still wins over photo defaults, through the real downloader.
 const capId=randomUUID();await db.downloadJob.create({data:{id:capId,sessionId,platform:'tiktok',sourceUrl:URL,ownerUntil:after(120)}});await processJob({name:'analyze',data:{id:capId}});
 const ci=await db.mediaItem.findFirstOrThrow({where:{jobId:capId}});await db.downloadJob.update({where:{id:capId},data:{state:'queued',formatId:(ci.formats as any[])[1].id,prepareKey:randomUUID()}});
 await config(capId,'large-jpeg');await settings({maxBytes:1024});await processJob({name:'prepare',data:{id:capId}});assert.equal((await clean(capId)).errorCode,'LIMIT_EXCEEDED');await settings();
 cases.push({case:'app-lower-output-cap-real-large-JPEG-read-rejection',maxBytes:1024});
 for(const mode of ['prepare-pass-exit20','prepare-pass-hang','cancel','expired','deadline']){
  const q=await analyze(mode.startsWith('prepare-')?c:other);await settings({prepareTimeout:mode.startsWith('prepare-')?40:12});await config(q.id,mode.startsWith('prepare-')?mode:'hang');
  const sel=selection(q.j);await db.downloadJob.update({where:{id:q.id},data:{state:'queued',formatId:sel.formatId,prepareKey:sel.idempotencyKey}});
  const running=processJob({name:'prepare',data:{id:q.id}});
  if(mode==='cancel'||mode==='expired'){
   for(let i=0;i<160;i++){if((await events(q.id)).some(e=>e.event==='helper_started'))break;await sleep(100);}
   assert.ok((await events(q.id)).some(e=>e.event==='helper_started'));
   if(mode==='cancel')await request(other,'jobs/'+q.id+'/cancel',{});else await db.downloadJob.update({where:{id:q.id},data:{ownerUntil:after(-1)}});
  }
  await running;const result=await clean(q.id);assert.ok(['failed','cancelled','expired'].includes(result.state));
  const ev=await events(q.id);for(const e of ev.filter(v=>v.event==='child_begin'||v.event==='helper_started')){
   for(const pid of [e.pid,e.helperPid].filter(Boolean)){try{const s=await readFile('/proc/'+pid+'/stat','utf8');assert.ok(['Z','X'].includes(s.split(') ')[1].split(' ')[0]));}catch(error:any){if(error.code!=='ENOENT')throw error;}}
  }
  if(mode.startsWith('prepare-')){
   assert.ok(ev.some(e=>e.event==='child_result'&&e.phase==='prepare'&&e.actualCoreExit===0));
   assert.ok(ev.some(e=>e.event===(mode.endsWith('exit20')?'injected_exit20':'packet_pass_hang')));
  }
  cases.push({case:mode,error:result.errorCode,workerToken:result.workerToken,groupLive:0,outputAbsent:true});await settings();
 }
 const regression=await client();
 for(const url of ['https://www.tiktok.com/@fixture/video/7692288554839313682','https://www.youtube.com/watch?v=abcdefghijk']){
  const a=await request(regression,'jobs/analyze',{url});assert.equal(a.status,202);const meta=await state(regression,a.data.jobId,'selectable');assert.equal(meta.items[0].kind,'video');
  const sel={itemId:meta.items[0].id,formatId:meta.items[0].formats[0].id,idempotencyKey:randomUUID()};assert.equal((await request(regression,'jobs/'+a.data.jobId+'/prepare',sel)).status,202);await state(regression,a.data.jobId,'ready');
  const t=await request(regression,'jobs/'+a.data.jobId+'/download-ticket',{});const r=await fetch('http://127.0.0.1:3000'+t.data.url,{headers:{cookie:regression.cookie,range:'bytes=0-99'}});assert.equal(r.status,206);assert.equal(r.headers.get('content-type'),'video/mp4');assert.equal(r.headers.get('content-disposition'),'attachment; filename="wed-snap-video.mp4"');assert.equal((await r.arrayBuffer()).byteLength,100);
  cases.push({case:url.includes('youtube')?'YouTube-legacy-fixture-regression':'TikTok-video-fixture-regression',kind:'video',rangeStatus:206});
 }
 await writeFile('/control/api-result.json',JSON.stringify({status:'PASS_OFFLINE_APP_FIXTURE',sourceCalls:0,cases},null,2));console.log('PASS offline app fixture',cases.length,'cases');
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async(e)=>{
 await writeFile('/control/test-failure.json',JSON.stringify({class:e?.constructor?.name,code:e?.code,assertion:e?.operator,stackLines:String(e?.stack||'').split('\n').filter((l:string)=>/^\s+at /.test(l)).slice(0,5)},null,2));
 console.error('PHOTO_STEP2_TEST_FAILED');await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;
});
