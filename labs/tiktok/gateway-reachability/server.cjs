// Lab marker only; no outbound HTTP/DNS code in this server.
const http=require('node:http'),fs=require('node:fs');
const run=process.env.PROBE_RUN;
if(process.versions.node!=='22.22.3'||!/^[a-f0-9]{32}$/.test(run))process.exit(20);
const marker='WED_SNAP_REACHABILITY_'+run+'\n',counts={container:0,host:0,browser:0,other:0};
const server=http.createServer((req,res)=>{
 const good=req.method==='GET'&&req.url==='/reachability';
 const point=['container','host'].includes(req.headers['x-wed-probe-point'])?req.headers['x-wed-probe-point']:'browser';
 counts[good?point:'other']++;
 fs.appendFileSync('/control/requests.jsonl',JSON.stringify({point:good?point:'other',status:good?200:404,localAddress:req.socket.localAddress,localPort:req.socket.localPort,remoteAddress:req.socket.remoteAddress,remotePort:req.socket.remotePort,utc:new Date().toISOString()})+'\n');
 res.writeHead(good?200:404,{'content-type':'text/plain; charset=utf-8','cache-control':'no-store','content-length':Buffer.byteLength(good?marker:'NOT_FOUND\n'),'connection':'close'});res.end(good?marker:'NOT_FOUND\n');
});
let closing=false;
function stop(reason){if(closing)return;closing=true;clearTimeout(deadline);server.close(()=>{fs.writeFileSync('/control/server-end.json',JSON.stringify({reason,counts,node:process.versions.node,utc:new Date().toISOString()}));process.exit(0);});server.closeAllConnections();}
server.on('error',()=>{fs.writeFileSync('/control/server-error.json',JSON.stringify({code:'LISTEN_ERROR'}));process.exit(21);});
server.on('connect',(_r,s)=>s.destroy());
server.listen(5206,'0.0.0.0',()=>fs.writeFileSync('/control/listen.json',JSON.stringify({address:server.address(),node:process.versions.node,runID:run,utc:new Date().toISOString()})));
const deadline=setTimeout(()=>stop('DEADLINE_90S'),90000);
process.once('SIGTERM',()=>stop('SIGTERM'));process.once('SIGINT',()=>stop('SIGINT'));
