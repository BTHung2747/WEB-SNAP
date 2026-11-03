import assert from 'node:assert/strict';
import {readFile,writeFile,mkdir,symlink,unlink,rm,open} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {mirrorSourceDiagnostics} from '../apps/worker/src/source-diagnostics';
async function main(){
 const result=JSON.parse(await readFile('/out/python-results.json','utf8'));const logs:any[]=[];
 for(const row of result.cases){await mirrorSourceDiagnostics('/media',row.id,'analyze','youtube',r=>logs.push(r));}
 assert.equal(logs.length,4);assert.ok(logs.some(r=>r.reason==='UNKNOWN'&&r.exceptionClass==='DownloadError'));
 await mirrorSourceDiagnostics('/media',result.previewId,'analyze','preview',r=>logs.push(r));assert.equal(logs.at(-1).code,'NO_GRANT');
 assert.ok(!JSON.stringify(logs).includes('secret'));
 const id=randomUUID(),dir='/media/'+id;await mkdir(dir);const file=dir+'/youtube-diagnostic.json';
 const valid={version:1,phase:'analyze',gate:'EXTRACTOR',reason:'UNKNOWN',exceptionClass:'DownloadError',causeClass:'ExtractorError'};
 for(const payload of [{...valid,reason:'https://secret.invalid/token'},{...valid,extra:'cookie'},'x'.repeat(1025),'{']){
  await writeFile(file,typeof payload==='string'?payload:JSON.stringify(payload));const before=logs.length;await mirrorSourceDiagnostics('/media',id,'analyze','youtube',r=>logs.push(r));assert.equal(logs.length,before);
 }
 await unlink(file);await writeFile('/out/symlink-valid-receipt.json',JSON.stringify(valid));await symlink('/out/symlink-valid-receipt.json',file);const beforeSymlink=logs.length;await mirrorSourceDiagnostics('/media',id,'analyze','youtube',r=>logs.push(r));assert.equal(logs.length,beforeSymlink);await unlink(file);
 assert.equal(spawnSync('mkfifo',[file]).status,0);const start=Date.now();await mirrorSourceDiagnostics('/media',id,'analyze','youtube',()=>{throw Error('FIFO')});assert.ok(Date.now()-start<1000);await unlink(file);
 await writeFile(file,JSON.stringify(valid));let called=0;assert.equal(await mirrorSourceDiagnostics('/media',id,'analyze','youtube',()=>{called++;throw Error('secret logger failure')}),undefined);assert.equal(called,1);
 const before=logs.length;await mirrorSourceDiagnostics('/media',id,'prepare','youtube',r=>logs.push(r));assert.equal(logs.length,before);
 const folderLink=randomUUID();await symlink(dir,'/media/'+folderLink);await mirrorSourceDiagnostics('/media',folderLink,'analyze','youtube',r=>logs.push(r));assert.equal(logs.length,before);
 await mirrorSourceDiagnostics('/media','../../foreign','analyze','youtube',r=>logs.push(r));assert.equal(logs.length,before);
 // Observe before cleanup; deleting own receipts afterwards does not remove the safe event.
 await rm('/media/'+result.previewId,{recursive:true});assert.equal(logs.at(-1).code,'NO_GRANT');
 const src=await readFile('/app/apps/worker/src/adapter.ts','utf8');const closed=src.indexOf('groupStopped = true;');const mirror=src.indexOf('await mirrorSourceDiagnostics',closed);const parse=src.indexOf('JSON.parse(output',closed);assert.ok(closed<mirror&&mirror<parse);
 await writeFile('/out/worker-results.json',JSON.stringify({result:'PASS_OFFLINE',events:logs,checks:['strict-schema-cap','secret-rejection','nofollow-file-folder','FIFO-nonblocking','phase-binding','logger-throw-best-effort','producer-to-parent-before-cleanup','adapter-wiring-before-error-parse'],sourceCalls:0},null,2));
 console.log('WORKER_DIAGNOSTICS_PASS producer-receipts/strictprivacy/ownership/logger-failure/cleanup/wiring');
}
main().catch(()=>{console.error('WORKER_DIAGNOSTICS_CHECK_FAILED');process.exitCode=20;});
