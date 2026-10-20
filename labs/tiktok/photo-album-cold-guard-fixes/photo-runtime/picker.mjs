// AGPL-3.0 lab glue. Cobalt owns imagePost parsing and ordered JPEG selection.
import fs from 'node:fs';
import resolver from './vendor/tiktok.js';
try {
 const id=process.argv[2],body=fs.readFileSync(0);
 if(!/^\d{15,22}$/.test(id)||body.length>8*1024*1024)throw new Error();
 globalThis.fetch=async url=>{
  if(url!=='https://www.tiktok.com/@i/video/'+id)throw new Error();
  return {headers:new Headers(),text:async()=>body.toString('utf8')};
 };
 const r=await resolver({postId:id,h265:false,isAudioOnly:false,alwaysProxy:false});
 if(r.error||!r.lab||r.lab.id!==id||r.lab.resolvedPostId!==id||!r.lab.imagePost||r.lab.privateItem||
    !Array.isArray(r.picker)||!r.picker.length||r.picker.length>50)throw new Error();
 const images=r.picker.map((p,i)=>{
  if(p.type!=='photo'||typeof p.url!=='string')throw new Error();
  const u=new URL(p.url);if(u.protocol!=='https:'||u.username||u.password||(u.port&&u.port!=='443'))throw new Error();
  const dim=n=>Number.isInteger(n)&&n>0&&n<=8192?n:null;
  return {index:i+1,url:p.url,width:dim(r.lab.dimensions[i]?.[0]),height:dim(r.lab.dimensions[i]?.[1])};
 });
 // Private pipe only: parent does not read this packet; Python retains URLs in RAM, never evidence.
 process.stdout.write(JSON.stringify({id,type:'photo',images}));
}catch {process.stdout.write(JSON.stringify({error:'PHOTO_METADATA_UNAVAILABLE'}));process.exitCode=20;}
