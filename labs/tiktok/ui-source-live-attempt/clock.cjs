'use strict';
// Readiness only: built-in filesystem/crypto/clock APIs, no application imports.
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
assert.notEqual(process.env.STEP5_EXECUTE_SOURCE,'1');
const nonce=process.argv[2],count=Number(process.argv[3]);
assert.match(nonce,/^[a-f0-9]{32}$/);assert.ok(Number.isInteger(count)&&count>0&&count<=256);
const files=[];
for(let i=0;i<count;i++){
 const target='/probe/src/'+String(i).padStart(4,'0');
 files.push({target,sha256:crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex')});
}
console.log(JSON.stringify({mode:'READINESS_ONLY_NO_SOURCE_AUTHORITY',nonce,node:process.versions.node,platform:process.platform,uid:process.getuid(),unixMs:Date.now(),monotonicNs:process.hrtime.bigint().toString(),files}));
