'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function validateRecords(rows,writer,{size,sha256}){
 assert.ok(writer.complete&&writer.sealed&&writer.closed&&writer.queued===0&&writer.failure===null);assert.ok(Number.isSafeInteger(writer.accepted)&&writer.accepted>0);assert.equal(writer.accepted,writer.written);assert.equal(rows.length,writer.written);
 rows.forEach((r,i)=>{assert.equal(r.sequence,i+1);assert.ok(Number.isFinite(r.monotonicMs)&&r.monotonicMs>=0);if(i)assert.ok(r.monotonicMs>=rows[i-1].monotonicMs);});
 const native=rows.filter(r=>r.event==='BROWSER_NATIVE_RESPONSE');assert.equal(native.length,1);assert.equal(native[0].status,200);assert.equal(native[0].bytes,size);assert.equal(native[0].sha256,sha256);
 const get=rows.filter(r=>r.event==='HTTP'&&r.kind==='DOWNLOAD'&&r.method==='GET');assert.equal(get.length,1);assert.equal(get[0].status,200);
 const negatives=rows.filter(r=>r.event==='NEGATIVES');assert.equal(negatives.length,1);assert.equal(negatives[0].badCSRF,403);assert.equal(negatives[0].wrongSession,404);
 const transfer=rows.filter(r=>r.event==='API_TRANSFER');assert.equal(transfer.length,1);assert.equal(transfer[0].head,200);assert.equal(transfer[0].get,200);assert.equal(transfer[0].range,206);assert.equal(transfer[0].size,size);assert.equal(transfer[0].sha256,sha256);
 return {rows:rows.length,validJSONL:true,uniqueSequence:true,ordered:true,browserNativeResponses:1,browserGET:1,localAPITransfer:1,browserSave:'UNKNOWN'};
}
function main(root){
 const read=name=>JSON.parse(fs.readFileSync(path.join(root,name),'utf8').replace(/^\uFEFF/,''));
 const gateway=read('gateway-result.json');assert.equal(gateway.status,'PASS_GATEWAY_FIXTURE');
 const cleanup=read('gateway-cleanup.json');assert.equal(cleanup.cancel.status,201);assert.equal(cleanup.cancel.bodyValid,true);assert.ok(cleanup.cleanupOK&&cleanup.closureOK&&cleanup.listenerClosed&&cleanup.secretsCleared);assert.equal(cleanup.incomingSockets+cleanup.outgoingSockets+cleanup.outgoingRequests,0);
 const native=read('cases/happy/prepare.native.json');assert.equal(native.coreExit,0);assert.equal(native.fileExists,true);assert.match(native.sha256,/^[a-f0-9]{64}$/);
 const file=path.join(root,'native-image.jpg'),size=fs.statSync(file).size;assert.ok(size>0&&size<=16*1024*1024);const bytes=fs.readFileSync(file);const sha256=crypto.createHash('sha256').update(bytes).digest('hex');assert.equal(sha256,native.sha256);assert.equal(bytes[0],255);assert.equal(bytes[1],216);assert.equal(gateway.size,size);assert.equal(gateway.sha256,sha256);
 const log=fs.readFileSync(path.join(root,'gateway-events.jsonl'));assert.ok(log.length<=1048576);const lines=log.toString('utf8').split('\n');assert.equal(lines.pop(),'');const rows=lines.map(JSON.parse);
 const coverage=validateRecords(rows,gateway.eventWriter,{size,sha256});assert.deepEqual(cleanup.eventWriter,gateway.eventWriter);
 const before=read('head-before-ack.json'),after=read('head-after-ack.json');assert.equal(before.count,after.count);assert.equal(after.headLeaseUnchanged,true);
 const controller=fs.readFileSync(path.join(root,'controller.jsonl'),'utf8').trim().split('\n').map(JSON.parse);assert.equal(controller.filter(r=>r.event==='BROWSER_SELECTION_CONFIRMED'&&r.index===2).length,1);const closed=controller.filter(r=>r.event==='CLEANUP_COMPLETE');assert.equal(closed.length,1);assert.equal(closed[0].consumerExit,0);assert.equal(closed[0].consumerSignal,null);assert.ok(closed[0].hadJob&&closed[0].mediaRemoved&&closed[0].workerTokenReleased);assert.equal(closed[0].startedLeases,0);
 fs.writeFileSync(path.join(root,'final-gate.json'),JSON.stringify({status:'PASS_FINAL_FIXTURE_GATES',node:process.versions.node,coverage,size,sha256,headLeaseUnchanged:true,selectionIndex:2,browserSave:'UNKNOWN',sourceCalls:0}),{flag:'wx'});
 console.log('{"status":"PASS_FINAL_FIXTURE_GATES"}');
}
module.exports={validateRecords};
if(require.main===module){try{main(process.argv[2]);}catch{console.log('{"status":"FAIL_FINAL_FIXTURE_GATES"}');process.exitCode=1;}}
