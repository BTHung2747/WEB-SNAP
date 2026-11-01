// Disposable, source-disabled integration launcher. Actual AppModule/auth/DB/
// Redis; only static serving of an already built UI is lab glue, not Caddy.
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import {Request,Response} from 'express';
import cookieParser from 'cookie-parser';
import helmet from 'helmet';
import fs from 'node:fs';
import { randomBytes } from 'node:crypto';
import { AppModule } from '../apps/api/src/app.module';
import { SafeErrors } from '../apps/api/src/common';
import { clientIdentityMiddleware } from '../apps/api/src/security/client-ip';
import { db,redis,queue,defaults,passwordHash } from '../packages/shared/src/core';
const labPort=Number(process.env.SUPPORT_LIVE_PORT||5202);
if(process.env.SUPPORT_LIVE_GUARD!=='own-loopback-support-20261101'||!Number.isInteger(labPort)||labPort<1024||labPort>65535||process.env.APP_ORIGIN!==`http://127.0.0.1:${labPort}`||
 !/^postgresql:\/\/support_lab:.*@postgres:5432\/support_lab$/.test(process.env.DATABASE_URL||'')||process.env.REDIS_URL!=='redis://redis:6379/0'||process.env.TIKTOK_ADAPTER_ENABLED!=='0')throw Error('LAB_GUARD');
async function main(){
 await redis.ping();
 await db.settings.create({data:{id:'main',value:{...defaults,enabledPlatforms:[],acceptJobs:false}}});
 const email='support-lab@example.invalid',password='LabOnly-'+randomBytes(16).toString('hex');
 await db.adminUser.create({data:{email,passwordHash:passwordHash(password)}});
 fs.writeFileSync('/out/operator-access.json',JSON.stringify({email,password,scope:'disposable loopback lab only; deleted with owned lab',url:process.env.APP_ORIGIN}),{mode:0o600});
 const app=await NestFactory.create(AppModule,{logger:['error','warn']});
 const server=app.getHttpAdapter().getInstance();server.set('trust proxy',false);
 app.use(clientIdentityMiddleware());app.use(helmet({contentSecurityPolicy:false}));app.use(cookieParser());
 app.useGlobalFilters(new SafeErrors());
 app.use((req:Request,res:Response,next:any)=>{
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Wed-Support-Lab','real-api-pg-redis');
  next();
 });
 await app.listen(3000,'0.0.0.0');console.log('SUPPORT_LIVE_READY realAPI PostgreSQL Redis; source disabled');
 const end=async()=>{await app.close();await queue.close();redis.disconnect();await db.$disconnect();process.exit(0);};
 process.once('SIGTERM',()=>{void end();});process.once('SIGINT',()=>{void end();});
}
main().catch(()=>{console.error('SUPPORT_LIVE_START_FAILED');process.exit(20);});
