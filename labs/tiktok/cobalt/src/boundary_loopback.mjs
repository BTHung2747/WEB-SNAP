// Offline fixture only: reuse Node HTTP/HTTPS/net servers from the existing stage-fixture pattern.
import fs from 'node:fs';import http from 'node:http';import https from 'node:https';import net from 'node:net';
import readline from 'node:readline';import {once} from 'node:events';
const cert=fs.readFileSync('/lab/src/fixtures/stages-cert.pem'),key=fs.readFileSync('/lab/src/fixtures/stages-key.pem');
const sockets=new Set(),timers=new Set();let mode='success';
const track=s=>{sockets.add(s);s.on('error',()=>{});s.once('close',()=>sockets.delete(s));};
const later=(fn,ms)=>{const t=setTimeout(()=>{timers.delete(t);fn();},ms);timers.add(t);};
const reply=(_req,res)=>{
  const run=()=>{if(res.destroyed)return;res.writeHead(200,{'content-length':7,'set-cookie':'FAKECOOKIE=RAM'});res.end('FIXTURE');};
  later(run,mode==='headers-delay'?700:15);
};
const a=https.createServer({key,cert},reply),b=https.createServer({key,cert},reply),stallTLS=net.createServer(track),proxy=http.createServer();
for(const s of [a,b,proxy]){s.on('connection',track);s.on('clientError',(_e,socket)=>socket.destroy());}
for(const s of [a,b,stallTLS,proxy]){s.listen(0,'127.0.0.1');await once(s,'listening');}
proxy.on('connect',(req,socket,head)=>{
  if(mode==='setup-delay')return; // Never return CONNECT response, still loopback only.
  const port=Number(req.url.split(':').at(-1));
  if(![a.address().port,b.address().port,stallTLS.address().port].includes(port)){socket.destroy();return;}
  const up=net.connect(port,'127.0.0.1');track(up);
  up.once('connect',()=>later(()=>{if(socket.destroyed){up.destroy();return;}socket.write('HTTP/1.1 200 Connection established\r\n\r\n');if(head.length)up.write(head);socket.pipe(up);up.pipe(socket);},20));
});
process.stdout.write(JSON.stringify({a:a.address().port,b:b.address().port,tls:stallTLS.address().port,proxy:proxy.address().port})+'\n');
readline.createInterface({input:process.stdin}).on('line',line=>{
  if(line==='STOP'){for(const t of timers)clearTimeout(t);for(const s of sockets)s.destroy();for(const s of [a,b,stallTLS,proxy])s.close();process.exit(0);}
  if(['success','setup-delay','headers-delay'].includes(line)){mode=line;process.stdout.write('OK\n');}
});
process.on('uncaughtException',()=>{process.stdout.write('FIXTURE_SERVER_ERROR\n');process.exit(20);});
