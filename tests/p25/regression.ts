import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { RequestMethod } from '@nestjs/common';
import { generated, canonical, raw, sha } from './bootstrap';
import { expected, states, jobKeys, sessionKeys, sourceRefs } from './regression-expectations';
const same=(a:any,b:any)=>assert.deepEqual([...a].sort(),[...b].sort());
async function main(){
  const {doc,counts,routes,validation}=await generated();const d:any=doc;
  const matrix:{name:string;expected:string;run:()=>void}[]=[];
  const add=(name:string,expectedText:string,run:()=>void)=>matrix.push({name,expected:expectedText,run});
  function resolve(s:any):any{assert(s,'schema required');if(s.$ref){assert(s.$ref.startsWith('#/components/schemas/'));return resolve(d.components.schemas[s.$ref.split('/').at(-1)]);}return s;}
  function accepts(s:any,v:any){s=resolve(s);if(v===null){assert(s.nullable,'expected nullable');return;}if(s.allOf){s.allOf.forEach((p:any)=>accepts(p,v));return;}if(s.enum)assert(s.enum.includes(v));
    if(s.type==='object'){assert(v&&typeof v==='object'&&!Array.isArray(v));for(const key of s.required||[])assert(key in v,'missing '+key);for(const [key,value]of Object.entries(v)){if(s.additionalProperties===false)assert(key in (s.properties||{}),'unknown '+key);if(s.properties?.[key])accepts(s.properties[key],value);}}
    if(s.type==='array'){assert(Array.isArray(v));if(s.maxItems!==undefined)assert(v.length<=s.maxItems);v.forEach(x=>accepts(s.items,x));}
    if(s.type==='string'){assert.equal(typeof v,'string');if(s.maxLength!==undefined)assert(v.length<=s.maxLength);if(s.minLength!==undefined)assert(v.length>=s.minLength);if(s.pattern)assert(new RegExp(s.pattern).test(v));if(s.format==='uuid')assert(/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(v));if(s.format==='date-time')assert(/^\d{4}-\d\d-\d\dT/.test(v)&&Number.isFinite(Date.parse(v)));}
    if(s.type==='number'||s.type==='integer'){assert.equal(typeof v,'number');if(s.type==='integer')assert(Number.isInteger(v));if(s.minimum!==undefined)assert(v>=s.minimum);}
    if(s.type==='boolean')assert.equal(typeof v,'boolean');
  }
  const json=(o:any,status:number)=>o.responses[String(status)].content?.['application/json']?.schema;
  function codes(s:any):string[]{s=resolve(s);if(s.properties?.error?.properties?.code?.enum)return s.properties.error.properties.code.enum;if(s.allOf)return s.allOf.flatMap(codes);return [];}
  const fixtureId='11111111-1111-4111-8111-111111111111';
  for(const [name,method,path,success,errors,auth] of expected){add('operation-'+name,'exact statuses/errors, success shape, nullability, params and cookie/CSRF/Origin from source; '+sourceRefs.validation,()=>{
    const o=d.paths[path]?.[method];assert(o,'missing '+method+' '+path);
    same(Object.keys(o.responses),[String(success),...Object.keys(errors),...(name.startsWith('download-')?['206']:[])]);
    for(const [status,allowed] of Object.entries(errors)){
      const response=o.responses[status];assert(response.description);
      if(method==='head'){assert(!response.content,'HEAD errors have no body');same(response['x-error-codes'],allowed);}
      else{same(codes(json(o,Number(status))),allowed);for(const code of allowed)accepts(json(o,Number(status)),{error:{code}});assert.throws(()=>accepts(json(o,Number(status)),{error:{code:allowed[0],message:'internal'}}));}
    }
    const parameters=o.parameters||[];const header=(n:string)=>parameters.find((p:any)=>p.in==='header'&&p.name===n);
    if(auth==='public')assert.deepEqual(o.security,[]);else assert(o.security.some((s:any)=>s.cookie));
    if(method==='post'){assert.equal(header('Origin')?.required,true);assert(header('x-csrf-token'));if(auth==='header'){assert.equal(header('x-csrf-token').required,true);assert.deepEqual(o.security,[{cookie:[],csrf:[]}]);}else{assert.equal(header('x-csrf-token').required,false);same(o['x-csrf-alternatives'],['header:x-csrf-token','body:csrf']);const body=resolve(o.requestBody.content['application/json'].schema);assert(body.properties.csrf);assert(o.description.includes('csrf'));}}
    else{assert(!header('Origin')&&!header('x-csrf-token'));if(auth==='cookie')assert.deepEqual(o.security,[{cookie:[]}]);}
    if(path.includes('{id}')){const p=parameters.find((p:any)=>p.name==='id'&&p.in==='path');assert(p.required);assert.equal(p.schema.format,'uuid');}
    if(path.includes('{ticket}')){const p=parameters.find((p:any)=>p.name==='ticket'&&p.in==='path');assert(p.required);assert.equal(p.schema.pattern,'^[a-f0-9]{64}$');}
    if(name==='health')accepts(json(o,success),{ok:true});
    if(name==='session'){const s=resolve(json(o,success));same(s.required,sessionKeys);accepts(s,{csrf:'a'.repeat(64),supported:['youtube'],verified:['youtube'],contact:null,productName:'WED SNAP',heartbeatSeconds:15});assert.equal(s.properties.productName.maxLength,60);assert(!s.properties.contact.format,'contact env not validated email');}
    if(name==='analyze')accepts(json(o,success),{jobId:fixtureId});
    if(name==='prepare'){accepts(json(o,success),{jobId:fixtureId,state:'queued'});same(resolve(json(o,success)).required,['jobId','state']);}
    if(['heartbeat','release','cancel'].includes(name))accepts(json(o,success),{ok:true});
    if(name==='ticket')accepts(json(o,success),{url:'/api/v1/downloads/'+'b'.repeat(64),expiresIn:1800});
    if(name==='status'){const s=resolve(json(o,success));same(s.required,jobKeys);same(Object.keys(s.properties),jobKeys);same(s.properties.state.enum,states);assert.equal(s.properties.mode.enum.join(),'temporary');for(const state of states)accepts(s,{id:fixtureId,state,errorCode:null,title:null,duration:null,metadataAcceptedAt:null,metadataExpiresAt:null,items:[],previewUrl:null,mode:'temporary',serverMeaning:'server_finished không chứng minh tệp đã lưu vào thiết bị'});accepts(s,{id:fixtureId,state:'selectable',errorCode:null,title:'Local schema fixture',duration:1,metadataAcceptedAt:'2026-10-03T00:00:00.000Z',metadataExpiresAt:'2026-10-03T00:02:00.000Z',items:[{id:fixtureId,kind:'video',formats:[{id:'137+140',label:'MP4 có tiếng',size:null,height:null,kind:'video'}]}],previewUrl:'/api/v1/jobs/'+fixtureId+'/preview',mode:'temporary',serverMeaning:'server_finished không chứng minh tệp đã lưu vào thiết bị'});}
    if(name==='preview'){for(const media of ['image/jpeg','image/png'])assert(o.responses['200'].content[media].schema.format==='binary');assert(o.responses['404'].description.includes('body rỗng'));}
    if(name.startsWith('download-')){const range=header('Range');assert(range&&!range.required);for(const status of ['200','206']){const r=o.responses[status];for(const h of ['Content-Type','Content-Length','Accept-Ranges','Cache-Control'])assert(r.headers[h]);if(status==='206')assert(r.headers['Content-Range']);else assert(!r.headers['Content-Range']);if(method==='head'){assert(!r.content);assert(!r.headers['Content-Disposition']);assert.equal(r.headers['Cache-Control'].schema.enum[0],'no-store');}else{assert(r.content['video/mp4'].schema.format==='binary');assert(r.headers['Content-Disposition']);assert.equal(r.headers['Cache-Control'].schema.enum[0],'private, no-store');}}assert(o.responses['416'].headers['Content-Range'].schema.pattern.includes('bytes'));}
  });}
  add('inventory-and-route-metadata','19paths/23operations;11targetpaths/12ops;11actual public handlers+implicit HEAD only',()=>{
    assert.equal(Object.keys(d.paths).length,19);assert.equal(Object.values(d.paths).reduce((n:number,p:any)=>n+['get','head','post','put','delete'].filter(m=>p[m]).length,0),23);
    assert.equal(new Set(expected.map(x=>x[2])).size,11);assert.equal(routes.length,11);
    for(const r of routes){const p='/'+r.base+'/'+r.path.replace(/:([^/]+)/g,'{$1}');const method=RequestMethod[r.method].toLowerCase();assert.equal(d.paths[p][method].operationId,r.controller+'_'+r.handler);}
    const p=d.paths['/api/v1/downloads/{ticket}'];assert.equal(p.head['x-implicit-head-of'],p.get.operationId);assert(!routes.some((r:any)=>r.method===RequestMethod.HEAD));
  });
  add('request-validation-contract','analyze max2048/strict;prepare UUIDs/max80/regex/strict match production Zod; no invented body constraints',()=>{
    const a=resolve(d.paths['/api/v1/jobs/analyze'].post.requestBody.content['application/json'].schema);assert.equal(a.additionalProperties,false);same(a.required,['url']);assert.equal(a.properties.url.maxLength,2048);
    assert(validation.inputSchema.safeParse({url:'x'.repeat(2048)}).success);assert(!validation.inputSchema.safeParse({url:'x'.repeat(2049)}).success);assert(!validation.inputSchema.safeParse({url:'x',csrf:'token'}).success);
    const p=resolve(d.paths['/api/v1/jobs/{id}/prepare'].post.requestBody.content['application/json'].schema);assert.equal(p.additionalProperties,false);same(p.required,['itemId','formatId','idempotencyKey']);assert.equal(p.properties.formatId.maxLength,80);assert.equal(p.properties.formatId.pattern,'^[\\w-]+(?:\\+[\\w-]+)?$');
    for(const formatId of ['137+140','abc_1','x'.repeat(80),'x'.repeat(81),'a+b+c','a/b','']){const payload={itemId:fixtureId,formatId,idempotencyKey:fixtureId};let accepted=true;try{accepts(p,payload);}catch{accepted=false;}assert.equal(accepted,validation.prepareSchema.safeParse(payload).success,'Zod/schema disagreement '+formatId);}
  });
  add('metadata-and-cancel-expiry','fixed deadline<=120000ms/now>=,not owner/HB;legacy nullable;cancel410;release no410;no internal leak',()=>{
    const o=d.paths['/api/v1/jobs/{id}'].get;const ttl=o['x-metadata-ttl'];assert.deepEqual(ttl,{maxAgeMs:120000,origin:'metadataAcceptedAt',expiresWhen:'now >= metadataExpiresAt',heartbeatRenews:false,legacyMissing:'expired',trustedEarlierSourceExpiry:true,acceptedPrepareContinues:true});
    assert(d.paths['/api/v1/jobs/{id}/cancel'].post.responses['410']);assert(!d.paths['/api/v1/jobs/{id}/release'].post.responses['410']);assert(d.paths['/api/v1/jobs/{id}/prepare'].post.responses['410']);
    const schemas=JSON.stringify(d.components.schemas);for(const privateKey of ['cleanupCompletedAt','workerToken','processUntil','sourceUrl','transferLease','password','cookieValue'])assert(!schemas.includes('"'+privateKey+'"'));assert(!Object.keys(resolve(o.responses['200'].content['application/json'].schema).properties).includes('path'));
  });
  add('head-is-bodyless-and-non-reserving','HEAD no503budget/content/disposition;method branch before lease;code metadata not runtime certification',()=>{const h=d.paths['/api/v1/downloads/{ticket}'].head;assert(h);assert(h.description.includes('không tạo lease')&&h.description.includes('không reserve'));assert(!h.responses['503']);for(const r of Object.values(h.responses) as any[])assert(!r.content);assert.equal(h['x-transfer-reservation'],false);assert.equal(d.paths['/api/v1/downloads/{ticket}'].get['x-transfer-reservation'],true);});
  add('refs-uniqueness-security','all refs resolve;no duplicate operationId/parameter/security;cookie schemes exact',()=>{
    const walk=(value:any)=>{if(!value||typeof value!=='object')return;if(value.$ref){assert(value.$ref.startsWith('#/'));let target:any=d;for(const k of value.$ref.slice(2).split('/'))target=target?.[k.replace(/~1/g,'/').replace(/~0/g,'~')];assert(target,'unresolved '+value.$ref);}Object.values(value).forEach(walk);};walk(d);
    const ids=new Set();for(const p of Object.values(d.paths) as any[])for(const method of ['get','head','post','put','delete']){const o=p[method];if(!o)continue;assert(!ids.has(o.operationId));ids.add(o.operationId);const params=(o.parameters||[]).map((p:any)=>p.in+':'+p.name);assert.equal(new Set(params).size,params.length);const sec=(o.security||[]).map((s:any)=>JSON.stringify(canonical(s)));assert.equal(new Set(sec).size,sec.length);for(const requirement of o.security||[])for(const key of Object.keys(requirement))assert(d.components.securitySchemes[key]);}
    assert.deepEqual(d.components.securitySchemes.cookie,{type:'apiKey',in:'cookie',name:'ws_session'});assert.deepEqual(d.components.securitySchemes.csrf,{type:'apiKey',in:'header',name:'x-csrf-token'});
  });
  add('admin-ads-protected-contract','all non-target operations byte-semantically match preserved19/22 snapshot, not complete schemas',()=>{const baseline=JSON.parse(readFileSync('tests/p24/backlog.baseline.json','utf8'));const target=new Set(expected.map(x=>x[2]));for(const [path,value]of Object.entries(baseline.paths)){if(!target.has(path as any))assert.deepEqual(canonical(d.paths[path]),canonical(value));}assert.deepEqual(d.components.securitySchemes.adminCookie,baseline.components.securitySchemes.adminCookie);});
  add('normalized-snapshot','docs/openapi.json equals canonical generated Swagger+describeContracts, not manually fabricated',()=>{assert.deepEqual(canonical(d),canonical(JSON.parse(readFileSync('docs/openapi.json','utf8'))));});
  add('measured-framework-only-delta','entire canonical P24 snapshot preserved except400 responses at12 measured public operations; all other statuses/schemas/routes/adminads identical',()=>{
    const baseline=JSON.parse(readFileSync('tests/p25/baseline.openapi.json','utf8'));
    const before=structuredClone(baseline),after=structuredClone(d);
    for(const [,method,path] of expected){
      const old=before.paths[path][method],now=after.paths[path][method];
      assert(now.responses['400']);assert(now.responses['400']['x-error-codes'].includes('INTERNAL_ERROR'));
      if(old.responses['400'])same(now.responses['400']['x-error-codes'],[...old.responses['400']['x-error-codes'],'INTERNAL_ERROR']);
      else same(now.responses['400']['x-error-codes'],['INTERNAL_ERROR']);
      delete old.responses['400'];delete now.responses['400'];
    }
    assert.deepEqual(canonical(after),canonical(before));
  });
  raw('matrix-before-checks',{expected:matrix.map(({name,expected})=>({name,expected})),sourceRefs,expectedSha:sha('tests/p25/regression-expectations.ts'),snapshotSha:sha('docs/openapi.json'),counts});
  let passed=0,failed=0;for(const test of matrix){let error=null;try{test.run();passed++;}catch(e){error=String(e);failed++;}raw('case-result',{name:test.name,expected:test.expected,result:error?'FAIL':'PASS',error});}
  raw('summary',{passed,failed,result:failed?'FAIL':'PASS',scope:'contract metadata/schema/validation only; no lifecycle/media/platform/HTTP runtime',counts});if(failed)process.exitCode=1;
}
main().catch(e=>{raw('HARNESS_FAIL',{error:String(e)});process.exitCode=1;});


