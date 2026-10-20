// Narrow supplementary integration probe: a different image requires a new job.
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { readFile, writeFile, copyFile } from 'node:fs/promises';
import { db,redis,queue,defaults } from '/app/packages/shared/src/core';
const base='http://127.0.0.1:3000/api/v1/',origin='http://photo-step2-fixture.invalid';
const sleep=(ms:number)=>new Promise(r=>setTimeout(r,ms));
async function main(){
 for(let i=0;i<100;i++){try{if((await fetch(base+'health')).ok)break;}catch{}await sleep(100);}
 await db.settings.update({where:{id:'main'},data:{value:{...defaults,enabledPlatforms:['youtube','tiktok'],prepareTimeout:40}}});
 const s=await fetch(base+'session');const data:any=await s.json();const cookie=s.headers.get('set-cookie')!.split(';')[0];
 async function request(path:string,body?:any){const r=await fetch(base+path,{method:body===undefined?'GET':'POST',headers:{cookie,origin,'x-csrf-token':data.csrf,'content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});return {status:r.status,data:await r.json()};}
 async function state(id:string,wanted:string){for(let i=0;i<200;i++){const r=await request('jobs/'+id);if(r.data.state===wanted)return r.data;assert.ok(!['failed','expired'].includes(r.data.state));await sleep(100);}throw Error('Timeout');}
 const outcomes:any[]=[];let previous:any;
 for(const index of [0,1]){
  const a=await request('jobs/analyze',{url:'https://www.tiktok.com/@fixture/photo/7000000000000000001'});assert.equal(a.status,202);const id=a.data.jobId,meta=await state(id,'selectable');
  const pick={itemId:meta.items[0].id,formatId:meta.items[0].formats[index].id,idempotencyKey:randomUUID()};assert.equal((await request('jobs/'+id+'/prepare',pick)).status,202);await state(id,'ready');
  const job=await db.downloadJob.findUniqueOrThrow({where:{id},include:{asset:true}});assert.equal(job.formatId,pick.formatId);assert.equal(job.asset!.path,id+'/image.jpg');
  const ticket=await request('jobs/'+id+'/download-ticket',{});const response=await fetch('http://127.0.0.1:3000'+ticket.data.url,{headers:{cookie}});assert.equal(response.status,200);assert.equal(response.headers.get('content-type'),'image/jpeg');
  const bytes=Buffer.from(await response.arrayBuffer());assert.deepEqual(bytes,await readFile('/control/input.jpg'));await writeFile('/control/prepared-image-'+(index+1)+'.jpg',bytes);
  await copyFile('/media/'+id+'/tiktok-operations.jsonl','/control/prepared-operations-'+(index+1)+'.jsonl');
  if(previous){assert.notEqual(id,previous.id);assert.notEqual(pick.formatId,previous.formatId);assert.equal((await request('jobs/'+previous.id+'/prepare',{itemId:previous.itemId,idempotencyKey:previous.idempotencyKey,formatId:pick.formatId})).status,409);}
  previous={...pick,id};
  const ev=(await readFile('/control/'+id+'/events.jsonl','utf8')).trim().split('\n').map(v=>JSON.parse(v));assert.equal(ev.filter(e=>e.event==='metadata_GET').length,4);assert.equal(ev.filter(e=>e.event==='JPEG_GET').length,1);
  outcomes.push({jobId:id,selectedIndex:index+1,formatId:pick.formatId,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,metadataGET:4,JPEGGET:1,httpStatus:200});
 }
 await writeFile('/control/new-job-result.json',JSON.stringify({status:'PASS_OFFLINE_NEW_JOB_SELECTION',sourceCalls:0,outcomes},null,2));
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async(e)=>{await writeFile('/control/extra-failure.json',JSON.stringify({class:e?.constructor?.name,operator:e?.operator,lines:String(e?.stack||'').split('\n').filter((s:string)=>/^\s+at /.test(s)).slice(0,4)}));await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;});
