'use strict';
const fs=require('node:fs/promises');
function createEventWriter(path,{queueCap=256,eventCap=4096,byteCap=1048576,rowCap=4096,onFailure=()=>{}}={}){
 let chain=Promise.resolve(),handle,accepted=0,written=0,queued=0,bytes=0,failure=null,sealed=false,closed=false;const begin=performance.now();
 function fail(code){if(!failure){failure=code;try{onFailure(code);}catch{}}}
 function enqueue(row){
  if(sealed){fail('EVENT_AFTER_SEAL');return false;}if(failure)return false;
  if(queued>=queueCap){fail('EVENT_QUEUE_CAP');return false;}if(accepted>=eventCap){fail('EVENT_COUNT_CAP');return false;}
  let data;try{data=Buffer.from(JSON.stringify({...row,sequence:accepted+1,monotonicMs:Math.round((performance.now()-begin)*1000)/1000})+'\n');}catch{fail('EVENT_SCHEMA');return false;}
  if(data.length>rowCap||bytes+data.length>byteCap){fail('EVENT_BYTE_CAP');return false;}
  bytes+=data.length;accepted++;queued++;
  chain=chain.then(async()=>{try{handle||=await fs.open(path,'wx');await handle.writeFile(data);written++;}catch{fail('EVENT_WRITE_ERROR');}finally{queued--;}});
  return true;
 }
 async function seal(){
  sealed=true;await chain;
  try{if(handle)await handle.sync();}catch{fail('EVENT_FLUSH_ERROR');}
  finally{try{if(handle)await handle.close();closed=true;}catch{fail('EVENT_CLOSE_ERROR');}}
  if(failure)throw Object.assign(new Error(),{code:failure});return snapshot();
 }
 function snapshot(){return{accepted,written,queued,bytes,failure,sealed,closed,complete:sealed&&closed&&!failure&&accepted===written};}
 return{enqueue,seal,snapshot,get failure(){return failure;}};
}
async function finalizeObserved(primary,cleanup,writer){
 // Callers close sockets before this; writer failure cannot bypass cleanup.
 try{await writer.seal();}catch{}
 const eventWriter=writer.snapshot();return {...primary,cleanup,eventWriter,status:primary.status==='PASS_GATEWAY_FIXTURE'&&(!cleanup.cleanupOK||!eventWriter.complete)?'FAIL_FINAL_GUARDS':primary.status};
}
module.exports={createEventWriter,finalizeObserved};
