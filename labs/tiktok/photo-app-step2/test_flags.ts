import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';
import { db, redis, queue, defaults } from '/app/packages/shared/src/core';
async function main(){
 for(let i=0;i<120;i++){try{if((await fetch('http://127.0.0.1:3000/api/v1/health')).ok)break;}catch{}await new Promise(r=>setTimeout(r,100));}
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,enabledPlatforms:['youtube','tiktok']}},update:{}});
 const s=await fetch('http://127.0.0.1:3000/api/v1/session');const session:any=await s.json();
 const before=await db.downloadJob.count();
 const response=await fetch('http://127.0.0.1:3000/api/v1/jobs/analyze',{method:'POST',headers:{cookie:s.headers.get('set-cookie')!.split(';')[0],origin:process.env.APP_ORIGIN!,'x-csrf-token':session.csrf,'content-type':'application/json'},body:JSON.stringify({url:'https://www.tiktok.com/@fixture/photo/7000000000000000001'})});
 const result:any=await response.json();assert.equal(response.status,400);assert.equal(result.error.code,'UNSUPPORTED_PLATFORM');assert.equal(await db.downloadJob.count(),before);assert.ok(!('photo' in session));
 await writeFile('/control/flags-api-result.json',JSON.stringify({status:'PASS_OFFLINE_API_FLAG_OFF',httpStatus:response.status,jobsCreated:0,sourceCalls:0}));
}
main().then(async()=>{await queue.close();redis.disconnect();await db.$disconnect();}).catch(async()=>{console.error('FLAG_API_TEST_FAILED');await queue.close();redis.disconnect();await db.$disconnect();process.exitCode=1;});
