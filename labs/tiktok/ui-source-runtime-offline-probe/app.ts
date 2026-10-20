import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
const require=createRequire('/app/package.json');
async function main(){
 assert.equal(process.platform,'linux');assert.equal(process.arch,'x64');assert.equal(process.versions.node.split('.')[0],'22');
 assert.notEqual(process.env.STEP5_EXECUTE_SOURCE,'1');
 const versions=Object.fromEntries(['tsx','zod','@prisma/client','bullmq','ioredis'].map(name=>[name,require(name+'/package.json').version]));
 assert.deepEqual(versions,{tsx:'4.20.5',zod:'3.25.76','@prisma/client':'6.19.0',bullmq:'5.81.5',ioredis:'5.7.0'});
 // Actual core has eager clients: offline URLs point solely to private namespace
 // loopback port1, never real services. Close through public APIs, no stub module.
 const core=await import('/app/packages/shared/src/core');
 core.redis.on('error',()=>{});core.queue.on('error',()=>{});
 core.redis.disconnect(false);
 let timer:NodeJS.Timeout|undefined;
 try{await Promise.race([Promise.all([core.queue.close(),core.db.$disconnect()]),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('CLIENT_CLOSE_DEADLINE')),1000);})]);}finally{clearTimeout(timer);}
 const photos=await import('/app/packages/shared/src/tiktok-photo');
 const api=await import('/app/apps/api/src/validation');
 const worker=await import('/app/apps/worker/src/proxy-phase');
 assert.equal(typeof worker.ProxyPhase.open,'function');
 const id='7000000000000000001',index=1,width=32,height=32;
 const hash=(value:unknown)=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
 // Synthetic fixture fields inserted in the contract's canonical key order;
 // native crypto/JSON only, no copied private parser/validator/canonicalizer.
 const itemKey=hash([id,'photo',index,width,height]);
 const image={height,index,itemKey,width};
 const structure={id,imageCount:1,images:[image],type:'photo',version:'tt-photo-album-v1'};
 const snapshotKey=hash(structure),format={index,width,height,itemKey,id:'ttp1_01_'+snapshotKey,label:'Ảnh 1/1',size:null,kind:'photo',contentId:id,imageCount:1,mime:'image/jpeg',snapshotKey};
 const value={kind:'photo',title:'Album TikTok',duration:null,summary:{...structure,snapshotKey},formats:[format]};
 const checked=photos.checkedPhotoMetadata(value,id);assert.equal(checked.formats.length,1);
 assert.throws(()=>photos.checkedPhotoMetadata({...value,untrusted:'SYNTHETIC'},id),e=>(e as any).code==='FORMAT_UNAVAILABLE');
 assert.throws(()=>photos.checkedPhotoMetadata(value,'7000000000000000002'),e=>(e as any).code==='FORMAT_UNAVAILABLE');
 assert.equal(api.inputSchema.safeParse({url:'SYNTHETIC_INPUT_ONLY'}).success,true);
 assert.equal(api.inputSchema.safeParse({url:'SYNTHETIC_INPUT_ONLY',extra:1}).success,false);
 assert.throws(()=>photos.requirePhotoEnabled(['tiktok']),e=>(e as any).code==='UNSUPPORTED_PLATFORM');
 console.log(JSON.stringify({kind:'role',role:'app',ok:true,node:process.versions.node,platform:process.platform,versions,imports:['core','tiktok-photo','api/validation','worker/proxy-phase'],schemaPositive:true,schemaNegativeExtra:true,schemaNegativeBodyID:true,apiInputPositive:true,apiInputNegative:true,sourceCapabilityDisabled:true,clientsClosed:true,fixture:'SYNTHETIC_SCHEMA_NOT_SOURCE_METADATA',serviceStarted:false}));
}
main().catch(()=>{console.log(JSON.stringify({kind:'failure',role:'app',stage:'NODE_IMPORT_SCHEMA_OR_CLIENT_CLOSE'}));process.exitCode=20;});
