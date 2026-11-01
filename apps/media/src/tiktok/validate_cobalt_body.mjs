// Reuse pinned Cobalt parser on the final yt-dlp webpage in RAM; zero network requests.
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import resolver from './vendor/tiktok.js';
try{
  const id=process.argv[2],body=fs.readFileSync(0);
  if(!/^\d{15,22}$/.test(id)||body.length>8*1024*1024)throw new Error('INPUT_POLICY');
  globalThis.fetch=async url=>{
    if(url!=='https://www.tiktok.com/@i/video/'+id)throw new Error('PARSER_SCOPE');
    return {headers:new Headers(),text:async()=>body.toString('utf8')};
  };
  const result=await resolver({postId:id,h265:false,isAudioOnly:false,alwaysProxy:false});
  const m=result.lab;
  if(result.error==='content.post.age'||m?.privateItem){process.stdout.write(JSON.stringify({status:'FAIL',error:'AUTH_REQUIRED'}));process.exit(20);}
  if(result.picker||m?.imagePost){process.stdout.write(JSON.stringify({status:'FAIL',error:'UNSUPPORTED_CONTENT'}));process.exit(20);}
  if(result.error||!m||String(m.id)!==id||String(m.resolvedPostId)!==id||m.privateItem||m.imagePost||
     !Number.isFinite(m.duration)||m.duration<=0||m.duration>600||m.source!=='playAddr')throw new Error('CONTENT_POLICY');
  // No play URL, HTML, cookie, token or original exception is emitted.
  // Opaque URL digest stays in the private RAM pipe; never store it in public rows/logs.
  const defaultUrlSHA256=typeof result.urls==='string' && result.urls.startsWith('https://')
    ? createHash('sha256').update(result.urls).digest('hex') : null;
  process.stdout.write(JSON.stringify({status:'PASS',id:String(m.id),duration:m.duration,photo:false,private:false,defaultUrlSHA256}));
}catch{
  process.stdout.write(JSON.stringify({status:'FAIL',error:'CONTENT_UNAVAILABLE'}));process.exitCode=20;
}
