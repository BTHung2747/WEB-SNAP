// Network-none fixture: real Undici proxy/TLS sockets, no source requests.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import { once } from 'node:events';
import { ProxyAgent } from 'undici';
import { createStages } from './stages.mjs';
import { createTransport } from './transport.mjs';
const cert=fs.readFileSync(new URL('./fixtures/origin-cert.pem',import.meta.url));
const key=fs.readFileSync(new URL('./fixtures/stages-key.pem',import.meta.url));
async function run(mode){
  const sockets=new Set();const track=s=>{sockets.add(s);s.on('error',()=>{});s.once('close',()=>sockets.delete(s))};
  const origin=https.createServer({key,cert},(req,res)=>{
    if(req.url==='/redirect'){res.writeHead(302,{location:'https://alt.localhost/final?token=FAKEQUERY'});res.end();return}
    res.end('FAKEBODY');
  });origin.on('connection',track);origin.listen(0,'127.0.0.1');await once(origin,'listening');
  const silent=net.createServer(track);silent.listen(0,'127.0.0.1');await once(silent,'listening');
  const proxy=http.createServer();proxy.on('connection',track);proxy.on('connect',(req,socket,head)=>{
    const isAlt=req.url.startsWith('alt.localhost:');
    const target=mode==='failure'&&isAlt?silent:origin;
    const upstream=net.connect(target.address().port,'127.0.0.1');track(upstream);
    upstream.once('connect',()=>{socket.write('HTTP/1.1 200 Connection established\r\n\r\n');if(head.length)upstream.write(head);socket.pipe(upstream);upstream.pipe(socket)});
  });proxy.listen(0,'127.0.0.1');await once(proxy,'listening');
  const proxyURI='http://127.0.0.1:'+proxy.address().port,report={requests:[]},stages=createStages({report,proxyURI});
  const agent=new ProxyAgent({uri:proxyURI,requestTls:{ca:cert,rejectUnauthorized:true},proxyTls:{rejectUnauthorized:true},clientFactory:stages.clientFactory,factory:stages.originFactory});
  let controller=new AbortController();
  const make=()=>createTransport({report,stages,dispatcher:agent,signal:controller.signal});
  const transport=make();let timer,watch;
  try{
    if(mode==='redirect'){
      assert.equal(await(await transport.fetch('https://localhost/redirect')).text(),'FAKEBODY');
      const hops=report.transportStages.requests;assert.equal(hops.length,2);assert.notEqual(hops[0].originId,hops[1].originId);
      assert.notEqual(hops[0].connectionId,hops[1].connectionId);assert.equal(hops[1].connectionReused,false);assert.equal(hops[1].originTLSReady,true);
    }else{
      assert.equal(await(await transport.fetch('https://localhost/first')).text(),'FAKEBODY');
      if(mode==='reuse'){
        assert.equal(await(await transport.fetch('https://localhost/second')).text(),'FAKEBODY');
        const hops=report.transportStages.requests;assert.equal(hops.length,2);assert.equal(hops[1].originTLSAvailable,true);
        assert.equal(hops[0].connectionId,hops[1].connectionId);assert.equal(hops[1].connectionReused,true);assert.equal(hops[1].originTLSReady,true);
      }else{
        watch=setInterval(()=>{if(report.transportStages.awaitedStage==='WAITING_ORIGIN_TLS'){clearInterval(watch);timer=setTimeout(()=>controller.abort(new Error('FAKE_DEADLINE')),80)}},10);
        const safety=setTimeout(()=>controller.abort(new Error('FIXTURE_TIMEOUT')),2500);
        await assert.rejects(transport.fetch('https://alt.localhost/second'));
        clearTimeout(safety);clearInterval(watch);clearTimeout(timer);
        const second=report.transportStages.requests[1];assert.equal(second.originTLSReady,false);assert.equal(second.originTLSAvailable,false);
        assert.equal(second.failureStage,'WAITING_ORIGIN_TLS');assert.equal(second.tunnelStatus,200);assert.equal(second.bodyComplete,false);
        // New request on the still-live first socket: prior failure must not leak.
        controller=new AbortController();const again=make();
        assert.equal(await(await again.fetch('https://localhost/third')).text(),'FAKEBODY');
        const third=report.transportStages.requests[2];assert.equal(third.failureStage,undefined);assert.equal(third.connectionReused,true);assert.equal(third.originTLSReady,true);
        assert.equal(third.connectionId,report.transportStages.requests[0].connectionId);
      }
    }
    assert.equal(report.transportStages.observerFault,false);
    assert.doesNotMatch(JSON.stringify(report),/https?:\/\/|localhost|FAKEQUERY|FAKEBODY/);
    return {case:mode,requests:report.transportStages.requests.map(h=>({requestId:h.requestId,originId:h.originId,connectionId:h.connectionId,connectionReused:h.connectionReused,originTLSReady:h.originTLSReady,failureStage:h.failureStage,stage:h.awaitedStage}))};
  }finally{
    clearInterval(watch);clearTimeout(timer);for(const s of sockets)s.destroy();await agent.destroy();await transport.close();
    await Promise.all([origin,silent,proxy].map(server=>new Promise(resolve=>server.close(resolve))));
  }
}
const results=[];for(const mode of ['redirect','reuse','failure']){results.push(await run(mode));console.log('PASS F-STAGE-ORIGIN '+mode+'; request/origin/socket scoped; no source')}
fs.writeFileSync('/out/origin-fixtures.json',JSON.stringify({environment:'network-none loopback',results},null,2));
