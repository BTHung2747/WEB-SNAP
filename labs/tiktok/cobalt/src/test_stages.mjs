// Offline only: Node library servers/tunnel, trusted fixture CA, no external network.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import { once } from 'node:events';
import { ProxyAgent } from 'undici';
import { createStages,EVENT_CAP } from './stages.mjs';
import { createTransport } from './transport.mjs';
const cert=fs.readFileSync(new URL('./fixtures/stages-cert.pem',import.meta.url));
const key=fs.readFileSync(new URL('./fixtures/stages-key.pem',import.meta.url));
async function caseRun(mode,expected){
  const sockets=new Set(),timers=new Set();
  const track=socket=>{sockets.add(socket);socket.on('error',()=>{});socket.once('close',()=>sockets.delete(socket))};
  const later=(fn,ms)=>{const timer=setTimeout(()=>{timers.delete(timer);fn()},ms);timers.add(timer)};
  const origin=mode==='tls'?net.createServer(track):https.createServer({key,cert},(req,res)=>{
    // Token-bearing URL/header/body stay entirely in fake fixtures/RAM.
    const reply=()=>{if(res.destroyed)return;res.writeHead(200,{'content-type':'text/plain','set-cookie':'FAKECOOKIE'});res.flushHeaders();
      if(mode==='body'){res.write('FAKEBODY');later(()=>res.end('TAIL'),1000)}else res.end('FAKEBODY')};
    if(mode==='headers'){res.writeEarlyHints({link:'</FAKEPATH>; rel=preload'});later(reply,1000)}else later(reply,30);
  });
  origin.on('connection',track);origin.listen(0,'127.0.0.1');await once(origin,'listening');
  const proxy=http.createServer();proxy.on('connection',track);
  proxy.on('connect',(req,socket,head)=>{
    if(mode==='connect')return; // Accept TCP/CONNECT, never issue CONNECT response.
    later(()=>{
      if(socket.destroyed)return;
      const upstream=net.connect(origin.address().port,'127.0.0.1');track(upstream);
      upstream.once('connect',()=>{if(socket.destroyed){upstream.destroy();return}socket.write('HTTP/1.1 200 Connection established\r\n\r\n');if(head.length)upstream.write(head);socket.pipe(upstream);upstream.pipe(socket)});
    },70);
  });
  proxy.listen(0,'127.0.0.1');await once(proxy,'listening');
  const proxyURI=`http://127.0.0.1:${proxy.address().port}`,report={requests:[]};
  const stages=createStages({report,proxyURI});
  const agent=new ProxyAgent({uri:proxyURI,requestTls:{ca:cert,rejectUnauthorized:true},proxyTls:{rejectUnauthorized:true},clientFactory:stages.clientFactory,factory:stages.originFactory});
  const controller=new AbortController();
  const transport=createTransport({report,stages,dispatcher:agent,signal:controller.signal});
  // Abort only after the expected measured stage is reached; deterministic under CPU limits.
  const wanted={connect:'WAITING_PROXY_CONNECT_RESPONSE',tls:'WAITING_ORIGIN_TLS',headers:'WAITING_RESPONSE_HEADERS',body:'READING_BODY'}[mode];
  const interval=setInterval(()=>{if(wanted&&report.transportStages.awaitedStage===wanted&& (mode!=='body'||report.transportStages.firstDecoded)){
    clearInterval(interval);later(()=>controller.abort(new Error('FAKE_DEADLINE')),100);
  }},10);
  const safety=setTimeout(()=>controller.abort(new Error('FIXTURE_STAGE_NOT_REACHED')),2500);
  try{
    const response=await transport.fetch('https://localhost/FAKEPATH?token=FAKEQUERY',{headers:{cookie:'FAKECOOKIE',authorization:'FAKEAUTH'}});
    const body=await response.text();assert.equal(mode,'success');assert.equal(body,'FAKEBODY');
  }catch(error){if(mode==='success')throw error;assert.equal(controller.signal.aborted,true)}
  finally{
    clearInterval(interval);clearTimeout(safety);for(const timer of timers)clearTimeout(timer);
    for(const socket of sockets)socket.destroy();await agent.destroy();await transport.close();
    await Promise.all([new Promise(r=>proxy.close(r)),new Promise(r=>origin.close(r))]);
  }
  const trace=report.transportStages;
  assert.equal(mode==='success'?trace.awaitedStage:trace.failureStage,expected);
  assert.equal(trace.proxyTCPReady,true);assert.equal(trace.observerFault,false);assert.ok(trace.events.length<=EVENT_CAP);
  if(mode!=='connect')assert.equal(trace.tunnelStatus,200);
  if(['headers','body','success'].includes(mode)){
    assert.equal(trace.originTLSReady,true);assert.ok(trace.events.some(e=>e.event==='connection_ready'&&e.role==='origin'&&e.authorized));
  }
  if(mode==='headers'){assert.equal(trace.originSent,true);assert.equal(trace.originHeaders,false);assert.ok(trace.events.some(e=>e.event==='response_headers'&&e.status===103))}
  if(mode==='body'){assert.equal(trace.originHeaders,true);assert.equal(trace.bodyReaderStarted,true);assert.equal(trace.firstDecoded,true);assert.equal(trace.bodyComplete,false)}
  if(mode==='success')assert.equal(trace.bodyComplete,true);
  assert.doesNotMatch(JSON.stringify(report),/FAKEPATH|FAKEQUERY|FAKECOOKIE|FAKEAUTH|FAKEBODY|https?:\/\//);
  return {case:mode,measuredStage:expected,proxyTCP:trace.proxyTCPReady,CONNECT:trace.tunnelStatus??null,verifiedTLS:trace.originTLSReady??false,headers:trace.originHeaders,firstDecoded:trace.firstDecoded,events:trace.events.length};
}
const results=[];
for(const [mode,expected] of [['connect','WAITING_PROXY_CONNECT_RESPONSE'],['tls','WAITING_ORIGIN_TLS'],['headers','WAITING_RESPONSE_HEADERS'],['body','READING_BODY'],['success','COMPLETE']]){
  results.push(await caseRun(mode,expected));console.log(`PASS measured local ${mode} stage, trusted fixture TLS, no external network/token log`);
}
fs.writeFileSync('/out/stage-fixtures.json',JSON.stringify({environment:'network-none; loopback fake Node servers; no real egress/TikTok',results},null,2));
// Observer event cap and detach are tested without transport or fake channel publications.
const report={};const observer=createStages({report});for(let i=0;i<EVENT_CAP+10;i++)observer.mark('fixture_cap');
assert.equal(report.transportStages.events.length,EVENT_CAP);assert.ok(report.transportStages.dropped>0);observer.close();
const count=report.transportStages.events.length;observer.mark('after_close');assert.equal(report.transportStages.events.length,count);
console.log('PASS observer cap128 and unsubscribe/closed observer');
