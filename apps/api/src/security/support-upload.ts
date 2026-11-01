import { CanActivate,ExecutionContext,Injectable,NestInterceptor,CallHandler,HttpException } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request,Response } from 'express';
import { Transform } from 'node:stream';
import { performance } from 'node:perf_hooks';
import { finalize } from 'rxjs';
import { admin } from '../auth/session';
import { AppError,hash,rate } from '../../../../packages/shared/src/core';
import { qrLimit,uploadLimit } from '../services/support-contract';
type Upload={actor:string;deadline:number;signal:AbortSignal;release:()=>void;reject:(code:string,status:number)=>void};
export const uploadContext=new WeakMap<Request,Upload>();
let active=false;
@Injectable()
export class SupportUploadGuard implements CanActivate {
 async canActivate(context:ExecutionContext){
  const req=context.switchToHttp().getRequest<Request>(),res=context.switchToHttp().getResponse<Response>();
  // Nest runs guards before interceptors. No multipart/data listener, parser or
  // memory buffer is attached before these existing authentication checks.
  const actor=await admin(req,true);
  await rate('support:upload:'+hash(actor),10,60);
  if(!/^multipart\/form-data\s*;/i.test(req.get('content-type')||''))throw new AppError('SUPPORT_QR_INVALID');
  const length=req.get('content-length');
  if(length&&(!/^[0-9]+$/.test(length)||Number(length)>uploadLimit))throw new AppError('SUPPORT_QR_LIMIT',413);
  if(active)throw new AppError('SUPPORT_UPLOAD_BUSY',409);
  active=true;const control=new AbortController();let released=false;
  const abort=()=>control.abort();
  const close=()=>{if(!res.writableFinished)abort();};
  const reject=(code:string,status:number)=>{
   abort();
   if(!res.headersSent){res.setHeader('Connection','close');res.status(status).json({error:{code}});}
   // Do not drain an unlimited chunked body after a cap/deadline violation.
   setImmediate(()=>req.destroy());
  };
  const timer=setTimeout(()=>reject('SUPPORT_UPLOAD_TIMEOUT',408),20000);
  req.once('aborted',abort);res.once('close',close);
  const release=()=>{
   if(released)return;released=true;active=false;clearTimeout(timer);
   req.removeListener('aborted',abort);res.removeListener('close',close);uploadContext.delete(req);
   const file=(req as any).file;if(file?.buffer)file.buffer.fill(0);delete (req as any).file;
  };
  uploadContext.set(req,{actor,deadline:performance.now()+20000,signal:control.signal,release,reject});return true;
 }
}
// Public Multer2.4 streamHandler delegates multipart parsing to Busboy through
// a standard Transform; only aggregate byte accounting is WED SNAP glue.
const options={
 // Busboy1.6 enforces16KiB of part headers; its2000-pair constant only
 // stops recording additional headers. limits.headerPairs is ignored upstream.
 limits:{fileSize:qrLimit,files:1,fields:0,parts:1,fieldNameSize:32,fieldSize:0,fieldNestingDepth:0,fieldArrayIndexLimit:0},
 fileFilter:(_req:any,file:any,done:any)=>done(['image/png','image/jpeg'].includes(file.mimetype)?null:new AppError('SUPPORT_QR_INVALID'),true),
 streamHandler(req:Request,parser:any){
  let bytes=0;
  const bounded=new Transform({transform(chunk:Buffer,_encoding,done){bytes+=chunk.length;
   if(bytes>uploadLimit){uploadContext.get(req)?.reject('SUPPORT_QR_LIMIT',413);done(new AppError('SUPPORT_QR_LIMIT',413));}
   else done(null,chunk);
  }});
  bounded.on('error',()=>parser.destroy(new AppError('SUPPORT_QR_LIMIT',413)));
  req.once('aborted',()=>bounded.destroy());parser.once('close',()=>{req.unpipe(bounded);bounded.destroy();});
  req.pipe(bounded).pipe(parser);
 },
};
const Multipart=FileInterceptor('file',options);
@Injectable()
export class SupportUploadInterceptor implements NestInterceptor {
 private readonly parser=new Multipart();
 async intercept(context:ExecutionContext,next:CallHandler){
  const req=context.switchToHttp().getRequest<Request>(),upload=uploadContext.get(req);
  if(!upload)throw new AppError('ADMIN_REQUIRED',403);
  try{
   const result=await this.parser.intercept(context,next);
   return result.pipe(finalize(()=>upload.release()));
  }catch(error){
   upload.release();
   if(error instanceof AppError)throw error;
   // Never expose Multer filename/message, even from transformed exceptions.
   if(error instanceof HttpException&&error.getStatus()===413)throw new AppError('SUPPORT_QR_LIMIT',413);
   throw new AppError('SUPPORT_QR_INVALID');
  }
 }
}
