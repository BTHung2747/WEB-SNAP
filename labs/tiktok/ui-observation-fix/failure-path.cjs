// Public Node22 HTTP/socket APIs; same functions used by lab gateway and tests.
'use strict';
const assert=require('node:assert/strict');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const STATES=new Set(['analyzing','selectable','queued','preparing','ready','failed','cancelled','expired']);
const TERMINAL=new Set(['failed','cancelled','expired']);
function observeJob(status,v,expectedID){
 assert.equal(status,200);assert.ok(v&&typeof v==='object'&&!Array.isArray(v));
 assert.equal(v.id,expectedID);assert.equal(typeof v.state,'string');assert.ok(STATES.has(v.state));assert.equal(v.previewUrl,null);
 assert.ok(v.errorCode===null||(typeof v.errorCode==='string'&&/^[A-Z][A-Z0-9_]{0,79}$/.test(v.errorCode)));
 assert.ok(Array.isArray(v.items));assert.ok(v.title===null||typeof v.title==='string');assert.ok(v.duration===null||(Number.isFinite(v.duration)&&v.duration>=0));
 for(const key of ['metadataAcceptedAt','metadataExpiresAt'])assert.ok(v[key]===null||(typeof v[key]==='string'&&Number.isFinite(Date.parse(v[key]))));
 assert.equal(v.mode,'temporary');assert.equal(typeof v.serverMeaning,'string');
 if(TERMINAL.has(v.state))assert.equal(v.items.length,0);
 return {state:v.state,previewNull:true,terminal:TERMINAL.has(v.state),primaryCode:v.errorCode||(TERMINAL.has(v.state)?'JOB_'+v.state.toUpperCase():null)};
}
function cancelContract(response){
 const status=Number.isInteger(response?.status)&&response.status>=100&&response.status<=599?response.status:'UNKNOWN';let bodyValid=false;
 try{if(Buffer.isBuffer(response?.bytes)&&response.bytes.length<=256){const b=JSON.parse(response.bytes.toString('utf8'));bodyValid=b!==null&&typeof b==='object'&&!Array.isArray(b)&&Object.keys(b).length===1&&b.ok===true;}}catch{}
 return {outcome:status===201&&bodyValid?'HTTP_201_BODY_OK':status==='UNKNOWN'?'INVALID_STATUS':status!==201?'HTTP_STATUS_REJECTED':'HTTP_BODY_REJECTED',status,bodyValid};
}
function createClosure(){
 const incoming=new Set(),requests=new Set(),outgoing=new Set();let stopping=false,closed=false;
 function trackIncoming(socket){incoming.add(socket);socket.once('close',()=>incoming.delete(socket));if(stopping)socket.destroy();}
 function trackRequest(request){
  requests.add(request);request.once('close',()=>requests.delete(request));
  request.on('socket',socket=>{outgoing.add(socket);socket.once('close',()=>outgoing.delete(socket));if(closed)socket.destroy();});
  if(closed)request.destroy();return request;
 }
 async function cleanup({server,cancel,clearSecrets,secretsEmpty,limitMs=20000,cancelMs=5000}){
  assert.ok(Number.isFinite(limitMs)&&limitMs>0&&limitMs<=20000);assert.ok(Number.isFinite(cancelMs)&&cancelMs>0&&cancelMs<=5000);
  const begin=performance.now(),deadline=begin+limitMs;let listenerCallback=!server||!server.listening;
  const errors=[];let cancelOutcome={outcome:'NOT_ATTEMPTED',status:'UNKNOWN',bodyValid:'UNKNOWN'},timer;
  // Stop ingress before cancel. Failure in any later operation cannot skip finally.
  stopping=true;
  try{
   if(server?.listening)server.close(error=>{listenerCallback=true;if(error)errors.push('LISTENER_CLOSE');});
   if(cancel){
    try{
     const remaining=deadline-performance.now();if(remaining<=0)throw Object.assign(new Error(),{code:'CLEANUP_DEADLINE'});
     const response=await Promise.race([Promise.resolve().then(cancel),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Object.assign(new Error(),{code:'CANCEL_DEADLINE'})),Math.min(cancelMs,remaining));})]);
     cancelOutcome=cancelContract(response);
    }catch(error){cancelOutcome={outcome:error?.code==='CANCEL_DEADLINE'?'TIMEOUT':error?.code==='CLEANUP_DEADLINE'?'DEADLINE':'TRANSPORT_ERROR',status:'UNKNOWN',bodyValid:'UNKNOWN'};}
    finally{clearTimeout(timer);}
   }
  }catch{errors.push('CLEANUP_OPERATION');}
  finally{
   closed=true;
   // Each closure action is independent, even if another action throws.
   try{server?.closeAllConnections();}catch{errors.push('CLOSE_ALL');}
   for(const request of requests)try{request.destroy();}catch{errors.push('REQUEST_DESTROY');}
   for(const socket of [...incoming,...outgoing])try{socket.destroy();}catch{errors.push('SOCKET_DESTROY');}
   try{clearSecrets();}catch{errors.push('SECRET_CLEAR');}
   while((requests.size||incoming.size||outgoing.size||!listenerCallback)&&performance.now()<deadline)await sleep(Math.min(5,Math.max(1,deadline-performance.now())));
  }
  let secretsCleared=false;try{secretsCleared=secretsEmpty()===true;}catch{errors.push('SECRET_CHECK');}
  const receipt={cancel:cancelOutcome,listenerClosed:!server?.listening&&listenerCallback,incomingSockets:incoming.size,outgoingRequests:requests.size,outgoingSockets:outgoing.size,secretsCleared,elapsedMs:Math.round((performance.now()-begin)*1000)/1000,limitMs,deadlineExpired:performance.now()>=deadline,errors};
  receipt.closureOK=receipt.listenerClosed&&receipt.incomingSockets===0&&receipt.outgoingRequests===0&&receipt.outgoingSockets===0&&secretsCleared&&!receipt.deadlineExpired&&!errors.length;
  receipt.cleanupOK=receipt.closureOK&&['HTTP_201_BODY_OK','NOT_ATTEMPTED'].includes(cancelOutcome.outcome);
  return receipt;
 }
 return {trackIncoming,trackRequest,cleanup,get stopping(){return stopping;}};
}
function finalizeResult(primary,receipt){return {...primary,cleanup:receipt,status:primary.status==='PASS_GATEWAY_FIXTURE'&&receipt.cleanupOK?'PASS_GATEWAY_FIXTURE':primary.status==='PASS_GATEWAY_FIXTURE'?'FAIL_GATEWAY_CLEANUP':primary.status};}
module.exports={observeJob,createClosure,finalizeResult,cancelContract};
