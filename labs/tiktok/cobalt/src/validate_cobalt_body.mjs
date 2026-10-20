// Reuse pinned Cobalt parser on the final yt-dlp webpage in RAM; zero network requests.
import fs from 'node:fs';
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
  if(result.error||!m||String(m.id)!==id||String(m.resolvedPostId)!==id||m.privateItem||m.imagePost||
     !Number.isFinite(m.duration)||m.duration<=0||m.duration>600||m.source!=='playAddr')throw new Error('CONTENT_POLICY');
  // No play URL, HTML, cookie, token or original exception is emitted.
  process.stdout.write(JSON.stringify({status:'PASS',id:String(m.id),duration:m.duration,photo:false,private:false}));
}catch{
  process.stdout.write(JSON.stringify({status:'FAIL',error:'COBALT_BODY_ID_OR_CONTENT_VALIDATION'}));process.exitCode=20;
}
