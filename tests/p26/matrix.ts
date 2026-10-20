import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {RequestMethod} from '@nestjs/common';
import {generated,canonical,raw,sha} from './bootstrap';
import {operations,bounds,id,campaign,limits,schemaNames,adsErrors} from './expectations';
const same=(a:any,b:any)=>assert.deepEqual([...a].sort(),[...b].sort());
async function main(){
  const {doc,counts,routes,validation,core,eventSchema,enabledRejected,placement,framework,models}=await generated();const d:any=doc;
  const cases:{name:string;expected:string;run:()=>void}[]=[];const add=(name:string,expected:string,run:()=>void)=>cases.push({name,expected,run});
  const resolve=(s:any):any=>{assert(s,'schema required');return s.$ref?resolve(d.components.schemas[s.$ref.split('/').at(-1)]):s;};
  function accepts(schema:any,value:any){const s=resolve(schema);if(value===null){assert(s.nullable,'nullable required');return;}if(s.allOf)s.allOf.forEach((v:any)=>accepts(v,value));if(s.enum)assert(s.enum.includes(value));
    if(s.type==='object'){assert(value&&typeof value==='object'&&!Array.isArray(value));for(const k of s.required||[])assert(k in value,'missing '+k);for(const [k,v]of Object.entries(value)){if(s.additionalProperties===false)assert(k in s.properties,'unknown '+k);if(s.properties?.[k])accepts(s.properties[k],v);}}
    if(s.type==='array'){assert(Array.isArray(value));if(s.maxItems!==undefined)assert(value.length<=s.maxItems);value.forEach(v=>accepts(s.items,v));}
    if(s.type==='string'){assert.equal(typeof value,'string');if(s.minLength!==undefined)assert(value.length>=s.minLength);if(s.maxLength!==undefined)assert(value.length<=s.maxLength);if(s.pattern)assert(new RegExp(s.pattern).test(value));if(s.format==='uuid')assert(/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(value));if(s.format==='date-time')assert(Number.isFinite(Date.parse(value))&&value.includes('T'));if(s.format==='email')assert(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value));if(s.format==='uri')assert.doesNotThrow(()=>new URL(value));}
    if(s.type==='integer'||s.type==='number'){assert.equal(typeof value,'number');assert(Number.isFinite(value));if(s.type==='integer')assert(Number.isInteger(value));if(s.minimum!==undefined)assert(value>=s.minimum);if(s.maximum!==undefined)assert(value<=s.maximum);}
    if(s.type==='boolean')assert.equal(typeof value,'boolean');
  }
  const json=(o:any,status:number)=>o.responses[String(status)].content?.['application/json']?.schema;
  const body=(o:any)=>resolve(o.requestBody.content['application/json'].schema);
  const campaignOutput={id,...campaign};const ad={id,title:campaign.title,imageUrl:null,targetUrl:campaign.targetUrl,linkType:'legacy-imported-link',placement:'banner'};
  const dashboard={groups:[{state:'legacy-state',_count:2}],leases:[{state:'legacy-lease',_count:1,_sum:{bytes:'9007199254740993'}}],budget:[{month:'2026-10',charged:'9007199254740993'}],failed:[{id,platform:'legacy-platform',errorCode:null,updatedAt:new Date('2026-10-03T00:00:00Z').toJSON()}],events:[{campaignId:id,type:'legacy-event',_count:3}],queue:{waiting:0,active:1},verified:['youtube']};
  for(const [name,method,path,status,schema,branchErrors,auth]of operations)add('operation-'+name,'source-derived success/status/request/security/AppError profile; default framework envelope not HTTP parser proof',()=>{
    const o=d.paths[path]?.[method];assert(o);const errors:any={...(name==='ads'?adsErrors:branchErrors),500:['INTERNAL_ERROR']};same(Object.keys(o.responses),[String(status),...Object.keys(errors),'default']);assert.equal(json(o,status).$ref,'#/components/schemas/'+schema);
    const response=o.responses[String(status)];assert.equal(response.headers['Cache-Control'].schema.enum[0],'no-store');
    for(const [code,allowed]of Object.entries(errors)){const r=o.responses[code];same(r['x-app-error-codes'],allowed);for(const c of allowed as string[])accepts(r.content['application/json'].schema,{error:{code:c}});assert.throws(()=>accepts(r.content['application/json'].schema,{error:{code:'INTERNAL_ERROR',message:'private'}}));}
    accepts(o.responses.default.content['application/json'].schema,{error:{code:'INTERNAL_ERROR'}});assert(o.responses.default.description.includes('HttpException'));assert(!o.responses['404']||name==='ad-event','no invented missing-row404');
    if(auth==='guest')assert.deepEqual(o.security,[{cookie:[]}]);else if(auth==='admin')assert.deepEqual(o.security,[{adminCookie:[]}]);else{
      const admin=auth.startsWith('admin'),fallback=auth.endsWith('fallback');const primary={cookie:[],csrf:[],...(admin?{adminCookie:[]}:{})};assert.deepEqual(o.security,fallback?[primary,{cookie:[],...(admin?{adminCookie:[]}:{})}]:[primary]);
      const headers=o.parameters||[];assert.equal(headers.find((p:any)=>p.in==='header'&&p.name==='Origin')?.required,true);assert.equal(headers.find((p:any)=>p.name==='x-csrf-token')?.required,!fallback);
      if(fallback){same(o['x-csrf-alternatives'],['header:x-csrf-token','body:csrf']);assert(o.description.includes('body')&&o.description.includes('bắt buộc'));assert(body(o).properties.csrf);}
      else{assert(body(o).additionalProperties===false);assert(!body(o).properties.csrf);assert.equal(o.requestBody.required,true);}
    }
    if(method==='get')assert(!(o.parameters||[]).some((p:any)=>p.in==='header'&&(p.name==='Origin'||p.name==='x-csrf-token')));
    if(path.includes('{id}')){const p=o.parameters.find((p:any)=>p.in==='path'&&p.name==='id');assert(p.required);assert.equal(p.schema.format,'uuid');}
    if(name==='ads'){accepts(json(o,status),ad);accepts(json(o,status),null);assert(o.parameters.some((p:any)=>p.name==='placement'&&p.in==='query'&&!p.required));}
    else if(schema==='OkResponse')accepts(json(o,status),{ok:true});else if(schema==='AdminLimits')accepts(json(o,status),limits);else if(schema==='AdminCampaign')accepts(json(o,status),campaignOutput);else if(schema==='AdminCampaignList')accepts(json(o,status),[campaignOutput]);else if(schema==='AdminDashboard')accepts(json(o,status),dashboard);
    if(name==='login'||name==='logout'){assert(response.headers['Set-Cookie']);assert(!o.security.some((s:any)=>s.adminCookie));}
  });
  add('limits17-production-boundaries','17required strict fields; all15 integer min/max-1/min/max/max+1/fraction boundaries match actual limitsSchema.safeParse',()=>{
    const s=resolve(d.components.schemas.AdminLimits);same(s.required,[...Object.keys(bounds),'acceptJobs','enabledPlatforms']);same(Object.keys(s.properties),s.required);assert.equal(s.additionalProperties,false);let compared=0;
    for(const [key,[min,max]]of Object.entries(bounds)){const p=s.properties[key];assert.equal(p.type,'integer');assert.equal(p.minimum,min);assert.equal(p.maximum,max);for(const v of [min-1,min,min+0.5,max,max+1]){const payload={...limits,[key]:v};let accepted=true;try{accepts(s,payload);}catch{accepted=false;}const actual=core.limitsSchema.safeParse(payload).success;assert.equal(accepted,actual,key+'='+v);compared++;}}
    for(const payload of [{...limits,extra:true},{...limits,csrf:'x'},{...limits,acceptJobs:'true'},{...limits,enabledPlatforms:['invalid']},{...limits,enabledPlatforms:Array(5).fill('youtube')}]){assert(!core.limitsSchema.safeParse(payload).success);assert.throws(()=>accepts(s,payload));compared++;}
    for(const key of s.required){const missing:any={...limits};delete missing[key];assert(!core.limitsSchema.safeParse(missing).success);assert.throws(()=>accepts(s,missing));compared++;}
    raw('validation-boundaries',{name:'limits',compared,validator:'production limitsSchema.safeParse',counts});
  });
  add('login-production-boundaries','strict login emailmax254/password12..256 vs actual loginSchema; csrf extra rejected',()=>{
    const s=resolve(d.components.schemas.AdminLoginInput);assert.equal(s.additionalProperties,false);assert.equal(s.properties.email.format,'email');assert.equal(s.properties.email.maxLength,254);assert.equal(s.properties.password.minLength,12);assert.equal(s.properties.password.maxLength,256);
    const fixtures=[{email:'docs@example.invalid',password:'x'.repeat(12)},{email:'docs@example.invalid',password:'x'.repeat(256)},{email:'docs@example.invalid',password:'x'.repeat(11)},{email:'docs@example.invalid',password:'x'.repeat(257)},{email:'broken',password:'x'.repeat(12)},{email:'a'.repeat(241)+'@example.test',password:'x'.repeat(12)},{email:'a'.repeat(242)+'@example.test',password:'x'.repeat(12)},{email:'docs@example.invalid',password:'x'.repeat(12),csrf:'fixture'}];
    for(const payload of fixtures){let accepted=true;try{accepts(s,payload);}catch{accepted=false;}assert.equal(accepted,validation.loginSchema.safeParse(payload).success);}
    raw('validation-boundaries',{name:'login',compared:fixtures.length,values:'public fixture; passwords not logged',counts});
  });
  add('campaign-production-boundaries','title1..120/weight integer1..100/enums/optional-nullimage/strict body match production campaignSchema; schedule/HTTPS handled separately',()=>{
    const s=resolve(d.components.schemas.AdminCampaignInput);assert.equal(s.additionalProperties,false);assert(!s.required.includes('imageUrl'));assert.equal(s.properties.imageUrl.nullable,true);assert.equal(s.properties.title.minLength,1);assert.equal(s.properties.title.maxLength,120);assert.equal(s.properties.weight.minimum,1);assert.equal(s.properties.weight.maximum,100);
    const fixtures:any[]=[campaign,{...campaign,imageUrl:undefined},{...campaign,imageUrl:'https://example.invalid/image'}];delete fixtures[1].imageUrl;
    for(const title of ['', 'x','x'.repeat(120),'x'.repeat(121)])fixtures.push({...campaign,title});for(const weight of [0,1,100,101,1.5])fixtures.push({...campaign,weight});for(const changes of [{placement:'other'},{linkType:'other'},{enabled:'true'},{csrf:'fixture'},{extra:1}])fixtures.push({...campaign,...changes});
    for(const payload of fixtures){let accepted=true;try{accepts(s,payload);}catch{accepted=false;}assert.equal(accepted,validation.campaignSchema.safeParse(payload).success);}
    raw('validation-boundaries',{name:'campaign-structural',compared:fixtures.length,validator:'production campaignSchema.safeParse',counts});
  });
  add('campaign-HTTPS-and-crossfield','production HTTPS refinement and schedule relation tested; OpenAPI3 extensions describe limits, no cloned validator',()=>{
    const s=resolve(d.components.schemas.AdminCampaignInput);assert.equal(s.properties.targetUrl.maxLength,2048);assert(s['x-production-refinements'].includes('startsAt < endsAt'));assert(s.properties.targetUrl.description.includes('HTTPS'));
    for(const [url,ok]of [['https://example.invalid/a',true],['HTTPS://example.invalid/a',true],['https://example.invalid:443/a',true],['http://example.invalid/a',false],['https://user@example.invalid/a',false],['https://example.invalid:444/a',false],['https://127.0.0.1/a',false],['https://10.0.0.1/a',false],['https://192.168.1.1/a',false],['https://[::1]/a',false],['https://169.254.1.1/a',false],['https://localhost/a',false]] as const){assert.equal(validation.httpsUrl.safeParse(url).success,ok);assert.equal(validation.campaignSchema.safeParse({...campaign,targetUrl:url}).success,ok);}
    const prefix='https://example.invalid/a?x=';for(const length of [2048,2049])assert.equal(validation.httpsUrl.safeParse(prefix+'x'.repeat(length-prefix.length)).success,length===2048);
    for(const endsAt of [campaign.startsAt,'2026-10-02T00:00:00.000Z']){const payload={...campaign,endsAt};accepts(s,payload);assert(!validation.campaignSchema.safeParse(payload).success,'cross-field production rejects despite structural schema');}
    assert(!validation.campaignSchema.safeParse({...campaign,startsAt:'not-date'}).success);raw('validation-refinements',{name:'HTTPS/schedule',schemaLimit:'OpenAPI3 structural schema cannot enforce all production refinements',counts});
  });
  add('event-production-inline-validator','exact AST-selected production adEvent parse schema, UUID/type/strict fixtures; no copied Zod definition',()=>{
    const s=resolve(d.components.schemas.AdEventInput);assert.equal(s.additionalProperties,false);same(s.required,['id','campaignId','type']);same(s.properties.type.enum,['impression','click']);
    const fixture={id,campaignId:id,type:'impression'};for(const changes of [{},{type:'click'},{id:'bad'},{campaignId:'bad'},{type:'view'},{csrf:'fixture'},{extra:true}]){const payload={...fixture,...changes};let accepted=true;try{accepts(s,payload);}catch{accepted=false;}assert.equal(accepted,eventSchema.safeParse(payload).success);}
  });
  add('enabledPlatforms-production-guard','schema enum/max4 strict; actual AST-extracted service predicate rejects unverified even when Zod structurally accepts',()=>{
    const s=resolve(d.components.schemas.AdminLimits);assert.equal(s.properties.enabledPlatforms.maxItems,4);same(s.properties.enabledPlatforms.items.enum,['youtube','tiktok','facebook','x']);assert(s['x-enabled-platforms'].includes('VERIFIED_PLATFORMS'));
    for(const enabledPlatforms of [[],['youtube'],['tiktok'],['youtube','tiktok']]){const payload={...limits,enabledPlatforms};assert(core.limitsSchema.safeParse(payload).success);accepts(s,payload);assert.equal(enabledRejected(payload,['youtube']),enabledPlatforms.includes('tiktok'));}
    assert(d.paths['/api/v1/admin/settings'].put.responses['400']['x-app-error-codes'].includes('PLATFORM_NOT_VERIFIED'));raw('validation-refinements',{name:'enabledPlatforms',scope:'production pure predicate, no AdminService/auth/settings/datastore call',counts});
  });
  add('ads-selection-and-event-policy','exact placement branch/campaign-or-null/600s NX conservative GET/no-campaign-no-claim/banner exempt; UUID event dedupe/rate60',()=>{
    const o=d.paths['/api/v1/ads'].get;const query=o.parameters.find((p:any)=>p.in==='query'&&p.name==='placement');assert(query&&!query.required&&!query.schema.enum);assert.equal(o['x-sponsor-policy'].cooldownSeconds,600);assert.equal(o['x-sponsor-policy'].claim,'Redis SET NX EX');assert.equal(o['x-sponsor-policy'].emptyCampaignConsumes,false);assert.equal(o['x-sponsor-policy'].bannerCooldown,false);
    for(const value of [undefined,'banner','sponsor','other',['sponsor']])assert.equal(placement(value),value==='sponsor'?'sponsor':'banner');accepts(json(o,200),null);
    const event=d.paths['/api/v1/ad-events'].post;assert.equal(event['x-event-policy'].idempotency,'event UUID/createMany skipDuplicates');assert.equal(event['x-event-policy'].rateMax,60);assert.equal(event['x-event-policy'].rateSeconds,60);
  });
  add('outputs-Prisma-serialization-and-persisted-strings','Prisma model fields/types nullability; campaign date serialization and dashboard BigInt strings; persisted strings not narrowed to input enums',()=>{
    const model=models.find((m:any)=>m.name==='AdCampaign');const fields=model.fields.filter((f:any)=>f.kind!=='object');const s=resolve(d.components.schemas.AdminCampaign);same(Object.keys(s.properties),fields.map((f:any)=>f.name));same(s.required,fields.map((f:any)=>f.name));assert.equal(s.properties.imageUrl.nullable,true);
    const legacy={...campaignOutput,linkType:'legacy-link',placement:'legacy-place',startsAt:new Date(campaign.startsAt),endsAt:new Date(campaign.endsAt)};accepts(s,JSON.parse(JSON.stringify(legacy)));assert(!s.properties.linkType.enum&&!s.properties.placement.enum);assert.throws(()=>accepts(s,{...campaignOutput,imageUrl:undefined}));
    accepts(d.components.schemas.AdminDashboard,dashboard);assert.throws(()=>accepts(d.components.schemas.AdminDashboard,{...dashboard,budget:[{month:'2026-10',charged:9007199254740992}]}));assert.throws(()=>accepts(d.components.schemas.AdminDashboard,{...dashboard,leases:[{state:'started',_count:1,_sum:{bytes:1}}]}));
    const budget=models.find((m:any)=>m.name==='EgressBudget');assert.equal(budget.fields.find((f:any)=>f.name==='charged').type,'BigInt');assert.equal(model.fields.find((f:any)=>f.name==='startsAt').type,'DateTime');
    const dash=resolve(d.components.schemas.AdminDashboard);same(Object.keys(dash.properties),['groups','leases','budget','failed','events','queue','verified']);
  });
  add('inventory-real-routes-and-default-status','8targetpaths11ops match actual admin/ads routes; actual cached Nest status method including manual Res;19paths23ops',()=>{
    assert.equal(Object.keys(d.paths).length,19);assert.equal(Object.values(d.paths).reduce((n:number,p:any)=>n+['get','post','head','put','delete'].filter(m=>p[m]).length,0),23);assert.equal(routes.length,11);assert.equal(new Set(operations.map(x=>x[2])).size,8);
    for(const route of routes){const path='/'+route.base+'/'+route.path.replace(/:([^/]+)/g,'{$1}');const method=RequestMethod[route.method].toLowerCase();const expected=operations.find(x=>x[1]===method&&x[2]===path);assert(expected);assert.equal(d.paths[path][method].operationId,route.controller+'_'+route.handler);assert.equal(expected[3],route.httpCode??framework.getStatusByMethod(route.method));}
  });
  add('refs-unique-security','all refs resolve, unique operation/params/security alternatives, same existing cookie schemes',()=>{
    const walk=(v:any)=>{if(!v||typeof v!=='object')return;if(v.$ref){let target:any=d;assert(v.$ref.startsWith('#/'));for(const k of v.$ref.slice(2).split('/'))target=target?.[k.replace(/~1/g,'/').replace(/~0/g,'~')];assert(target,'unresolved ref');}Object.values(v).forEach(walk);};walk(d);const ids=new Set();
    for(const path of Object.values(d.paths)as any[])for(const method of ['get','head','post','put','delete']){const o=path[method];if(!o)continue;assert(!ids.has(o.operationId));ids.add(o.operationId);const params=(o.parameters||[]).map((p:any)=>p.in+':'+p.name);assert.equal(new Set(params).size,params.length);const security=(o.security||[]).map((s:any)=>JSON.stringify(canonical(s)));assert.equal(new Set(security).size,security.length);}
  });
  add('public12-schema-security-canonical-preservation','public11paths12ops/12oldschemas/security definitions unchanged; only8targetpaths and8newschemas may differ',()=>{
    const before=JSON.parse(readFileSync('tests/p26/baseline.openapi.json','utf8'));const target=new Set(operations.map(x=>x[2]));for(const [path,value]of Object.entries(before.paths))if(!target.has(path as any))assert.deepEqual(canonical(d.paths[path]),canonical(value));for(const [name,schema]of Object.entries(before.components.schemas))assert.deepEqual(canonical(d.components.schemas[name]),canonical(schema));assert.deepEqual(canonical(d.components.securitySchemes),canonical(before.components.securitySchemes));same(Object.keys(d.components.schemas),[...Object.keys(before.components.schemas),...schemaNames]);
    const normalized=structuredClone(d);for(const path of target)normalized.paths[path]=before.paths[path];for(const name of schemaNames)delete normalized.components.schemas[name];assert.deepEqual(canonical(normalized),canonical(before));
  });
  add('normalized-snapshot','canonical snapshot equals factory/controllers Swagger; no manual JSON source',()=>assert.deepEqual(canonical(d),canonical(JSON.parse(readFileSync('docs/openapi.json','utf8')))));
  raw('matrix-before-checks',{expected:cases.map(({name,expected})=>({name,expected})),expectedSha:sha('tests/p26/expectations.ts'),counts,scope:'metadata/schema fixtures + pure production validators/AST predicates, no HTTP/datastore/business success'});let passed=0,failed=0;
  for(const test of cases){let error=null;try{test.run();passed++;}catch(e){error=String(e);failed++;}raw('case-result',{name:test.name,expected:test.expected,result:error?'FAIL':'PASS',error});}raw('summary',{passed,failed,result:failed?'FAIL':'PASS',counts,scope:'contract/pure validator only; not11 HTTP business success'});if(failed)process.exitCode=1;
}
main().catch(e=>{raw('HARNESS_FAIL',{error:String(e)});process.exitCode=1;});
