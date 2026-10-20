import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { withLab,raw,sha,canonical } from './bootstrap';
import { filterCases,targets,parserPolicy,scope,id } from './expectations';

async function main(){await withLab(true,async(lab)=>{
  const {doc,counts,port,http,net,SafeErrors,AppError,HttpException}=lab;
  const matrix:{name:string;expected:string;run:()=>Promise<void>|void}[]=[];
  const add=(name:string,expected:string,run:()=>Promise<void>|void)=>matrix.push({name,expected,run});
  const errorCodes=(response:any):string[]=>response?.['x-error-codes']||[];
  const safe=(bytes:Buffer,status:number,code:string)=>{const body=JSON.parse(bytes.toString());assert.deepEqual(body,{error:{code}});assert(!bytes.toString().includes('fixture-private'));assert(status>=400);};
  let order=0;
  async function request(name:string,method:string,path:string,body:string,kind:string){
    const before=counts.datastoreCalls;
    const start=++order,time=Date.now();
    const headers:Record<string,string>={'Content-Type':'application/json','Content-Length':String(Buffer.byteLength(body)),'Origin':'http://p25.invalid','Connection':'close'};
    raw('request-start',{name,kind,order:start,method,path,body,requestBytes:Buffer.byteLength(body),headers,noCookie:true,counts});
    const result:any=await new Promise((resolve,reject)=>{
      const r=http.request({host:'127.0.0.1',port,path,method,headers,agent:false},(response:any)=>{
        const chunks:Buffer[]=[];let size=0;
        response.on('data',(b:Buffer)=>{size+=b.length;if(size>parserPolicy.limits.maxResponseBytes){r.destroy(Error('response bound exceeded'));return;}chunks.push(b);});
        response.on('error',reject);response.on('end',()=>resolve({status:response.statusCode,headers:response.headers,bytes:Buffer.concat(chunks)}));
      });
      r.on('error',reject);r.setTimeout(parserPolicy.limits.timeoutMs,()=>r.destroy(Error('HTTP deadline exceeded')));r.end(body);
    });
    raw('request-finish',{name,kind,startOrder:start,finishOrder:++order,method,path,status:result.status,headers:result.headers,body:result.bytes.toString(),bodyBytes:result.bytes.length,elapsedMs:Date.now()-time,bounds:parserPolicy.limits,counts});
    // An accidental business datastore call is an isolation failure, never a parser verdict.
    if(counts.datastoreCalls!==before)throw Error('HARNESS_ISOLATION datastore call');
    return result;
  }
  for(const [name,kind,status,code] of filterCases)add('filter-'+name,'production SafeErrors '+kind+' -> '+status+'/'+code+' safe envelope',()=>{
    const e=kind==='app'?new AppError(code,status):kind==='http'?new HttpException({message:'fixture-private',path:'fixture-private'},status):Error('fixture-private');
    const recorded:any={status:null,payload:null,destroy:0};const response={headersSent:false,status(n:number){recorded.status=n;return this;},json(v:any){recorded.payload=v;return this;},destroy(){recorded.destroy++;}};
    new SafeErrors().catch(e,{switchToHttp:()=>({getResponse:()=>response})} as any);
    raw('filter-output',{name,class:e.constructor.name,expected:{status,code},recorded});
    assert.deepEqual(recorded,{status,payload:{error:{code}},destroy:0});
  });
  add('filter-headers-sent','production SafeErrors destroys once; no status/json after headersSent',()=>{
    const calls:string[]=[];const res={headersSent:true,status(){calls.push('status');return this;},json(){calls.push('json');},destroy(){calls.push('destroy');}};
    new SafeErrors().catch(new HttpException('fixture-private',400),{switchToHttp:()=>({getResponse:()=>res})} as any);
    raw('filter-output',{name:'headersSent',calls});assert.deepEqual(calls,['destroy']);
  });
  add('docs-filter-classification','API distinguishes AppError/HttpException.getStatus404NOT_FOUND/unknown500, no universal non-AppError500 claim',()=>{
    const text=readFileSync('docs/API.md','utf8');assert(text.includes('HttpException')&&text.includes('getStatus')&&text.includes('NOT_FOUND'),'F25.1: docs omit preserved HttpException status/classifier');
    assert(!text.includes('Safe error không phải AppError trả500/INTERNAL'),'F25.1: universal non-AppError500 assertion');
  });
  for(const [name,method,path,wire]of targets)add('json-'+name,'real malformed JSON; measured400or500/INTERNAL_ERROR must be documented at exact operation; HEAD empty',async()=>{
    const r=await request('json-'+name,method,wire,'{"url":','malformed-json');
    assert(parserPolicy.malformedJson.allowedObservedStatuses.includes(r.status));
    assert.equal(r.headers['cache-control'],parserPolicy.headers.cache);assert.equal(r.headers['x-content-type-options'],parserPolicy.headers.helmet);
    assert(r.headers['content-type'].startsWith(parserPolicy.headers.contentType));
    if(method==='HEAD')assert.equal(r.bytes.length,0);else safe(r.bytes,r.status,parserPolicy.malformedJson.code);
    const response=doc.paths[path][method.toLowerCase()].responses[String(r.status)];
    assert(response,'observed status missing from contract '+r.status);assert(errorCodes(response).includes('INTERNAL_ERROR'),'observed parser INTERNAL_ERROR absent in '+r.status);
    if(method==='HEAD')assert(!response.content);
  });
  for(const [name,method,path,wire]of targets.filter(t=>t[2].includes('{')))add('uri-'+name,'real URI decode error before controller; measured400or500/INTERNAL_ERROR documented; no database',async()=>{
    const uri=wire.replace(path.includes('{id}')?id:'a'.repeat(64),'%E0%A4%A');
    const r=await request('uri-'+name,method,uri,'','malformed-uri');
    assert(parserPolicy.malformedUri.allowedObservedStatuses.includes(r.status));assert.equal(r.headers['cache-control'],'no-store');assert.equal(r.headers['x-content-type-options'],'nosniff');
    if(method==='HEAD')assert.equal(r.bytes.length,0);else safe(r.bytes,r.status,'INTERNAL_ERROR');
    const response=doc.paths[path][method.toLowerCase()].responses[String(r.status)];assert(response,'observed URI status missing');assert(errorCodes(response).includes('INTERNAL_ERROR'),'URI INTERNAL_ERROR absent');
  });
  for(const [name,method,path,wire]of targets.filter(t=>t[0]!=='health'&&t[0]!=='session'))add('control-'+name,'valid JSON/UUID without cookie ->403SESSION_REQUIRED before datastore; HEAD zero wire bytes',async()=>{
    const payload=method==='POST'?name==='analyze'?'{"url":"https://www.youtube.com/watch?v=fixture"}':name==='prepare'?JSON.stringify({itemId:id,formatId:'137',idempotencyKey:id}):'{}':'';
    const r=await request('control-'+name,method,wire,payload,'no-cookie');assert.equal(r.status,403);assert.equal(r.headers['cache-control'],'no-store');
    if(method==='HEAD')assert.equal(r.bytes.length,0);else safe(r.bytes,403,'SESSION_REQUIRED');
    assert(errorCodes(doc.paths[path][method.toLowerCase()].responses['403']).includes('SESSION_REQUIRED'));assert.equal(counts.datastoreCalls,0);
  });
  add('framework-not-found-control','unmatched lab GET404/NOT_FOUND; no invented existing-operation404 branch',async()=>{
    const r=await request('framework-not-found-control','GET','/api/v1/p25-unmatched-route','','not-found');assert.equal(r.status,404);safe(r.bytes,404,'NOT_FOUND');
  });
  add('io-deny-controls','second server/localhost/other port denied before native I/O; only1listen/exact loopback dials',()=>{
    assert.throws(()=>http.createServer().listen(0,'127.0.0.1'),/Forbidden listen/);
    const s=new net.Socket();try{assert.throws(()=>s.connect({host:'127.0.0.1',port:9}),/Forbidden dial/);assert.throws(()=>s.connect({host:'localhost',port}),/Forbidden dial/);}finally{s.destroy();}
    assert.equal(counts.allowedListens,1);assert.equal(counts.deniedListens,1);assert.equal(counts.deniedDials,2);assert.equal(counts.datastoreCalls,0);
  });
  raw('matrix-before-checks',{expected:matrix.map(({name,expected})=>({name,expected})),expectedSha:sha('tests/p25/expectations.ts'),parserPolicy,scope,counts});
  let passed=0,failed=0;
  for(const test of matrix){let error=null;try{await test.run();passed++;}catch(e){if(counts.datastoreCalls>0||String(e).includes('HARNESS_ISOLATION'))throw e;error=String(e);failed++;}raw('case-result',{name:test.name,expected:test.expected,result:error?'FAIL':'PASS',error});}
  raw('summary',{passed,failed,result:failed?'FAIL':'PASS',scope,counts});if(failed)process.exitCode=1;
});}
main().catch(e=>{raw('HARNESS_FAIL',{error:String(e)});process.exitCode=1;});
