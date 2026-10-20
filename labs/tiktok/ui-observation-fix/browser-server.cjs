'use strict';
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const [OUT,RUN]=process.argv.slice(2),PORT=5217,begin=performance.now(),sockets=new Set();let closing=false,total=0,native=0,responded=false,timer;
const payload=Buffer.from('WED_SNAP_SYNTHETIC_ONLY\n'),sha256=crypto.createHash('sha256').update(payload).digest('hex');
const page=Buffer.from('<!doctype html><html lang="vi"><meta charset="utf-8"><title>Native fixture probe</title><h1>Probe offline nhỏ</h1><p>Chỉ kiểm dispatch; chưa xác nhận lưu tệp.</p><a href="/native" download="wed-snap-probe.txt">Tải tệp giả lập</a></html>');
function write(name,row){fs.writeFileSync(path.join(OUT,name),JSON.stringify(row),{flag:'wx'});}
function event(kind,row={}){if(++total>16){void stop('EVENT_CAP');return;}fs.appendFileSync(path.join(OUT,'server-events.jsonl'),JSON.stringify({runID:RUN,sequence:total,kind,utc:new Date().toISOString(),monotonicMs:performance.now()-begin,...row})+'\n');}
const server=http.createServer({maxHeaderSize:2048},(req,res)=>{
 res.setHeader('content-security-policy',"default-src 'none'; script-src 'none'; style-src 'none'; connect-src 'none'; img-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");res.setHeader('cache-control','no-store');res.setHeader('x-content-type-options','nosniff');res.setHeader('connection','close');
 if(closing||req.method!=='GET'||req.headers.host!==`127.0.0.1:${PORT}`||req.headers['transfer-encoding']||Number(req.headers['content-length']||0)!==0){res.writeHead(403);res.end();event('DENIED',{status:403});return;}
 if(req.url==='/'){res.writeHead(200,{'content-type':'text/html; charset=utf-8','content-length':page.length});res.end(page);event('PAGE_GET',{status:200,bytes:page.length});return;}
 if(req.url==='/native'){
  native++;event('NATIVE_GET',{method:'GET',index:native});if(native!==1){res.writeHead(409);res.end();void stop('DUPLICATE_NATIVE');return;}
  res.on('finish',()=>{responded=true;event('NATIVE_RESPONSE',{status:200,bytes:payload.length,sha256});setTimeout(()=>{void stop('NATIVE_FINISHED');},100);});
  res.writeHead(200,{'content-type':'application/octet-stream','content-disposition':'attachment; filename="wed-snap-probe.txt"','content-length':payload.length});res.end(payload);return;
 }
 res.writeHead(404);res.end();event('OTHER',{status:404});
});
server.on('connection',socket=>{sockets.add(socket);socket.once('close',()=>sockets.delete(socket));});
server.on('connect',(_req,socket)=>socket.destroy());server.on('upgrade',(_req,socket)=>socket.destroy());
async function stop(reason){
 if(closing)return;closing=true;clearTimeout(timer);await new Promise(r=>{server.close(r);server.closeAllConnections();for(const socket of sockets)socket.destroy();});
 await new Promise(r=>setImmediate(r));const receipt={runID:RUN,pid:process.pid,node:process.versions.node,status:native===1&&responded?'PASS_NATIVE_GET_ONLY':'FAIL_NO_NATIVE',reason,nativeGET:native,responseFinished:responded,attachmentBytes:payload.length,sha256,listenerClosed:!server.listening,sockets:sockets.size,elapsedMs:performance.now()-begin,deadlineMs:28000,browserSave:'UNKNOWN',sourceCalls:0,utc:new Date().toISOString()};
 write('server-completion.json',receipt);process.exitCode=receipt.status==='PASS_NATIVE_GET_ONLY'&&receipt.listenerClosed&&sockets.size===0?0:20;
}
server.once('error',()=>{clearTimeout(timer);write('server-error.json',{runID:RUN,code:'SERVER_BIND_ERROR',sourceCalls:0});process.exitCode=21;});
server.listen(PORT,'127.0.0.1',()=>{write('ready.json',{runID:RUN,pid:process.pid,origin:`http://127.0.0.1:${PORT}`,utc:new Date().toISOString(),monotonicMs:performance.now()-begin,deadlineMs:28000});});
timer=setTimeout(()=>{void stop('SERVER_WATCHDOG');},28000);
