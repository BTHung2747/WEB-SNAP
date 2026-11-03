// Focused HTTP integration against an isolated, migrated PostgreSQL + Redis lab.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {writeFile} from 'node:fs/promises';
import {db, redis, queue, defaults, passwordHash} from '../packages/shared/src/core';
const origin='http://127.0.0.1:5219',base='http://api:3000/api/v1/';
type Client={cookie:string;csrf:string};
const outcomes:string[]=[];
let stage='PREFLIGHT';
async function client():Promise<Client>{const r=await fetch(base+'session');assert.equal(r.status,200);const s:any=await r.json();return {cookie:r.headers.get('set-cookie')!.split(';')[0],csrf:s.csrf};}
async function call(c:Client,path:string,method='GET',body?:unknown,headers:Record<string,string>={}){
 const r=await fetch(base+path,{method,headers:{cookie:c.cookie,origin,'x-csrf-token':c.csrf,'content-type':'application/json',...headers},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(10000)});
 return {status:r.status,data:await r.json() as any};
}
async function check(name:string,fn:()=>Promise<void>){stage=name;await fn();outcomes.push(name);console.log('PASS '+name);}
const letter={kind:'bug',subject:'Phản hồi thử nghiệm riêng',message:'Nội dung mô phỏng. https://example.invalid/khong-truy-cap',name:'',email:''};
async function resetRate(){const keys=await redis.keys('rate:feedback:*');if(keys.length)await redis.del(...keys);}
async function main(){
 assert.match(process.env.DATABASE_URL||'',/^postgresql:\/\/feedback_lab:.*@postgres:5432\/feedback_lab$/);assert.equal(process.env.REDIS_URL,'redis://redis:6379/0');assert.equal(process.env.APP_ORIGIN,origin);
 const [database]=await db.$queryRaw<{name:string}[]>`SELECT current_database() AS name`;assert.equal(database.name,'feedback_lab');
 assert.equal(await db.feedback.count(),0);
 await db.settings.upsert({where:{id:'main'},create:{id:'main',value:{...defaults,acceptJobs:false,enabledPlatforms:[]}},update:{}});
 await db.adminUser.upsert({where:{email:'feedback-lab@example.invalid'},create:{email:'feedback-lab@example.invalid',passwordHash:passwordHash('Feedback-lab-only-20261103!')},update:{}});
 const c=await client(),anon=await client();let messageId='';
 await check('session-csrf-origin-admin-isolation',async()=>{
  assert.equal((await call({cookie:'',csrf:''},'feedback','POST',letter)).status,403);
  assert.equal((await call(c,'feedback','POST',letter,{'x-csrf-token':'wrong'})).status,403);
  assert.equal((await call(c,'feedback','POST',letter,{origin:'https://outside.invalid'})).status,403);
  assert.equal((await call(c,'admin/feedback')).status,403);
  assert.equal((await call(c,'admin/feedback/'+randomUUID())).status,403);
  assert.equal((await call(c,'admin/feedback/'+randomUUID(),'PUT',{status:'read'})).status,403);
  assert.equal((await call(c,'admin/feedback/'+randomUUID(),'DELETE')).status,403);
  const login=await fetch(base+'admin/login',{method:'POST',headers:{cookie:c.cookie,origin,'x-csrf-token':c.csrf,'content-type':'application/json'},body:JSON.stringify({email:'feedback-lab@example.invalid',password:'Feedback-lab-only-20261103!'})});assert.equal(login.status,201);c.cookie+='; '+login.headers.get('set-cookie')!.split(';')[0];
 });
 await check('strict-input-and-32k-json',async()=>{
  for(const body of [{...letter,message:''},{...letter,subject:'a'.repeat(121)},{...letter,message:'a'.repeat(4001)},{...letter,email:'bad'},{...letter,message:'<script>bad</script>'},{...letter,extra:'unknown'}]){await resetRate();assert.equal((await call(anon,'feedback','POST',body)).data.error.code,'FEEDBACK_INVALID');}
  const r=await call(anon,'feedback','POST',{...letter,message:'a'.repeat(33000)});assert.equal(r.status,413);assert.equal(r.data.error.code,'FEEDBACK_TOO_LARGE');
  const malformed=await fetch(base+'feedback',{method:'POST',headers:{cookie:anon.cookie,origin,'x-csrf-token':anon.csrf,'content-type':'application/json'},body:'{'});assert.equal(malformed.status,400);assert.equal((await malformed.json() as any).error.code,'FEEDBACK_INVALID');
  assert.equal(await db.feedback.count(),0);
 });
 await check('create-private-independent-record',async()=>{
  await resetRate();const r=await call(anon,'feedback','POST',letter);assert.equal(r.status,201);assert.deepEqual(Object.keys(r.data).sort(),['id','received']);assert.equal(r.data.received,true);messageId=r.data.id;
  const record=await db.feedback.findUniqueOrThrow({where:{id:messageId}});assert.equal(record.message,letter.message);assert.equal(record.name,null);assert.equal(record.email,null);assert.equal(record.status,'unread');
  assert.ok(!('sessionId' in record)&&!('ip' in record));assert.equal((await call(anon,'admin/feedback/'+messageId)).status,403);
  assert.equal((await call(anon,'feedback/'+messageId)).status,404);
 });
 await check('admin-list-detail-status-delete-and-query-validation',async()=>{
  const list=await call(c,'admin/feedback');assert.equal(list.status,200);assert.equal(list.data.items.length,1);assert.ok(!('message' in list.data.items[0])&&!('email' in list.data.items[0]));
  const detail=await call(c,'admin/feedback/'+messageId);assert.equal(detail.data.message,letter.message);
  assert.equal((await call(c,'admin/feedback/'+messageId,'PUT',{status:'read'},{'x-csrf-token':'wrong'})).status,403);
  for(const status of ['read','resolved','unread']){assert.equal((await call(c,'admin/feedback/'+messageId,'PUT',{status})).status,200);assert.equal((await call(c,'admin/feedback/'+messageId)).data.status,status);}
  for(const query of ['page=0','page=51','page=1&page=2','status=no','other=yes'])assert.equal((await call(c,'admin/feedback?'+query)).data.error.code,'FEEDBACK_INVALID');
  assert.equal((await call(c,'admin/feedback/not-a-uuid')).data.error.code,'FEEDBACK_INVALID');
  assert.equal((await call(c,'admin/feedback/'+messageId,'PUT',{status:'no'})).status,400);
  assert.equal((await call(c,'admin/feedback/'+messageId,'DELETE',undefined,{'x-csrf-token':'wrong'})).status,403);
  assert.equal((await call(c,'admin/feedback/'+messageId,'DELETE')).status,200);assert.equal((await call(c,'admin/feedback/'+messageId)).status,404);
 });
 await check('real-redis-session-and-trusted-ip-limits',async()=>{
  await resetRate();for(let n=0;n<3;n++)assert.equal((await call(anon,'feedback','POST',letter)).status,201);
  assert.equal((await call(anon,'feedback','POST',letter,{'x-forwarded-for':'203.0.113.9'})).status,429);
  await resetRate();const users=[c,anon,await client(),await client()];
  for(let n=0;n<10;n++)assert.equal((await call(users[Math.floor(n/3)],'feedback','POST',letter,{'x-forwarded-for':'203.0.113.'+(n+1)})).status,201);
  const blocked=await call(users[3],'feedback','POST',letter,{'x-forwarded-for':'198.51.100.9'});assert.equal(blocked.status,429);
 });
 await check('pagination-retention-and-atomic-capacity',async()=>{
  await resetRate();await db.feedback.deleteMany();
  await db.feedback.create({data:{kind:'idea',subject:'Quá hạn',message:'Synthetic',createdAt:new Date(Date.now()-91*86400000)}});
  const expiredList=await call(c,'admin/feedback');assert.equal(expiredList.data.total,0);assert.equal(await db.feedback.count(),0);
  await db.feedback.createMany({data:Array.from({length:999},()=>({kind:'feedback' as const,subject:'Fixture dung lượng',message:'Synthetic'}))});
  const attempts=await Promise.all([call(c,'feedback','POST',letter),call(anon,'feedback','POST',letter)]);assert.deepEqual(attempts.map(r=>r.status).sort(),[201,503]);assert.equal(await db.feedback.count(),1000);
  const page1=(await call(c,'admin/feedback?page=1')).data,page2=(await call(c,'admin/feedback?page=2')).data;assert.equal(page1.items.length,20);assert.equal(page1.pages,50);assert.equal(page1.total,1000);assert.equal(new Set([...page1.items,...page2.items].map(r=>r.id)).size,40);
  await db.feedback.deleteMany();await resetRate();
  // Leave two explicitly synthetic letters for the browser's real API review.
  await call(anon,'feedback','POST',{...letter,subject:'Gợi ý chọn định dạng',message:'Nên giải thích ngắn gọn khi nào chọn MP3 và khi nào chọn video.',kind:'idea'});
  await call(anon,'feedback','POST',{...letter,subject:'Cảm ơn đội ngũ WED SNAP',message:'Giao diện dễ dùng. Đây là phản hồi thử trong lab riêng.',kind:'feedback',name:'Người dùng thử'});
 });
 await writeFile('/out/api-checks.json',JSON.stringify({result:'PASS',environment:'isolated migrated PostgreSQL + real Redis + Nest HTTP',groups:outcomes,sourceRequests:0,productionChanged:false},null,2));
}
main().catch(async(error)=>{const safe={result:'FAIL',stage,type:/^[A-Za-z]+$/.test(error?.constructor?.name||'')?error.constructor.name:'UNKNOWN',code:/^[A-Z0-9_]+$/.test(error?.code||'')?error.code:null,actual:typeof error?.actual==='number'?error.actual:null,expected:typeof error?.expected==='number'?error.expected:null};await writeFile('/out/api-checks-failure.json',JSON.stringify(safe));console.error(JSON.stringify(safe));process.exitCode=20;}).finally(async()=>{await queue.close();redis.disconnect();await db.$disconnect();});
