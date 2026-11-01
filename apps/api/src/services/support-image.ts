// Local raster validation/normalization only. FFmpeg owns the decoder; it never
// receives a filename, URL or protocol from the upload. No QR/payment parser.
import { spawn } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { createHash } from 'node:crypto';
import { AppError } from '../../../../packages/shared/src/core';
import { qrLimit,SupportQR } from './support-contract';
export type SupportFile={buffer:Buffer;size:number;mimetype:string};
function invalid():never{throw new AppError('SUPPORT_QR_INVALID');}
async function native(tool:string,args:string[],input:Buffer,end:number,signal:AbortSignal,cap:number):Promise<Buffer>{
 if(signal.aborted||performance.now()>=end)throw new AppError('SUPPORT_UPLOAD_TIMEOUT',408);
 return new Promise((resolve,reject)=>{
  const p=spawn(tool,args,{shell:false,stdio:['pipe','pipe','ignore']});let size=0;const chunks:Buffer[]=[];let error:AppError|undefined;
  const stop=(reason:AppError)=>{if(!error)error=reason;p.kill('SIGKILL');};
  const abort=()=>stop(new AppError('SUPPORT_UPLOAD_TIMEOUT',408));
  const timer=setTimeout(abort,Math.max(1,end-performance.now()));
  signal.addEventListener('abort',abort,{once:true});
  p.stdin.on('error',()=>{});
  p.stdout.on('data',(data:Buffer)=>{size+=data.length;if(size>cap)stop(new AppError('SUPPORT_QR_LIMIT',413));else chunks.push(data);});
  p.on('error',()=>{error=new AppError('SUPPORT_QR_INVALID');});
  // Completion requires native close, including after timeout/cancel/kill.
  p.once('close',(code,actualSignal)=>{
   clearTimeout(timer);signal.removeEventListener('abort',abort);
   if(error)return reject(error);
   if(code!==0||actualSignal||signal.aborted||performance.now()>=end)return reject(new AppError(signal.aborted?'SUPPORT_UPLOAD_TIMEOUT':'SUPPORT_QR_INVALID',signal.aborted?408:400));
   resolve(Buffer.concat(chunks));
  });
  p.stdin.end(input);
 });
}
export async function supportImage(file:SupportFile,end:number,signal:AbortSignal):Promise<SupportQR>{
 if(!file||!Buffer.isBuffer(file.buffer)||file.size!==file.buffer.length||file.size<8||file.size>qrLimit)throw new AppError('SUPPORT_QR_LIMIT',413);
 const png=file.buffer.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
 const jpg=file.buffer[0]===255&&file.buffer[1]===216&&file.buffer[2]===255;
 if(!((png&&file.mimetype==='image/png')||(jpg&&file.mimetype==='image/jpeg')))invalid();
 const deadline=Math.min(end,performance.now()+8000);
 const raw=await native('ffprobe',['-v','error','-max_alloc','67108864','-protocol_whitelist','pipe','-count_frames',
  '-show_entries','stream=codec_type,codec_name,width,height,nb_read_frames','-of','json','-i','pipe:0'],file.buffer,deadline,signal,4096);
 let stream:any;
 try{const p=JSON.parse(raw.toString('utf8'));if(p.streams.length!==1)invalid();stream=p.streams[0];}catch{invalid();}
 if(stream.codec_type!=='video'||stream.codec_name!==(png?'png':'mjpeg')||stream.nb_read_frames!=='1'||
  !Number.isSafeInteger(stream.width)||!Number.isSafeInteger(stream.height)||stream.width<32||stream.height<32||stream.width>2048||stream.height>2048||stream.width*stream.height>4194304)invalid();
 const normalized=await native('ffmpeg',['-v','error','-nostdin','-xerror','-max_alloc','67108864','-threads','1',
  '-err_detect','explode','-protocol_whitelist','pipe','-i','pipe:0','-frames:v','1','-threads','1','-c:v','png','-compression_level','6','-f','image2pipe','pipe:1'],file.buffer,deadline,signal,qrLimit);
 if(normalized.length<8||!normalized.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))invalid();
 return {id:createHash('sha256').update(normalized).digest('hex'),png:normalized.toString('base64'),width:stream.width,height:stream.height};
}
