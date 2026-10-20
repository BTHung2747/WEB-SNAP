'use strict';
const http=require('node:http'),net=require('node:net'),assert=require('node:assert/strict'),fs=require('node:fs');
const {observeJob,createClosure,finalizeResult}=require('./failure-path.cjs');
const OUT='/control',rows=[];const id='11111111-1111-4111-8111-111111111111';
const listen=s=>new Promise(r=>s.listen(0,'127.0.0.1',r));
async function close(s){await new Promise(r=>{s.close(r);s.closeAllConnections();});}
async function cleanupCase(mode,status){
 const closure=createClosure(),upstreamSockets=new Set();
 let secret={cookie:'FAKE_RAM_COOKIE',csrf:'FAKE_RAM_CSRF',ticket:'FAKE_RAM_TICKET'};
 const upstream=http.createServer((req,res)=>{if(req.url==='/hold'||mode==='TIMEOUT')return;if(mode==='TRANSPORT'){req.socket.destroy();return;}res.writeHead(status);res.end('{}');});
 upstream.on('connection',s=>{upstreamSockets.add(s);s.on('close',()=>upstreamSockets.delete(s));});await listen(upstream);
 const gateway=http.createServer((_req,_res)=>{});gateway.on('connection',closure.trackIncoming);await listen(gateway);
 const client=net.connect(gateway.address().port,'127.0.0.1');client.on('error',()=>{});await new Promise(r=>client.once('connect',r));
 function request(path){return new Promise((resolve,reject)=>{const r=closure.trackRequest(http.request({host:'127.0.0.1',port:upstream.address().port,path,agent:false},res=>{res.resume();res.once('end',()=>resolve({status:res.statusCode}));}));r.on('error',reject);r.end();});}
 const held=request('/hold').catch(()=>{});await new Promise(r=>setTimeout(r,10));
 let receipt;
 try{
  receipt=await closure.cleanup({server:gateway,cancel:()=>request('/cancel'),clearSecrets:()=>{secret={cookie:'',csrf:'',ticket:''};},secretsEmpty:()=>Object.values(secret).every(v=>v===''),limitMs:2000,cancelMs:100});
  assert.equal(receipt.closureOK,true);assert.equal(receipt.listenerClosed,true);assert.equal(receipt.incomingSockets,0);assert.equal(receipt.outgoingSockets,0);assert.equal(receipt.outgoingRequests,0);assert.equal(receipt.secretsCleared,true);assert.ok(receipt.elapsedMs<2000);
  assert.equal(receipt.cancel.status,['HTTP200','HTTP409'].includes(mode)?status:'UNKNOWN');
  assert.equal(receipt.cancel.outcome,{HTTP200:'HTTP_200',HTTP409:'HTTP_NON_200',TRANSPORT:'TRANSPORT_ERROR',TIMEOUT:'TIMEOUT'}[mode]);
  assert.equal(receipt.cleanupOK,mode==='HTTP200');
  const primary={status:'FAIL_GATEWAY',code:'PHOTO_METADATA_UNAVAILABLE'};const result=finalizeResult(primary,receipt);assert.equal(result.code,primary.code);assert.equal(result.status,'FAIL_GATEWAY');
  rows.push({case:mode,status:'PASS',receipt,primaryPreserved:result.code});
 }finally{client.destroy();for(const s of upstreamSockets)s.destroy();await close(upstream);if(gateway.listening)await close(gateway);await held;}
}
const base={id,state:'failed',errorCode:'PHOTO_METADATA_UNAVAILABLE',previewUrl:null,title:null,duration:null,metadataAcceptedAt:null,metadataExpiresAt:null,items:[],mode:'temporary',serverMeaning:'fixture'};
async function observerCase(name,value,status,valid){
 const server=http.createServer((_req,res)=>{res.writeHead(status,{'content-type':'application/json'});res.end(JSON.stringify(value));});await listen(server);
 try{
  const response=await new Promise((resolve,reject)=>{const r=http.get({host:'127.0.0.1',port:server.address().port,agent:false},res=>{const bytes=[];res.on('data',b=>bytes.push(b));res.on('end',()=>resolve({status:res.statusCode,value:JSON.parse(Buffer.concat(bytes))}));});r.on('error',reject);});
  let result,error=false;try{result=observeJob(response.status,response.value,id);}catch{error=true;}
  assert.equal(error,!valid);if(valid){assert.equal(result.terminal,true);assert.equal(result.state,value.state);assert.equal(result.primaryCode,value.errorCode||'JOB_'+value.state.toUpperCase());}
  rows.push({case:name,status:'PASS',observation:result||{rejected:'RESPONSE_CONTRACT'}});
 }finally{await close(server);}
}
async function main(){
 assert.equal(process.versions.node,'22.22.3');
 for(const[mode,status]of [['HTTP200',200],['HTTP409',409],['TRANSPORT',null],['TIMEOUT',null]])await cleanupCase(mode,status);
 await observerCase('TERMINAL_FAILED',base,200,true);
 for(const state of ['cancelled','expired'])await observerCase('TERMINAL_'+state.toUpperCase(),{...base,state,errorCode:null},200,true);
 for(const[name,changes,status]of [['WRONG_STATUS',{},403],['WRONG_ID',{id:'22222222-2222-4222-8222-222222222222'},200],['NON_NULL_PREVIEW',{previewUrl:'FAKE_ONLY'},200],['INVALID_STATE',{state:'done'},200],['INVALID_SCHEMA',{items:'bad'},200],['INVALID_ERROR',{errorCode:'FAKE SECRET MESSAGE'},200]])await observerCase(name,{...base,...changes},status,false);
 fs.writeFileSync(OUT+'/gateway-tests.json',JSON.stringify({status:'PASS_LOOPBACK_ONLY',cases:rows,count:rows.length,node:process.versions.node,sourceCalls:0},null,2),{flag:'wx'});
 console.log(JSON.stringify({status:'PASS_LOOPBACK_ONLY',count:rows.length}));
}
main().catch(()=>{fs.writeFileSync(OUT+'/gateway-tests-failure.json',JSON.stringify({status:'FAIL',completed:rows}),{flag:'wx'});console.log('{"status":"FAIL_GATEWAY_TEST"}');process.exitCode=1;});
