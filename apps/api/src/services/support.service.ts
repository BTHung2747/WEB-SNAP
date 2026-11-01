import { Injectable } from '@nestjs/common';
import { Request,Response } from 'express';
import { createHash } from 'node:crypto';
import { db,fail } from '../../../../packages/shared/src/core';
import { admin,parse } from '../common';
import { supportConfig,supportId,supportRow,emptySupport,adminSupport,SupportRow,qrLimit } from './support-contract';
import { supportImage,SupportFile } from './support-image';
import { uploadContext } from '../security/support-upload';
const qrSchema=supportRow.shape.qr.unwrap();
const publicProjection=supportRow.pick({version:true,config:true}).extend({qrId:qrSchema.shape.id.nullable()});
@Injectable()
export class SupportService {
 private async read(client:any=db):Promise<SupportRow>{
  const record=await client.settings.findUnique({where:{id:supportId}});
  return record?supportRow.parse(record.value):emptySupport();
 }
 private async change(actor:string,action:string,update:(row:SupportRow)=>void){
  return db.$transaction(async(tx)=>{
   // Serialize this single bounded row, including the first insert. This lock
   // is separate from main settings, jobs, media and native-transfer leases.
   await tx.$executeRaw`SELECT pg_advisory_xact_lock(8172441)`;
   const row=await this.read(tx);update(row);
   await tx.settings.upsert({where:{id:supportId},create:{id:supportId,value:row},update:{value:row}});
   await tx.auditLog.create({data:{actor,action,detail:{enabled:row.config.enabled,hasQR:!!row.qr,pending:row.pending!==null}}});
   return adminSupport(row);
  },{maxWait:2000,timeout:5000});
 }
 async public(){
  // Project inside PostgreSQL: saved/pending PNGs never enter Node for metadata.
  const rows=await db.$queryRaw<Array<{version:unknown;config:unknown;qrId:unknown}>>`
   SELECT value->'version' AS version, value->'config' AS config, value#>>'{qr,id}' AS "qrId"
   FROM "Settings" WHERE id=${supportId}`;
  if(!rows.length)return {enabled:false};
  const row=publicProjection.parse(rows[0]);
  return row.config.enabled?{...row.config,qrUrl:row.qrId?`/api/v1/support/qr/${row.qrId}`:null}:{enabled:false};
 }
 async settings(req:Request){await admin(req);return adminSupport(await this.read());}
 async save(req:Request,body:unknown){
  const actor=await admin(req,true),config=parse(supportConfig,body);
  return this.change(actor,'support.save',row=>{
   const image=row.pending?row.pending.qr:row.qr;
   if(config.enabled&&!image&&!(config.bankName&&config.accountName&&config.accountNumber))fail('SUPPORT_PAYMENT_REQUIRED');
   row.config=config;row.qr=image;row.pending=null;
  });
 }
 async upload(req:Request,file:SupportFile){
  const context=uploadContext.get(req);if(!context)fail('ADMIN_REQUIRED',403);
  if(!file)fail('SUPPORT_QR_INVALID');
  const image=await supportImage(file,context.deadline,context.signal);
  if(context.signal.aborted)fail('SUPPORT_UPLOAD_TIMEOUT',408);
  return this.change(context.actor,'support.qr.stage',row=>{if(context.signal.aborted)fail('SUPPORT_UPLOAD_TIMEOUT',408);row.pending={qr:image};});
 }
 async remove(req:Request){const actor=await admin(req,true);return this.change(actor,'support.qr.remove.stage',row=>{row.pending={qr:null};});}
 async image(req:Request,res:Response,id:string,privateImage=false){
  if(privateImage)await admin(req);
  if(!/^[a-f0-9]{64}$/.test(id))return res.status(404).end();
  // One statement selects and authorizes the exact binary in the same snapshot.
  // Private preview keeps pending-null deletion distinct from no pending edit.
  const rows=privateImage?await db.$queryRaw<Array<{image:unknown}>>`
   WITH chosen AS (
    SELECT CASE WHEN value->'pending' IS NOT NULL AND value->'pending'<>'null'::jsonb
     THEN value#>'{pending,qr}' ELSE value->'qr' END AS image
    FROM "Settings" WHERE id=${supportId} AND value->'version'='1'::jsonb
   ) SELECT image FROM chosen WHERE image->>'id'=${id}`:
   await db.$queryRaw<Array<{image:unknown}>>`
    SELECT value->'qr' AS image FROM "Settings"
    WHERE id=${supportId} AND value->'version'='1'::jsonb
     AND value#>'{config,enabled}'='true'::jsonb AND value#>>'{qr,id}'=${id}`;
  if(!rows.length)return res.status(404).end();
  const image=qrSchema.parse(rows[0].image);
  const bytes=Buffer.from(image.png,'base64');
  if(bytes.length>qrLimit||!bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))||createHash('sha256').update(bytes).digest('hex')!==id)return res.status(404).end();
  res.setHeader('Content-Type','image/png');res.setHeader('Content-Length',bytes.length);
  res.setHeader('Cache-Control','private, no-store');res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Content-Disposition','inline; filename="wed-snap-support.png"');return res.end(bytes);
 }
}
