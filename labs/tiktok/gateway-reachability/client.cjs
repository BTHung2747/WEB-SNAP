const http=require('node:http'),fs=require('node:fs');
const begin=process.hrtime.bigint();let done=false,socket={localAddress:'UNKNOWN',localPort:'UNKNOWN',remoteAddress:'UNKNOWN',remotePort:'UNKNOWN'};
function finish(row){if(done)return;done=true;clearTimeout(timer);fs.writeFileSync('/control/container.json',JSON.stringify({...row,socket,timeoutSeconds:5,elapsedSeconds:Number(process.hrtime.bigint()-begin)/1e9,utc:new Date().toISOString()}));process.exitCode=row.status==='PASS'?0:1;}
const request=http.get({host:'127.0.0.1',port:5206,path:'/reachability',agent:false,headers:{'x-wed-probe-point':'container'}},response=>{
 let data='',length=0;response.on('data',b=>{length+=b.length;if(length>256){request.destroy();finish({status:'FAIL',code:'BODY_CAP'});return;}data+=b;});
 response.on('end',()=>{const match=data==='WED_SNAP_REACHABILITY_'+process.env.PROBE_RUN+'\n';finish({status:response.statusCode===200&&match?'PASS':'FAIL',httpStatus:response.statusCode,markerMatch:match,bytes:length,code:response.statusCode===200&&match?'OK':'MARKER_OR_HTTP'});});
 response.on('error',()=>finish({status:'FAIL',code:'RESPONSE_ERROR'}));
});
request.on('socket',s=>s.once('connect',()=>{socket={localAddress:s.localAddress,localPort:s.localPort,remoteAddress:s.remoteAddress,remotePort:s.remotePort};}));
request.on('error',e=>finish({status:'FAIL',code:['ECONNREFUSED','ETIMEDOUT','ECONNRESET'].includes(e.code)?e.code:'REQUEST_ERROR'}));
const timer=setTimeout(()=>{finish({status:'FAIL',code:'ABSOLUTE_TIMEOUT'});request.destroy();},5000);
