'use strict';
const assert=require('node:assert/strict'),{validateRecords}=require('./final-gate.cjs');const sha='a'.repeat(64),rows=[{event:'BROWSER_NATIVE_RESPONSE',status:200,bytes:248,sha256:sha},{event:'HTTP',kind:'DOWNLOAD',method:'GET',status:200},{event:'NEGATIVES',badCSRF:403,wrongSession:404},{event:'API_TRANSFER',head:200,get:200,range:206,size:248,sha256:sha}].map((r,i)=>({...r,sequence:i+1,monotonicMs:i})),writer={complete:true,sealed:true,closed:true,queued:0,failure:null,accepted:4,written:4};
validateRecords(rows,writer,{size:248,sha256:sha});let rejected=0;
for(const bad of [rows.map(r=>r.event==='HTTP'?{...r,kind:'CONTROL_ONLY'}:r),rows.map(r=>r.event==='BROWSER_NATIVE_RESPONSE'?{...r,event:'CONTROL_ONLY'}:r),rows.map(r=>r.event==='BROWSER_NATIVE_RESPONSE'?{...r,sha256:'b'.repeat(64)}:r),rows.map((r,i)=>i===1?{...r,sequence:1}:r)]){assert.throws(()=>validateRecords(bad,writer,{size:248,sha256:sha}));rejected++;}
assert.throws(()=>validateRecords(rows,{...writer,complete:false},{size:248,sha256:sha}));rejected++;
console.log(JSON.stringify({status:'PASS_FINAL_GATE_UNIT_ONLY',cases:1+rejected,node:process.versions.node}));
