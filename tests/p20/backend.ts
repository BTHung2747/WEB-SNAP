import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { readFileSync, readlinkSync } from 'node:fs';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import cookieParser from 'cookie-parser';
import { AdsController } from '../../apps/api/src/controllers/ads.controller';
import { AdsService } from '../../apps/api/src/services/ads.service';
import { SafeErrors } from '../../apps/api/src/common';
import { db, redis, queue, secret, hash } from '../../packages/shared/src/core';

async function main() {

const raw = (stage: string, data: object) => console.log('P20_BACKEND ' + JSON.stringify({ utc: new Date().toISOString(), stage, ...data }, (_, v) => typeof v === 'bigint' ? v.toString() : v));
const paths = ['apps/api/src/services/ads.service.ts','apps/web/src/components/Advertising.tsx','apps/web/src/pages/Home.tsx'];
// Web SHA is guarded by host; API/shared actually mounted RO and hashed here.
const apiSha = createHash('sha256').update(readFileSync(paths[0])).digest('hex');
assert.equal(apiSha,process.env.P20_SOURCE_SHA);
assert.equal(process.env.P20_GUARD, 'wed-snap-ads-lab');
assert.equal(process.env.DATABASE_URL, 'postgresql://p20@db:5432/wed_snap_ads_test');
assert.equal(process.env.REDIS_URL, 'redis://redis:6379/14');
assert.equal(process.env.MEDIA_ROOT, '/tmp/p20-unused-media');
@Module({ controllers: [AdsController], providers: [AdsService] }) class LabModule {}
const app = await NestFactory.create(LabModule, { logger: ['error'] });
app.use(cookieParser()); app.useGlobalFilters(new SafeErrors());
let release: (() => void) | undefined, arrivals = 0, inflight = 0, peak = 0;
const overlap: object[] = [];
app.use(async (req: any, res: any, next: () => void) => {
  if (req.get('x-p20-overlap') === 'pair') {
    inflight++; peak = Math.max(peak, inflight);
    overlap.push({ event: 'enter', at: performance.now(), inflight });
    res.once('finish', () => { overlap.push({ event: 'finish', at: performance.now(), inflight }); inflight--; });
    if (++arrivals === 1) await new Promise<void>(r => { release = r; });
    else release?.();
  }
  next();
});
await app.listen(0, '127.0.0.1');
const url = await app.getUrl();
const fixtures: { token: string; id: string; csrf: string }[] = [];
const campaignIds: string[] = [], eventIds: string[] = [];
const snapshot = async () => ({ settings: await db.settings.findMany({ orderBy: {id:'asc'} }), charged: await db.egressBudget.findMany({orderBy:{month:'asc'}}) });
const saved = await snapshot();
const identity:any[]=await db.$queryRaw`SELECT current_database() AS database, version() AS version`;
assert.equal(identity[0].database,'wed_snap_ads_test');
assert(/\bdb=14\b/.test(String(await redis.client('INFO'))),'Actual Redis database must be14');
const redisVersion=(await redis.info('server')).match(/redis_version:([^\r\n]+)/)?.[1];
raw('actual-datastore-readonly-guard',{database:identity[0].database,postgres:identity[0].version,redisVersion,redisDatabase:14,nest:JSON.parse(readFileSync('node_modules/@nestjs/core/package.json','utf8')).version,prisma:JSON.parse(readFileSync('node_modules/@prisma/client/package.json','utf8')).version});
const counts = async () => ({ sessions: await db.session.count(), campaigns: await db.adCampaign.count(), events: await db.adEvent.count(), jobs: await db.downloadJob.count() });
const beforeCounts = await counts();
assert.equal(beforeCounts.campaigns, 0, 'Lab must have no foreign campaigns (refuse, never delete them)');
raw('matrix-before-write', { apiSha, sharedSha:createHash('sha256').update(readFileSync('packages/shared/src/core.ts')).digest('hex'), sourceGuard:process.env.P20_SOURCE_SHA, node: process.version, namespace:readlinkSync('/proc/self/ns/pid'), beforeCounts, transport:'real HTTP Nest AdsController/AdsService; real Postgres/Redis14; request barrier only', expected: ['same-cookie overlap peak2:exactly1 sponsor/null1/TTL600', 'other cookie independently granted', 'banner unlimited/no sponsor TTL renewal', 'no eligible campaign:no claim', 'fixture-only PEXPIRE exercises expiry without changing600 production', 'cookie spoof/expired403', 'event UUID dedupe/concurrent + CSRF403/rate429/no insert on rejection'] });
let passed = 0, failed = 0;
const run = async (name: string, fn: () => Promise<void>) => { try { await fn(); passed++; raw('case-result',{name,result:'PASS'}); } catch(e) { failed++; raw('case-result',{name,result:'FAIL',error:String(e)}); } };
const session = async () => { const token = secret(), s = { token, id:hash(token), csrf:secret() }; await db.session.create({data:{id:s.id,csrf:s.csrf,expiresAt:new Date(Date.now()+3600000)}}); fixtures.push(s); return s; };
const get = async (s: typeof fixtures[number], placement='sponsor', extra: Record<string,string>={}) => { const r = await fetch(url+'/api/v1/ads?placement='+placement, {headers:{Cookie:'ws_session='+s.token,...extra}}); const body=await r.json(); raw('http',{placement,status:r.status,hasAd:!!body?.id}); return {r,body}; };
const claim = (s: typeof fixtures[number]) => 'ads:sponsor:'+s.id;
const campaign = async (placement: string) => { const id=randomUUID(); campaignIds.push(id); return db.adCampaign.create({data:{id,title:'P20 fixture '+placement,targetUrl:'https://example.invalid/p20',placement,enabled:true,startsAt:new Date(Date.now()-10000),endsAt:new Date(Date.now()+3600000),weight:1}}); };
try {
  const a=await session(), b=await session(), empty=await session();
  await run('no-campaign-before-claim',async()=> { assert.equal((await get(empty)).body,null); assert.equal(await redis.exists(claim(empty)),0); });
  const sponsor=await campaign('sponsor'), banner=await campaign('banner');
  await run('same-cookie-real-overlap',async()=> {
    const results=await Promise.all([get(a,'sponsor',{'x-p20-overlap':'pair'}),get(a,'sponsor',{'x-p20-overlap':'pair'})]);
    const grants=results.filter(x=>x.body?.id===sponsor.id).length, ttl=await redis.pttl(claim(a));
    raw('overlap',{peak,arrivals,grants,nulls:results.filter(x=>x.body===null).length,ttlMs:ttl,overlap});
    assert.equal(peak,2); assert.equal(grants,1); assert.equal(results.filter(x=>x.body===null).length,1); assert(ttl>595000&&ttl<=600000);
  });
  await run('other-cookie-independent',async()=> {assert.equal((await get(b)).body?.id,sponsor.id); assert((await redis.pttl(claim(b)))>595000);});
  await run('banner-and-no-renew',async()=> {const ttl=await redis.pttl(claim(a)); for(let i=0;i<2;i++)assert.equal((await get(a,'banner')).body?.id,banner.id); assert.equal((await get(a)).body,null); const later=await redis.pttl(claim(a));raw('ttl-no-renew',{ttl,later});assert(later<=ttl);});
  await run('no-campaign-does-not-consume',async()=> {const s=await session();await db.adCampaign.update({where:{id:sponsor.id},data:{enabled:false}});assert.equal((await get(s)).body,null);assert.equal(await redis.exists(claim(s)),0);await db.adCampaign.update({where:{id:sponsor.id},data:{enabled:true}});assert.equal((await get(s)).body?.id,sponsor.id);});
  await run('expiry-owned-key-only',async()=> {
    assert.equal(await redis.exists(claim(b)),1); const original=await redis.pttl(claim(b));assert(original>590000);
    await redis.pexpire(claim(b),30); const until=performance.now()+1500;
    while(await redis.exists(claim(b)) && performance.now()<until) await new Promise(r=>setTimeout(r,10));
    assert.equal(await redis.exists(claim(b)),0);assert.equal((await get(b)).body?.id,sponsor.id);const ttl=await redis.pttl(claim(b));raw('expiry',{original,fixtureTtl:30,newTtl:ttl});assert(ttl>595000&&ttl<=600000);
  });
  await run('cookie-authentication',async()=> {const fake={...a,token:secret()};assert.equal((await get(fake)).r.status,403);const s=await session();await db.session.update({where:{id:s.id},data:{expiresAt:new Date(0)}});assert.equal((await get(s)).r.status,403);assert.equal(await redis.exists(claim(s)),0);});
  const eventsSession=await session();
  const post=async(id:string,type='impression',csrf=eventsSession.csrf)=>{const r=await fetch(url+'/api/v1/ad-events',{method:'POST',headers:{Cookie:'ws_session='+eventsSession.token,Origin:'http://p20.local','x-csrf-token':csrf,'Content-Type':'application/json'},body:JSON.stringify({id,campaignId:sponsor.id,type})});const body=await r.json();return {status:r.status,body};};
  await run('event-id-dedupe-concurrent-and-click',async()=>{const id=randomUUID(),click=randomUUID();eventIds.push(id,click);const rs=await Promise.all([post(id),post(id)]);assert(rs.every(r=>r.status===201));assert.equal(await db.adEvent.count({where:{id}}),1);assert.equal((await post(id,'click')).status,201);assert.equal((await db.adEvent.findUnique({where:{id}}))?.type,'impression');assert.equal((await post(click,'click')).status,201);assert.equal((await db.adEvent.findUnique({where:{id:click}}))?.type,'click');raw('event-dedupe',{statuses:rs.map(r=>r.status),rows:await db.adEvent.count({where:{id:{in:[id,click]}}})});});
  await run('event-csrf-rate-regression',async()=>{const bad=randomUUID();assert.equal((await post(bad,'click','wrong')).status,403);assert.equal(await db.adEvent.count({where:{id:bad}}),0);const counter=Number(await redis.get('rate:ads:'+eventsSession.id));assert.equal(counter,4);for(let i=counter;i<60;i++){const id=randomUUID();eventIds.push(id);assert.equal((await post(id)).status,201);}const id=randomUUID();const before=await db.adEvent.count();const r=await post(id);assert.equal(r.status,429);assert.equal(r.body.error.code,'RATE_LIMITED');assert.equal(await db.adEvent.count(),before);raw('event-rate',{counterBefore:counter,limit:60,status:r.status,code:r.body.error.code,before,after:await db.adEvent.count()});});
} finally {
  await app.close();
  await db.adEvent.deleteMany({where:{id:{in:eventIds}}});
  await db.adCampaign.deleteMany({where:{id:{in:campaignIds}}});
  await db.session.deleteMany({where:{id:{in:fixtures.map(s=>s.id)}}});
  for(const s of fixtures) await redis.del(claim(s),'rate:ads:'+s.id);
  assert.deepEqual(await snapshot(),saved);assert.deepEqual(await counts(),beforeCounts);
  raw('cleanup',{ownedSessions:fixtures.length,ownedCampaigns:campaignIds.length,ownedEvents:eventIds.length,counts:await counts(),settingsChargedDeepEqual:true,noReset:true});
  await queue.close();await redis.quit();await db.$disconnect();
}
raw('summary',{passed,failed,result:failed?'FAIL':'PASS'});if(failed)process.exitCode=1;
}
main().catch(e => { console.error('P20_HARNESS_FAIL',String(e)); process.exit(1); });

