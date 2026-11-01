// Pure fake broker, reused EventEmitter pattern from source-quality test_pair.cjs.
// Host Node24 public TS transform; no dependencies, sockets, worker or native media.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {EventEmitter}=require('node:events'),http=require('node:http');
const {stripTypeScriptTypes,syncBuiltinESMExports}=require('node:module');
const out=path.resolve(process.argv[2]);const original=http.request;let plan,phase,calls=[];
http.request=(_options,callback)=>{
 const req=new EventEmitter();req.destroy=()=>{};
 req.end=body=>{
  const p=JSON.parse(body);calls.push(p.op);
  const reply={v:1,id:p.id,job:p.job,phase:p.phase,epoch:'e'.repeat(64),state:p.op==='open'?'OPEN':plan.state,
   connections:p.op==='open'?0:plan.connections,...(p.op==='open'?{connectKey:'f'.repeat(64)}:{})};
  if(plan.extra&&p.op==='seal')reply.url='https://fixture.invalid/PATH_SECRET?q=QUERY_SECRET';
  process.nextTick(()=>{const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{};callback(res);
   if(plan.expire&&p.op==='seal')phase.deadline=performance.now()-1; // Test clock boundary after request guard.
   res.emit('data',Buffer.from(JSON.stringify(reply)));res.emit('end');});
 };return req;
};
syncBuiltinESMExports();
const core='data:text/javascript,'+encodeURIComponent('export class AppError extends Error {constructor(code){super(code);this.code=code;}}');
const file=path.resolve('apps/worker/src/proxy-phase.ts'),source=fs.readFileSync(file,'utf8');
assert(source.includes("from '../../../packages/shared/src/core'"));
const code=stripTypeScriptTypes(source.replace("from '../../../packages/shared/src/core'",'from '+JSON.stringify(core)),{mode:'transform'});
process.env.TIKTOK_EGRESS_POLICY_ENABLED='1';process.env.TIKTOK_EGRESS_CONTROL_SECRET='a'.repeat(64);
(async()=>{
 const {ProxyPhase,ProxyProofError,proxyFinishObservation}=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
 const cases=[];
 for(const sample of [
  {name:'broker-rejected',state:'REJECTED',connections:1,stopped:false},
  {name:'accepted-with-zero-connections',state:'ACCEPTED',connections:0,stopped:false},
  {name:'local-stopped',state:'ACCEPTED',connections:1,stopped:true},
  {name:'deadline-after-reply',state:'ACCEPTED',connections:1,stopped:false,expire:true},
 ]){
  plan=sample;calls=[];phase=await ProxyPhase.open('analyze','fake-job','fake-worker',performance.now()+30000);
  let error;try{await phase.finish(()=>sample.stopped);}catch(e){error=e;}
  assert(error instanceof ProxyProofError);assert.equal(error.reason,'REJECTED');
  const observation=proxyFinishObservation(error);
  assert.deepEqual(observation,{brokerState:sample.state,connections:sample.connections,stopped:sample.stopped,deadlineExceeded:!!sample.expire,observationTiming:'AFTER_GUARD'});
  assert.deepEqual(calls,['open','seal']); // No take after refusal; acceptance unchanged.
  cases.push({name:sample.name,code:error.reason,...observation});
 }
 plan={state:'ACCEPTED',connections:1};calls=[];phase=await ProxyPhase.open('analyze','fake-job','fake-worker',performance.now()+30000);
 assert.equal(await phase.finish(()=>false),1);assert.deepEqual(calls,['open','seal','take']);cases.push({name:'accepted-control-unchanged'});
 plan={state:'REJECTED',connections:1};phase=await ProxyPhase.open('analyze','fake-job','fake-worker',performance.now()+30000);
 let stopReads=0,error;try{await phase.finish(()=>++stopReads>0);}catch(e){error=e;}
 assert.equal(stopReads,1);assert.equal(proxyFinishObservation(error).stopped,true); // Read after short-circuit guard.
 cases.push({name:'snapshot-after-guard-explicit'});
 const malformed=new ProxyProofError('REJECTED',{brokerState:'https://fixture.invalid/PATH_SECRET',connections:1,stopped:false,deadlineExceeded:false});
 assert.deepEqual(proxyFinishObservation(malformed),{});
 const forged=new ProxyProofError('REJECTED',{brokerState:'REJECTED',connections:1,stopped:false,deadlineExceeded:false,url:'PATH_SECRET',headers:'QUERY_SECRET'});
 const event={event:'proxy_phase_gate',id:'fake-job',phase:'analyze',accepted:false,code:forged.reason,...proxyFinishObservation(forged)};
 assert(!JSON.stringify(event).includes('SECRET'));assert.deepEqual(proxyFinishObservation(new Error('PATH_SECRET')),{});
 const adapter=fs.readFileSync(path.resolve('apps/worker/src/adapter.ts'),'utf8');
 assert(adapter.includes("event: 'proxy_phase_gate', id, phase, accepted: false"));assert(adapter.includes('...proxyFinishObservation(error)'));
 cases.push({name:'fixed-field-serialization-and-adapter-failurelog-wiring'});
 fs.writeFileSync(path.join(out,'worker-result.json'),JSON.stringify({status:'PASS',node:process.version,cases,realSockets:0,nativeWorkerMedia:0,sourceRequests:0,core:'AppError fixture only',transport:'fake HTTP EventEmitter',parentProcessGroup:'NOT_RUN'},null,2));
 console.log('PASS worker finish observation '+cases.length+' focused cases');
})().catch(e=>{console.error('FINISH_OBSERVATION_FAILED '+e.constructor.name);process.exitCode=1;})
.finally(()=>{http.request=original;syncBuiltinESMExports();});
