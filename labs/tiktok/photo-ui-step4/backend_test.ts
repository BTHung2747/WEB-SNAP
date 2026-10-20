import assert from 'node:assert/strict';
import {randomUUID,createHash} from 'node:crypto';
import {readFile,writeFile,access} from 'node:fs/promises';
import {db,redis,queue,defaults} from '/app/packages/shared/src/core';
import {SessionService} from '/app/apps/api/src/services/session.service';
const base='http://127.0.0.1:3000/api/v1/',origin='http://photo-ui-fixture.invalid',url='https://www.tiktok.com/@fixture/photo/7000000000000000001';
const cases:any[]=[],sleep=(n:number)=>new Promise(r=>setTimeout(r,n));
async function request(c:any,path:string,body?:any,extra:any={}){const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{cookie:c.cookie,origin,'x-csrf-token':c.csrf,'content-type':'application/json',...extra},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(5000)});return {status:r.status,data:await r.json()};}
async function client(){const r=await fetch(base+'session');assert.equal(r.status,200);const d:any=await r.json();return {cookie:r.headers.get('set-cookie')!.split(';')[0],csrf:d.csrf,capabilities:d.capabilities};}
async function state(c:any,id:string,target:string){for(let i=0;i<250;i++){const r=await request(c,'jobs/'+id);if(r.data.state===target)return r.data;if(['failed','expired','cancelled'].includes(r.data.state))throw Error('UNEXPECTED_TERMINAL');await sleep(80);}throw Error('STATE_DEADLINE');}
async function absent(path:string){try{await access(path);return false;}catch{return true;}}
async function main(){
 assert.ok(process.env.DATABASE_URL?.endsWith('/photo_ui_fixture'));
 for(let i=0;i<100;i++){try{if((await fetch(base+'health')).ok)break;}catch{}await sleep(100);}
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['youtube','tiktok'],analyzeTimeout:20,prepareTimeout:40}},update:{value:{...defaults,enabledPlatforms:['youtube','tiktok'],analyzeTimeout:20,prepareTimeout:40}}});
 const c=await client(),other=await client();assert.equal(c.capabilities.tiktokPhoto,true);
 const doc:any=await (await fetch('http://127.0.0.1:3000/api/docs-json')).json();
 assert.equal(doc.components.schemas.SessionResponse.properties.capabilities.properties.tiktokPhoto.type,'boolean');
 assert.ok(doc.components.schemas.SessionResponse.required.includes('capabilities'));
 // Same production service, actual fixture DB session; mutate only this test process env.
 const saved={...process.env};const req:any={cookies:{ws_session:c.cookie.split('=')[1]}};
 for(const [key,value] of [['TIKTOK_PHOTO_ENABLED',undefined],['TIKTOK_PHOTO_ENABLED','false'],['TIKTOK_ADAPTER_ENABLED','0'],['VERIFIED_PLATFORMS','youtube'],['TIKTOK_EGRESS_POLICY_ENABLED','0'],['TIKTOK_EGRESS_CONTROL_SECRET','invalid']]){
  process.env={...saved};if(value===undefined)delete process.env[key!];else process.env[key!]=value;
  let out:any;await new SessionService().createSession(req,{json:(v:any)=>{out=v;}} as any);assert.deepEqual(out.capabilities,{tiktokPhoto:false});assert.ok(!('controlSecret' in out));
 }
 process.env={...saved};cases.push({case:'actual-session-route-true-service-six-false-configs-no-secret'});
 assert.equal((await request(c,'jobs/analyze',{url},{'x-csrf-token':'wrong'})).status,403);
 async function analyze(){const r=await request(c,'jobs/analyze',{url});assert.equal(r.status,202);return {id:r.data.jobId,j:await state(c,r.data.jobId,'selectable')};}
 const a=await analyze();assert.equal(a.j.items[0].kind,'photo');assert.equal(a.j.items[0].formats.length,5);
 assert.equal((await request(other,'jobs/'+a.id)).status,404);
 const selection={itemId:a.j.items[0].id,formatId:a.j.items[0].formats[1].id,idempotencyKey:randomUUID()};
 assert.equal((await request(c,'jobs/'+a.id+'/prepare',{...selection,formatId:'tampered'})).status,400);
 assert.equal((await request(c,'jobs/'+a.id+'/prepare',selection)).status,202);await state(c,a.id,'ready');
 assert.equal((await request(c,'jobs/'+a.id+'/prepare',selection)).status,202);
 assert.equal((await request(c,'jobs/'+a.id+'/prepare',{...selection,formatId:a.j.items[0].formats[0].id})).status,409);
 const row=await db.downloadJob.findUniqueOrThrow({where:{id:a.id},include:{asset:true}});assert.equal(row.asset!.state,'available');assert.equal(row.formatId,selection.formatId);assert.equal(row.workerToken,null);
 const file=await readFile('/media/'+a.id+'/image.jpg');assert.deepEqual(file,await readFile('/control/input.jpg'));
 const counts=JSON.parse(await readFile('/control/counts.json','utf8'));assert.equal(counts.metadata,4);assert.equal(counts.JPEG,1);
 const ticket=await request(c,'jobs/'+a.id+'/download-ticket',{});assert.equal(ticket.status,201);
 const download='http://127.0.0.1:3000'+ticket.data.url,headers={cookie:c.cookie};
 const leasesBefore=await db.transferLease.count({where:{assetId:row.asset!.id}});
 const head=await fetch(download,{method:'HEAD',headers});assert.equal(head.status,200);assert.equal(head.headers.get('content-type'),'image/jpeg');assert.equal(head.headers.get('content-disposition'),'attachment; filename="wed-snap-image.jpg"');assert.equal(await db.transferLease.count({where:{assetId:row.asset!.id}}),leasesBefore);
 for(const range of [undefined,'bytes=0-99']){const r=await fetch(download,{headers:{...headers,...(range?{range}:{})}});assert.equal(r.status,range?206:200);assert.equal(r.headers.get('content-type'),'image/jpeg');assert.deepEqual(Buffer.from(await r.arrayBuffer()),range?file.subarray(0,100):file);}
 await writeFile('/control/prepared-image.jpg',file);cases.push({case:'actual-API-BullMQ-worker-phasegate-TLS-image2-ready-native-HEAD-GET-Range',jobId:a.id,formatId:selection.formatId,metadataGET:4,JPEGGET:1,size:file.length,sha256:createHash('sha256').update(file).digest('hex')});
 await writeFile('/control/mode.json',JSON.stringify({mode:'happy'}));const b=await analyze();await writeFile('/control/mode.json',JSON.stringify({mode:'late-CDN'}));
 const s={itemId:b.j.items[0].id,formatId:b.j.items[0].formats[0].id,idempotencyKey:randomUUID()};assert.equal((await request(c,'jobs/'+b.id+'/prepare',s)).status,202);
 await state(c,b.id,'failed');const failed=await db.downloadJob.findUniqueOrThrow({where:{id:b.id},include:{asset:true}});assert.notEqual(failed.asset?.state,'available');assert.equal(await absent('/media/'+b.id),true);
 assert.ok((await request(c,'jobs/'+b.id+'/download-ticket',{})).status>=400);cases.push({case:'actual-API-queue-late-CDN-gate-false-not-ready-no-ticket-cleanup',jobId:b.id});
 await writeFile('/control/backend-result.json',JSON.stringify({status:'PASS_BACKEND_OFFLINE_API_BULLMQ_PROXY_TLS',sourceCalls:0,apiServerRun:true,bullmqConsumerRun:true,browserBackendCombined:false,cases},null,2));
 console.log('PASS backend smoke',cases.length);
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async(e)=>{await writeFile('/control/failure.json',JSON.stringify({class:e?.constructor?.name,operator:e?.operator,code:e?.code,frames:String(e.stack||'').split('\n').filter((s:string)=>/^\s+at /.test(s)).slice(0,5)}));console.error('BACKEND_SMOKE_FAILED');await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;});
