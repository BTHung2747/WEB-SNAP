const fs=require('node:fs'),crypto=require('node:crypto');
const packages={};
for(const name of ['zod','express','@prisma/client','bullmq','tsx','typescript']){
 const p=require.resolve(name+'/package.json',{paths:['/app']});
 packages[name]={version:JSON.parse(fs.readFileSync(p)).version,manifestSHA256:crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')};
}
const z=require('/app/node_modules/zod');
if(z.z.object({a:z.z.number().int().positive().safe()}).strict().safeParse({a:1,secret:2}).success)throw Error('Strict schema failed');
const express=require('/app/node_modules/express');
if(typeof express.response.setHeader!=='function'||typeof express.response.status!=='function')throw Error('Response API missing');
const sourceFiles=['/app/node_modules/zod/v3/types.cjs','/app/node_modules/express/lib/response.js'].filter(fs.existsSync).map(path=>({path,sha256:crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')}));
fs.writeFileSync('/control/node-capability.json',JSON.stringify({node:process.version,packages,sourceFiles,strictUnknownKeysRejected:true},null,2));
