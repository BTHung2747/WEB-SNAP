// Cobalt metadata worker. Private result goes only to supervisor pipe, not Docker stdout/logs.
import fs from 'node:fs';
import resolver from './vendor/tiktok.js';
import { extract, normalizeURL } from './vendor/url.js';
import { createTransport, safe } from './transport.mjs';
const input=process.argv[2],out='/out',start=performance.now(),controller=new AbortController();
const report={startUTC:new Date().toISOString(),stage:'metadata',input:safe(input),cobaltCommit:'a636575b09de1fc55d9b8cd98cac88f5f2f16b42',metadata:'FAIL',file:'NOT_RUN',watermark:'NOT_RUN',requests:[],cookies:'fresh anonymous RAM only'};
fs.writeFileSync(`${out}/attempt-reserved.json`,JSON.stringify({input:safe(input),startUTC:report.startUTC}),{flag:'wx'});
const timer=setTimeout(()=>controller.abort(new Error('METADATA_DEADLINE')),28000);
const transport=createTransport({report,signal:controller.signal,
 onStageUpdate:data=>fs.writeFileSync(`${out}/transport-progress.json`,JSON.stringify(data))});globalThis.fetch=transport.fetch;
let contract=null;
try{
 const parsed=extract(normalizeURL(input));if(parsed.host!=='tiktok'||parsed.error)throw new Error('INVALID_TIKTOK_INPUT');
 const resolved=await resolver({...parsed.patternMatch,h265:false,isAudioOnly:false,fullAudio:false,alwaysProxy:false});
 if(resolved.error)throw new Error(`COBALT_${resolved.error}`);
 const m=resolved.lab;
 if(!m||String(m.id)!==String(m.resolvedPostId)||(parsed.patternMatch.postId&&String(m.id)!==parsed.patternMatch.postId))throw new Error('CONTENT_ID_MISMATCH');
 if(m.privateItem||m.imagePost||!Number.isFinite(m.duration)||m.duration<=0||m.duration>600)throw new Error('UNSUPPORTED_CONTENT_OR_DURATION');
 if(typeof resolved.urls!=='string'||!resolved.urls.startsWith('https://')||m.source!=='playAddr')throw new Error('NO_PLAY_SOURCE');
 report.metadata='PASS';report.id=String(m.id);report.duration=m.duration;report.sourceProvenance=m.source;
 contract={id:report.id,duration:m.duration,source:resolved.urls,video:m.video,cookie:String(resolved.headers?.cookie||''),webpage:input,provenance:m.source};
}catch(error){report.error=safe(`${error.name}: ${error.message}`);process.exitCode=20}
finally{
 clearTimeout(timer);await transport.close();report.totalDecodedBytes=transport.budget.total;report.endUTC=new Date().toISOString();report.seconds=(performance.now()-start)/1000;
 fs.writeFileSync(`${out}/metadata.json`,JSON.stringify(report,null,2),{flag:'wx'});
 process.stdout.write(JSON.stringify({report,contract}));
}
