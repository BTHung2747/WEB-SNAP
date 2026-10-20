'use strict';
// Lab coordination contract only. Photo schemas and transport remain in the app.
const assert=require('node:assert/strict'),crypto=require('node:crypto'),fs=require('node:fs/promises');
const ORIGIN='http://127.0.0.1:5206';
const BUDGET=Object.freeze(require('./budget-policy.json')),validated=new WeakSet(),runtimeWindows=new WeakMap();
const keys=['schema','mode','runID','origin','path','approvedURL','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs'];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const ns=v=>{assert.match(v,/^[1-9][0-9]{0,19}$/);return BigInt(v);};
function validateContract(c,{offline=false,now=process.hrtime.bigint(),checkOwnerClock=true}={}){
 assert.deepEqual(Object.keys(c).sort(),[...keys].sort());assert.equal(c.schema,'wed-ui-photo-source-contract-v1');
 assert.equal(c.mode,offline?'OFFLINE_TEST_ONLY':'UI_SINGLE_PHOTO_SOURCE');
 assert.match(c.runID,offline?/^OFFLINE_TEST_ONLY_[A-Z0-9_]{1,40}$/:/^[a-f0-9]{32}$/);
 assert.equal(c.origin,ORIGIN);assert.equal(c.path,'/');assert.match(c.expectedPostID,/^[0-9]{15,22}$/);
 assert.ok(Number.isInteger(c.selectedIndex)&&c.selectedIndex>=1&&c.selectedIndex<=50);
 assert.equal(typeof c.approvedURL,'string');assert.ok(c.approvedURL.length<=512);
 for(const k of ['decisionSHA256','budgetSHA256'])assert.match(c[k],/^[a-f0-9]{64}$/);
 const [a,b,d,e]=['startMonoNs','observationDeadlineMonoNs','cleanupDeadlineMonoNs','runDeadlineMonoNs'].map(k=>ns(c[k]));
 assert.ok((!checkOwnerClock||(a<=now&&now<b))&&a<b&&b<d&&d<e&&e-a<=480000000000n&&d-b>=20000000000n&&e-d>=1000000000n);
 return Object.freeze({...c});
}
function validateInputs(c,decisionRaw,budgetRaw,photos,{offline=false,now,wallNow=Date.now(),checkOwnerClock=true}={}){
 const checked=validateContract(c,{offline,now,checkOwnerClock});
 assert.equal(hash(decisionRaw),c.decisionSHA256);assert.equal(hash(budgetRaw),c.budgetSHA256);
 assert.deepEqual(JSON.parse(budgetRaw),BUDGET);
 const d=JSON.parse(decisionRaw);
 assert.deepEqual(Object.keys(d).sort(),['schema','mode','state','runID','approvedURL','expectedPostID','selectedIndex','budgetSHA256','expiresAt'].sort());
 assert.equal(d.schema,'wed-ui-photo-source-decision-v1');assert.equal(d.mode,c.mode);
 assert.equal(d.state,offline?'OFFLINE_TEST_ONLY':'APPROVED_NEW');
 for(const k of ['runID','approvedURL','expectedPostID','selectedIndex','budgetSHA256'])assert.equal(d[k],c[k]);
 assert.ok(typeof d.expiresAt==='string'&&Number.isFinite(Date.parse(d.expiresAt))&&Date.parse(d.expiresAt)>wallNow);
 if(photos)assert.equal(photos.photoPostId(c.approvedURL),c.expectedPostID);
 if(!checkOwnerClock)runtimeWindows.set(checked,calculateRuntimeWindow(c,d.expiresAt,{wallNow}));
 validated.add(checked);return checked;
}
async function readLimited(path){
 const h=await fs.open(path,'r');try{const stat=await h.stat();assert.ok(stat.isFile()&&stat.size<=16384);const b=Buffer.alloc(16385);const {bytesRead}=await h.read(b,0,b.length,0);assert.ok(bytesRead<=16384&&bytesRead===stat.size);return b.subarray(0,bytesRead);}finally{await h.close();}
}
async function runtimeContract(photos,env=process.env){
 // Reject mode before filesystem imports, DB, spawn, listening, or HTTP.
 assert.equal(env.STEP5_EXECUTE_SOURCE,'1');assert.equal(env.STEP5_OFFLINE_TEST,undefined);
 const c=JSON.parse(await readLimited('/control/browser-contract.json'));
 return validateInputs(c,await readLimited('/control/source-decision.json'),await readLimited('/control/source-budget.json'),photos,{checkOwnerClock:false});
}
function binding(c){return Object.fromEntries(['mode','runID','origin','path','expectedPostID','selectedIndex','decisionSHA256','budgetSHA256','observationDeadlineMonoNs'].map(k=>[k,c[k]]));}
function assertBinding(c,value){assert.deepEqual(value,binding(c));}
function calculateRuntimeWindow(c,expiresAt,{wallNow=Date.now(),monoNow=process.hrtime.bigint()}={}){
 // Owner QPC and Linux CLOCK_MONOTONIC are different clock domains.
 // expiresAt binds the owner run's UTC end; convert only remaining durations.
 const wallLeft=Date.parse(expiresAt)-wallNow;assert.ok(Number.isFinite(wallLeft)&&wallLeft>0&&wallLeft<=480000);
 const left=BigInt(Math.floor(wallLeft))*1000000n,span=ns(c.runDeadlineMonoNs)-ns(c.startMonoNs);
 const run=monoNow+(left<span?left:span),observation=run-(ns(c.runDeadlineMonoNs)-ns(c.observationDeadlineMonoNs)),cleanup=run-(ns(c.runDeadlineMonoNs)-ns(c.cleanupDeadlineMonoNs));
 assert.ok(observation>monoNow);return {observation,cleanup,run};
}
function remainingSeconds(c,phase='observation'){const w=runtimeWindows.get(c);assert.ok(w&&['observation','cleanup','run'].includes(phase));return Number(w[phase]-process.hrtime.bigint())/1e9;}
function assertValidated(c,{offline=false}={}){assert.ok(c&&validated.has(c),'AUTHORITY_NOT_VALIDATED');const foreign=runtimeWindows.has(c);validateContract(c,{offline,checkOwnerClock:!foreign});if(foreign)assert.ok(remainingSeconds(c)>0);}
module.exports={ORIGIN,BUDGET,hash,ns,validateContract,validateInputs,runtimeContract,readLimited,binding,assertBinding,assertValidated,calculateRuntimeWindow,remainingSeconds};
