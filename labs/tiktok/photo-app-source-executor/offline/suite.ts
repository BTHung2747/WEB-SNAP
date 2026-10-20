import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {runWorkflow,closeConnections} from '/lab/workflow';
const OUT='/control',URL='https://www.tiktok.com/@fixture/photo/7000000000000000001';
async function main(){
 assert.equal(process.env.STEP5_EXECUTE_SOURCE,undefined);assert.equal(process.env.STEP5_OFFLINE_TEST,'1');
 const cases=[];
 for(const name of ['happy','missing-proof','changed-structure']){
  await writeFile(OUT+'/mode.json',JSON.stringify({mode:name}));
  const result=await runWorkflow({mode:'offline',case:name,url:URL,expectation:'/offline/expectation.json'});
  if(name==='happy'){assert.equal(result.status,'PASS_TECHNICAL_NEEDS_VISUAL_REVIEW');assert.equal(result.attempts,5);assert.equal(result.imageAttempts,1);assert.equal(result.size,248);}
  else{assert.equal(result.status,'FAIL_STOPPED');assert.equal(result.failedStage,name==='missing-proof'?'ANALYZE':'SELECTION');}
  cases.push({case:name,status:result.status,jobId:result.jobId,code:result.code||null});
  if(name==='happy'){
   const a=JSON.parse(await readFile(OUT+'/cases/happy/analyze.diagnostics.json','utf8')),p=JSON.parse(await readFile(OUT+'/cases/happy/prepare.diagnostics.json','utf8'));
   const currentIDs=new Set(p.diagnostics.requests.map((r:any)=>r.boundaries.requestID)),priorIDs=new Set(a.diagnostics.requests.map((r:any)=>r.boundaries.requestID));
   assert.ok(p.boundaries.every((r:any)=>currentIDs.has(r.requestID)&&!priorIDs.has(r.requestID)));
   assert.ok(a.boundaries.length>0&&p.boundaries.length>0);
  }
 }
 const counts=JSON.parse(await readFile(OUT+'/counts.json','utf8'));assert.equal(counts.metadata,8);assert.equal(counts.JPEG,1);
 await writeFile(OUT+'/offline-result.json',JSON.stringify({status:'PASS_COMMON_SOURCE_EXECUTOR_GLUE_OFFLINE',sourceGrant:false,sourceExecutionStarted:false,sourceCalls:0,cases,fixtureCounts:counts,sourceBranchInvoked:false,browserCombined:false},null,2));
 console.log('PASS source-executor common workflow',cases.length);
}
main().catch(async()=>{await writeFile(OUT+'/failure.json',JSON.stringify({code:'OFFLINE_ASSERTION_FAILED'}));process.exitCode=1;}).finally(closeConnections);
