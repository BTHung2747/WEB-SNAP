// Offline doubles only for core DB and internal HTTP; actual public/profile validators run.
const assert=require('node:assert/strict'),fs=require('node:fs'),Module=require('node:module');
const {EventEmitter}=require('node:events');
const core='/app/packages/shared/src/core.ts';
class AppError extends Error {constructor(code){super(code);this.code=code;}}
const stub=new Module(core);stub.loaded=true;stub.exports={AppError};require.cache[core]=stub;
const {checkedVideoFormats,selectedVideo,videoTransfer,fullHdVideo}=require('/app/packages/shared/src/tiktok-video.ts');
const metadata=JSON.parse(fs.readFileSync('/out/metadata.json'));
const rows=checkedVideoFormats(metadata.formats,'7678642036060228885');
const items=[{kind:'video',formats:rows}],pair=rows.find(r=>r.selection.audioSource),single=rows.find(r=>r.sourceDefault);
assert.equal(videoTransfer(items,single.id,'7678642036060228885'),undefined);
assert.deepEqual(videoTransfer(items,pair.id,'7678642036060228885'),{profile:'hevc-copy-pair',selection:pair.id});
for(const mutate of [r=>r.selection.contentId='1111111111111111111',r=>r.selection.audioSource.acodec='none',r=>r.width=1440,r=>r.selection.video.width=1440,r=>r.id='tt2_'+'0'.repeat(64),r=>r.highest=false]){
  const changed=structuredClone(rows);mutate(changed.find(r=>r.id===pair.id));
  assert.throws(()=>checkedVideoFormats(changed,'7678642036060228885'));
}
assert.throws(()=>selectedVideo([{kind:'photo',formats:rows}],pair.id,'7678642036060228885'));
assert.equal(fullHdVideo(1080,1920),true);assert.equal(fullHdVideo(1440,2560),false);
const {initialSourceFormat}=require('/app/apps/web/src/lib/source-quality.ts');
assert.equal(initialSourceFormat([...rows].reverse()),single.id);
assert.equal(initialSourceFormat(rows.filter(r=>!r.sourceDefault)),pair.id);
// Delegate all request mechanics to a bounded fake response; no sockets or credentials.
const http=require('node:http');let tamper=null,requests=[],sequence=0;
http.request=(_opts,callback)=>{
  const request=new EventEmitter();request.destroy=()=>{};
  request.end=body=>{
    const p=JSON.parse(body);requests.push(p);sequence++;
    const reply={v:p.v||1,id:p.id,job:p.job,phase:p.phase,epoch:'e'.repeat(64),state:p.op==='open'?'OPEN':'ACCEPTED',connections:p.op==='open'?0:p.v===2?4:3,
      ...(p.v===2?{profile:p.profile,selection:p.selection}:{}),...(p.op==='open'?{connectKey:'f'.repeat(64)}:{})};
    if(tamper==='selection')reply.selection='tt2_'+'0'.repeat(64);
    if(tamper==='profile')reply.profile='single';
    if(tamper==='connections')reply.connections=5;
    if(tamper==='extra')reply.unknown=true;
    process.nextTick(()=>{const res=new EventEmitter();res.statusCode=200;res.destroy=()=>{};callback(res);res.emit('data',Buffer.from(JSON.stringify(reply)));res.emit('end');});
  };return request;
};
const {ProxyPhase}=require('/app/apps/worker/src/proxy-phase.ts');
process.env.TIKTOK_EGRESS_POLICY_ENABLED='1';process.env.TIKTOK_EGRESS_CONTROL_SECRET='a'.repeat(64);
(async()=>{
  const selection=videoTransfer(items,pair.id,'7678642036060228885');
  const phase=await ProxyPhase.open('prepare','job','worker',performance.now()+30000,selection);
  assert.equal(phase.childEnv().WED_MEDIA_SELECTION,pair.id);
  assert.equal(await phase.finish(()=>false),4);
  const {createHmac}=require('node:crypto'),open=requests[0];
  assert.equal(open.job,createHmac('sha256','a'.repeat(64)).update(JSON.stringify(['job','worker','prepare',open.id,selection.profile,selection.selection])).digest('hex'));
  for(tamper of ['selection','profile','connections','extra'])await assert.rejects(()=>ProxyPhase.open('prepare','job','worker',performance.now()+30000,selection));
  tamper=null;
  const legacy=await ProxyPhase.open('prepare','photo','worker',performance.now()+30000);
  assert.equal(legacy.childEnv().WED_MEDIA_PROFILE,undefined);assert.equal(await legacy.finish(()=>false),3);
  await assert.rejects(()=>ProxyPhase.open('analyze','job','worker',performance.now()+30000,selection));
  fs.writeFileSync('/out/pair-ts-result.json',JSON.stringify({status:'PASS',sourceRequests:0,groups:4,
    cases:['public-plan-hash-body-codec-dimensions-tamper','source-default-not-array-order','profile-HMAC-and-reply-tamper','legacy-single-photo-3-vs-pair4'],httpDoubleCalls:sequence},null,2));
  console.log('PASS TS public format / default / profile binding groups4');
})().catch(()=>{console.error('PAIR_TS_CHECK_FAILED');process.exitCode=1;});
