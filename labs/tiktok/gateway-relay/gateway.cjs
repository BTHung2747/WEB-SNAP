// Marker-only lab relay. Destination never comes from the incoming request.
const http=require('node:http'),net=require('node:net'),fs=require('node:fs');
const upstream=process.env.MARKER_IPV4,run=process.env.PROBE_RUN;
if(process.versions.node!=='22.22.3'||net.isIP(upstream)!==4||!/^[a-f0-9]{32}$/.test(run))process.exit(20);
const expected='WED_SNAP_REACHABILITY_'+run+'\n',counts={host:0,browser:0,other:0,upstream:0,errors:0,dnsDenied:0};
const active=new Set();let closing=false;
function record(row){fs.appendFileSync('/control/requests.jsonl',JSON.stringify({...row,utc:new Date().toISOString()})+'\n');}
const server=http.createServer((req,res)=>{
 const point=req.headers['x-wed-probe-point']==='host'?'host':'browser';
 if(closing||req.method!=='GET'||req.url!=='/reachability'||req.headers.host!=='127.0.0.1:5206'||req.headers['transfer-encoding']||Number(req.headers['content-length']||0)!==0){
  counts.other++;req.resume();res.writeHead(404,{'content-type':'text/plain','cache-control':'no-store','connection':'close'});res.end('DENIED\n');record({point:'other',code:'REQUEST_DENIED',status:404});return;
 }
 counts[point]++;let done=false;const begin=process.hrtime.bigint();let socket={remoteAddress:'UNKNOWN',remotePort:'UNKNOWN',localAddress:'UNKNOWN'};
 function fail(code){if(done)return;done=true;clearTimeout(timer);counts.errors++;request.destroy();if(!res.headersSent)res.writeHead(502,{'content-type':'text/plain','cache-control':'no-store','connection':'close'});res.end('RELAY_FAILED\n');record({point,code,status:502,socket,elapsedSeconds:Number(process.hrtime.bigint()-begin)/1e9});}
 const request=http.request({host:upstream,port:5206,path:'/reachability',method:'GET',agent:false,maxHeaderSize:4096,headers:{'x-wed-probe-point':point},lookup(_host,_options,callback){counts.dnsDenied++;callback(Object.assign(new Error(),{code:'DNS_DENIED'}));}},response=>{
  if(response.statusCode!==200||response.headers.location||!String(response.headers['content-type']).startsWith('text/plain')||response.headers['cache-control']!=='no-store'){response.destroy();fail('UPSTREAM_HEADERS');return;}
  let size=0;const chunks=[];
  response.on('data',b=>{size+=b.length;if(size>256){response.destroy();fail('BODY_CAP');return;}chunks.push(Buffer.from(b));});
  response.on('error',()=>fail('RESPONSE_ERROR'));
  response.on('end',()=>{if(done)return;const bytes=Buffer.concat(chunks);if(bytes.toString()!==expected){fail('MARKER_MISMATCH');return;}done=true;clearTimeout(timer);res.writeHead(200,{'content-type':'text/plain; charset=utf-8','cache-control':'no-store','content-length':bytes.length,'connection':'close'});res.end(bytes);record({point,code:'OK',status:200,bytes:size,markerMatch:true,socket,elapsedSeconds:Number(process.hrtime.bigint()-begin)/1e9});});
 });
 counts.upstream++;active.add(request);request.once('close',()=>active.delete(request));
 request.on('socket',s=>s.once('connect',()=>{socket={remoteAddress:s.remoteAddress,remotePort:s.remotePort,localAddress:s.localAddress};}));
 request.on('error',e=>fail(['ECONNREFUSED','ETIMEDOUT','ECONNRESET','DNS_DENIED'].includes(e.code)?e.code:'REQUEST_ERROR'));
 const timer=setTimeout(()=>fail('ABSOLUTE_DEADLINE'),5000);request.end();
});
server.on('connect',(_req,s)=>{counts.other++;record({point:'other',code:'CONNECT_DENIED'});s.destroy();});
server.on('upgrade',(_req,s)=>{counts.other++;record({point:'other',code:'UPGRADE_DENIED'});s.destroy();});
server.on('error',()=>{fs.writeFileSync('/control/server-error.json',JSON.stringify({code:'LISTEN_ERROR'}));process.exit(21);});
server.listen(5206,'0.0.0.0',()=>fs.writeFileSync('/control/listen.json',JSON.stringify({address:server.address(),upstreamIPv4:upstream,upstreamPort:5206,runID:run,node:process.versions.node,utc:new Date().toISOString()})));
function stop(reason){if(closing)return;closing=true;clearTimeout(lifetime);for(const request of active)request.destroy();server.close(()=>{fs.writeFileSync('/control/server-end.json',JSON.stringify({reason,counts,activeRequests:active.size,upstreamIPv4:upstream,node:process.versions.node,utc:new Date().toISOString()}));process.exit(counts.errors||counts.dnsDenied?1:0);});server.closeAllConnections();}
const lifetime=setTimeout(()=>stop('DEADLINE_110S'),110000);process.once('SIGTERM',()=>stop('SIGTERM'));process.once('SIGINT',()=>stop('SIGINT'));
