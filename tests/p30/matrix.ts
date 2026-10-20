import assert from 'node:assert/strict';
import http from 'node:http';
import expected from './expected.json';
export async function runMatrix({core,email,password,raw,baseline,snapshot,app}:any){
 const results:any[]=[];let cookie='',csrf='';
 async function request(path:string,options:any={}){
  const start=Date.now();return await new Promise<any>((resolve,reject)=>{
   const body=options.body===undefined?undefined:JSON.stringify(options.body);
   const req=http.request({hostname:'127.0.0.1',port:3000,path,method:options.method||'GET',agent:false,headers:{...(options.cookie===false?{}:{Cookie:options.cookie??cookie}),...(body?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(body)}:{}),...(options.method?{Origin:core.origin,'x-csrf-token':csrf}:{}),...options.headers}},res=>{
    let b='';res.on('data',c=>{b+=c;if(Buffer.byteLength(b)>65536)req.destroy(Error('Response bound'));});res.on('end',()=>{try{const data=JSON.parse(b);if(options.capture){const cookies=(res.headers['set-cookie']||[]).map(c=>c.split(';')[0]);cookie=[...cookie.split('; ').filter(Boolean).filter(c=>!cookies.some(n=>n.split('=')[0]===c.split('=')[0])),...cookies].join('; ');if(data.csrf)csrf=data.csrf;}resolve({status:res.statusCode,data,headers:res.headers,start,end:Date.now()});}catch(e){reject(e);}});
   });req.setTimeout(5000,()=>req.destroy(Error('HTTP deadline')));req.on('error',reject);req.end(body);
  });
 }
 async function test(name:string,fn:()=>Promise<any>){try{const evidence=await fn();results.push({name,result:'PASS',evidence});}catch(e){results.push({name,result:'FAIL',error:(e as Error).message});}raw('matrix-case',results.at(-1));}
 const base=expected.endpoint,q=(from=expected.from,to=expected.to)=>'?'+new URLSearchParams({from,to});
 const snapshotState=async()=>({campaign:await core.db.adCampaign.findMany({orderBy:{id:'asc'}}),event:await core.db.adEvent.findMany({orderBy:{id:'asc'}}),settings:await core.db.settings.findMany(),budget:await core.db.egressBudget.findMany(),audit:await core.db.auditLog.findMany(),sessions:await core.db.session.count()});
 await test('no-admin',async()=>{const r=await request(base,{cookie:false});assert.equal(r.status,403);assert.equal(r.data.error.code,'ADMIN_REQUIRED');return {status:r.status,code:r.data.error.code};});
 await request('/api/v1/session',{capture:true});await request('/api/v1/admin/login',{method:'POST',body:{email,password},capture:true});
 const before=await snapshotState();
 await test('utc-boundaries',async()=>{const r=await request(base+q());assert.equal(r.status,200);assert.deepEqual(r.data.window,{from:expected.from,to:expected.to,timezone:'UTC'});assert.deepEqual(r.data.rows.map(({campaignId,...row}:any)=>row).sort((a:any,b:any)=>a.title.localeCompare(b.title)),expected.rows);return r.data;});
 if(true){
 await test('offset-equivalence',async()=>{const a=await request(base+q()),b=await request(base+q('2026-01-01T07:00:00+07:00','2026-01-02T07:00:00+07:00'));assert.equal(b.status,200);assert.deepEqual(a.data,b.data);return b.data;});
 await test('empty-window-zero-rows',async()=>{const r=await request(base+q('2026-02-01T00:00:00Z','2026-02-02T00:00:00Z'));assert.equal(r.status,200);assert.equal(r.data.rows.length,2);assert(r.data.rows.every((x:any)=>x.impressions===0&&x.clicks===0&&x.ctrPercent===null));return r.data;});
 await test('default-window',async()=>{const r=await request(base);assert.equal(r.status,200);assert.equal(Date.parse(r.data.window.to)-Date.parse(r.data.window.from),7*86400000);assert(Date.parse(r.data.window.to)>=r.start&&Date.parse(r.data.window.to)<=r.end);return {window:r.data.window,bounds:[r.start,r.end]};});
 await test('90-days',async()=>{const r=await request(base+q('2026-01-01T00:00:00Z','2026-04-01T00:00:00Z'));assert.equal(r.status,200);return {status:r.status};});
 const invalid:Record<string,string>={
 'over-90-days':q('2026-01-01T00:00:00Z','2026-04-01T00:00:00.001Z'),reversed:q(expected.to,expected.from),equal:q(expected.from,expected.from),'missing-from':'?to='+expected.to,'missing-to':'?from='+expected.from,'invalid-calendar':q('2026-02-30T00:00:00Z',expected.to),'no-timezone':q('2026-01-01T00:00:00',expected.to),duplicate:q()+'&from='+expected.from,array:'?from[]='+expected.from+'&to='+expected.to,unknown:q()+'&extra=1','query-injection':'?from%5B%24gte%5D=2026-01-01&to='+expected.to};
 for(const [name,query] of Object.entries(invalid))await test(name,async()=>{const r=await request(base+query);assert.equal(r.status,400);assert.equal(r.data.error.code,'INVALID_REQUEST');return {query,status:r.status,code:r.data.error.code};});
 await test('unknown-event-excluded',async()=>{assert.equal(await core.db.adEvent.count({where:{type:'other'}}),1);const r=await request(base+q());assert.equal(r.data.rows.find((x:any)=>x.title==='p30-A').impressions,2);return {unknownEvents:1};});
 await test('admin-get-no-guest-no-csrf',async()=>{const adminCookie=cookie.split('; ').find(c=>c.startsWith('ws_admin='));assert(adminCookie);const r=await request(base+q(),{cookie:adminCookie});assert.equal(r.status,200);assert(!r.headers['set-cookie']);assert.equal(r.headers['cache-control'],'no-store');return {status:r.status,guest:false,csrf:false,setCookie:false};});
 await test('read-only',async()=>{assert.deepEqual(await snapshotState(),before);return {deepEqual:true,settingsBudgetChargedAuditSessionUnchanged:true};});
 await test('old-contract-preserved',async()=>{const {createOpenApiDocument}=await import('../../apps/api/src/openapi');const doc=createOpenApiDocument(app),old=JSON.parse(snapshot);for(const [path,value]of Object.entries(old.paths))assert.deepEqual(doc.paths[path],value,path);for(const [name,value]of Object.entries(old.components.schemas))assert.deepEqual(doc.components!.schemas![name],value,name);assert.deepEqual(doc.components!.securitySchemes,old.components.securitySchemes);assert.equal(Object.keys(doc.paths).length,20);assert.equal(Object.values(doc.paths).reduce((n:number,p:any)=>n+Object.keys(p).filter(m=>['get','post','head','put','delete'].includes(m)).length,0),24);const refs=(v:any)=>{if(v&&typeof v==='object'){if(v.$ref)assert(doc.components!.schemas![v.$ref.split('/').at(-1)]);Object.values(v).forEach(refs);}};refs(doc);return {paths:20,operations:24,oldPaths:19,oldSchemas:20,preserved:true,refs:true};});
 await test('settings-campaign-control',async()=>{for(const path of ['dashboard','settings','campaigns']){const r=await request('/api/v1/admin/'+path);assert.equal(r.status,200);}assert.deepEqual(await snapshotState(),before);return {oldAdminGets:3,noEffects:true};});
 }
 await request('/api/v1/admin/logout',{method:'POST'});
 const result={baseline,expectedSHA:'external before manifest',cases:results.length,pass:results.filter(r=>r.result==='PASS').length,fail:results.filter(r=>r.result==='FAIL').length,results};raw('matrix-summary',result);return result;
}

