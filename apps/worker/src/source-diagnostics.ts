// Two fixed child receipts only. No arbitrary path, exception message, or metadata.
import {constants} from 'node:fs';
import {open,realpath,lstat} from 'node:fs/promises';
import path from 'node:path';
import {z} from 'zod';
const count=z.number().int().min(0).max(50),bytes=z.number().int().min(0).max(8*1024*1024);
const preview=z.object({version:z.literal(1),outcome:z.enum(['SKIPPED','PENDING','FAIL']),
  stage:z.enum(['CANDIDATES','GRANT','FETCH','INPUT_WRITE','NORMALIZE','JPEG','IMAGE_WRITE','INDEX']),
  code:z.enum(['OK','INVALID_CANDIDATES','NO_GRANT','PREVIEW_DEADLINE','PREVIEW_SIZE','PREVIEW_TYPE','PREVIEW_STREAMS','PREVIEW_PIXELS','PREVIEW_DECODE','PREVIEW_NATIVE','PREVIEW_INDEX','PREVIEW_THREADS','PREVIEW_WORKER','PREVIEW_FETCH','PREVIEW_REAP','SUBPROCESS_TIMEOUT','JSON_INVALID','ENOENT','EACCES','EEXIST','ELOOP','EPERM','EIO','OS_ERROR','UNKNOWN']),
  count,completedCount:count,sourceBytes:bytes,lastSourceBytes:z.number().int().min(0).max(512*1024),outputBytes:bytes,
  remainingSeconds:z.number().finite().min(-30).max(30),elapsedSeconds:z.number().finite().min(0).max(30)}).strict();
const exceptionClass=z.enum(['DownloadError','ExtractorError','GeoRestrictedError','UnavailableVideoError','Rejected','AudioError','UNKNOWN']);
const youtube=z.object({version:z.literal(1),phase:z.enum(['analyze','prepare']),
  gate:z.enum(['EXTRACTOR','METADATA','METADATA_AUTH','METADATA_AGE','PROCESSING']),
  reason:z.enum(['PRIVATE','PREMIUM_ONLY','SUBSCRIBER_ONLY','NEEDS_AUTH','AGE_RESTRICTED','GEO_RESTRICTED','SOURCE_SIGN_IN_MESSAGE','SOURCE_AGE_MESSAGE','SOURCE_BOT_VERIFICATION_MESSAGE','UNKNOWN']),exceptionClass,causeClass:exceptionClass}).strict();
export async function mirrorSourceDiagnostics(root:string,id:string,phase:string,kind:'preview'|'youtube'|'facebook',emit:(row:unknown)=>void=row=>console.log(JSON.stringify(row))) {
  let directory:Awaited<ReturnType<typeof open>>|undefined,file:Awaited<ReturnType<typeof open>>|undefined;
  try {
    if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(id) || !['analyze','prepare'].includes(phase) || (kind==='preview'&&phase!=='analyze'))return;
    const base=path.resolve(root),folder=path.join(base,id),st=await lstat(base);
    if(!st.isDirectory()||st.isSymbolicLink()||await realpath(base)!==base)return;
    directory=await open(folder,constants.O_RDONLY|constants.O_DIRECTORY|constants.O_NOFOLLOW);
    if(await realpath(folder)!==folder)return;
    // Pin the opened directory for the fixed leaf read. NONBLOCK rejects FIFOs without waiting.
    file=await open(`/proc/self/fd/${directory.fd}/${kind==='preview'?'preview-diagnostic.json':kind+'-diagnostic.json'}`,constants.O_RDONLY|constants.O_NOFOLLOW|constants.O_NONBLOCK);
    const before=await file.stat();if(!before.isFile()||before.size<=0||before.size>1024)return;
    const buffer=Buffer.alloc(1025);let used=0;
    while(used<buffer.length){const r=await file.read(buffer,used,buffer.length-used,used);if(!r.bytesRead)break;used+=r.bytesRead;}
    const after=await file.stat();if(used!==before.size||before.size!==after.size||before.mtimeMs!==after.mtimeMs)return;
    const raw:unknown=JSON.parse(buffer.subarray(0,used).toString('utf8'));
    const parsed=kind==='preview'?preview.safeParse(raw):youtube.safeParse(raw);
    if(!parsed.success)return;
    if('phase' in parsed.data && parsed.data.phase!==phase)return;
    emit({event:kind==='preview'?'preview_generation_diagnostic':kind+'_source_diagnostic',id,phase,...parsed.data});
  } catch { /* Best-effort only, including logger failure. */ }
  finally {try{await file?.close();}catch{}try{await directory?.close();}catch{}}
}
