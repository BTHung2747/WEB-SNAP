async function main(){
 if(process.env.STEP5_EXECUTE_SOURCE!=='1'&&process.env.STEP5_OFFLINE_TEST!=='1'){console.log('SOURCE_DISABLED');process.exitCode=78;return;}
 const {Worker,UnrecoverableError}=await import('/app/node_modules/bullmq/dist/cjs/index.js');
 const {readFile,writeFile,open,mkdir}=await import('node:fs/promises');
 const {performance}=await import('node:perf_hooks');
 const {db,redis,queue}=await import('/app/packages/shared/src/core');
 const {processJob}=await import('/app/apps/worker/src/processor');
 const {sweep}=await import('/app/apps/worker/src/lifecycle');
// Lab consumer delegates production processor unchanged. Durable per-phase fences outlive restarts.
const root='/control';
async function note(dir:string,row:any){await writeFile(dir+'/consumer.jsonl',JSON.stringify(row)+'\n',{flag:'a'});}
async function once(path:string,value:any){const h=await open(path,'wx',0o600);try{await h.writeFile(JSON.stringify(value));}finally{await h.close();}}
const worker=new Worker('media',async job=>{
 const cfg=JSON.parse(await readFile(root+'/active.json','utf8')),dir=root+'/cases/'+cfg.case;
 try{
  if((cfg.mode!==(process.env.STEP5_EXECUTE_SOURCE==='1'?'source':'offline'))||(cfg.mode==='offline'&&process.env.STEP5_OFFLINE_TEST!=='1')||!['analyze','prepare'].includes(job.name)||performance.now()<0)throw new Error('MODE');
  const j=await db.downloadJob.findUniqueOrThrow({where:{id:job.data.id}});
  if(j.sourceUrl!==cfg.url||await exists(dir+'/stopped')||Date.now()>=cfg.wallEnd||Date.now()-job.timestamp>=10000)throw new Error('STOPPED');
  try{await once(dir+'/job-once.json',{id:j.id});}catch(e:any){if(e.code!=='EEXIST'||JSON.parse(await readFile(dir+'/job-once.json','utf8')).id!==j.id)throw e;}
  await once(dir+'/'+job.name+'.consumer-once',{jobId:j.id});
  await note(dir,{event:'PROCESSOR_BEGIN',phase:job.name,jobId:j.id});
  await processJob(job);
  await note(dir,{event:'PROCESSOR_END',phase:job.name,jobId:j.id});
 }catch{
  await note(dir,{event:'REDELIVERY_OR_GUARD_DENIED',phase:job.name,jobId:job.data.id});await writeFile(dir+'/stopped','DENIED');
  throw new UnrecoverableError('WORKFLOW_GUARD_DENIED');
 }
},{connection:redis as any,concurrency:1,maxStalledCount:0,maxStartedAttempts:1,lockDuration:10000,stalledInterval:1000});
async function exists(p:string){try{await readFile(p);return true;}catch{return false;}}
worker.on('error',()=>console.log('{"event":"QUEUE_ERROR"}'));
worker.on('stalled',()=>{void readFile(root+'/active.json','utf8').then(JSON.parse).then(c=>writeFile(root+'/cases/'+c.case+'/stopped','STALLED'));});
let closing=false;
let sweeping:Promise<any>|undefined;
const timer=setInterval(()=>{if(!closing&&!sweeping)sweeping=sweep().finally(()=>{sweeping=undefined;});},1000);
async function shutdown(){if(closing)return;closing=true;clearInterval(timer);await worker.close();await sweeping;await sweep();await queue.close();redis.disconnect();await db.$disconnect();process.exit(0);}
for(const s of ['SIGINT','SIGTERM'])process.once(s,()=>{void shutdown();});
console.log('{"event":"LAB_CONSUMER_READY","concurrency":1,"maxStalledCount":0,"maxStartedAttempts":1}');

}
main().catch(()=>{console.error('CONSUMER_START_FAILED');process.exitCode=1;});
