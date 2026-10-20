import assert from 'node:assert/strict';
import zlib from 'node:zlib';
import { MockAgent, fetch } from 'undici';
import resolver from './vendor/tiktok.js';
import { boundedText, createTransport, safe, RESPONSE_CAP, AGG_CAP } from './transport.mjs';
import { classifyHTML } from './classify.mjs';
import { createHash } from 'node:crypto';
let passed = 0;
async function test(name, body) { await body(); passed++; console.log(`PASS ${name}`); }
await test('stream clamp before concat and aggregate cap', async () => {
  const body = new ReadableStream({ start(c) { c.enqueue(new Uint8Array(200)); c.close(); } });
  const budget = { responseCap: 64, aggregateCap: 100, total: 0 }, row = {};
  await assert.rejects(boundedText(body, budget, row), /LIMIT_EXCEEDED/);
  assert.equal(budget.total, 65); assert.equal(row.decodedBytes, 65);
  const under = new ReadableStream({ start(c) { c.enqueue(new Uint8Array(40)); c.close(); } });
  const aggregate = { responseCap: 100, aggregateCap: 50, total: 20 };
  await assert.rejects(boundedText(under, aggregate, {}), /LIMIT_EXCEEDED/); assert.equal(aggregate.total, 51);
});
await test('Undici decoded gzip cap, not compressed Content-Length', async () => {
  const mock = new MockAgent(); mock.disableNetConnect();
  const compressed = zlib.gzipSync(Buffer.alloc(1024, 65));
  mock.get('https://www.tiktok.com').intercept({ path:'/fixture', method:'GET' }).reply(200, compressed, {headers:{'content-encoding':'gzip'}});
  const report = {requests:[]}; const transport = createTransport({report, dispatcher:mock, responseCap:64, aggregateCap:128});
  const response = await transport.fetch('https://www.tiktok.com/fixture');
  await assert.rejects(response.text(), /LIMIT_EXCEEDED/); assert.equal(transport.budget.total,65);
  await mock.close();
});
await test('Brotli library decode preserves complete fake challenge HTML; boolean diagnostics only', async () => {
  const payload=Buffer.from(JSON.stringify({v:{a:'FAKEHASH',c:'FAKEDIGEST'},url:'https://host.invalid/FAKEPATH?token=FAKEQUERY'})).toString('base64');
  const html=`<html><title>Please wait...</title><div id="cs" class="${payload}"></div><div class="FAKECOOKIE" id="wci"></div><div id="rci" class="FAKESESSION"></div></html>`;
  const compressed=zlib.brotliCompressSync(Buffer.from(html));
  const mock=new MockAgent();mock.disableNetConnect();
  mock.get('https://host.invalid').intercept({path:'/fake',method:'GET'}).reply(200,compressed,{headers:{'content-type':'text/html','content-encoding':'br','content-length':String(compressed.length)}});
  const report={requests:[]},transport=createTransport({report,dispatcher:mock});
  assert.equal(await (await transport.fetch('https://host.invalid/fake')).text(),html);
  const row=report.requests[0];assert.equal(row.decodedBytes,Buffer.byteLength(html));
  assert.equal(row.decodedBodySHA256,createHash('sha256').update(html).digest('hex'));
  assert.equal(row.markers.captcha,false);assert.equal(row.classification.csElement,true);
  assert.equal(row.classification.wciElement,true);assert.equal(row.classification.challengeDataJSON,true);
  assert.equal(row.classification.challengeDigestFields,true);assert.equal(row.classification.rehydrationElement,false);
  assert.doesNotMatch(JSON.stringify(report),/FAKE|host\.invalid/);await mock.close();
});
await test('diagnostic negatives/malformed data and rehydration do not manufacture metadata',async()=>{
  assert.equal(classifyHTML('<html>normal page</html>').challengeDataJSON,false);
  const malformed=classifyHTML('<div class="INVALID-FAKE" id="cs"></div><div id="wci" class="FAKECOOKIE"></div>');
  assert.equal(malformed.csElement,true);assert.equal(malformed.challengeDataJSON,false);
  assert.equal(classifyHTML('<script type="application/json" id="__UNIVERSAL_DATA_FOR_REHYDRATION__">{}</script>').rehydrationElement,true);
});
await test('actual 8 MiB response and 16 MiB aggregate decoded limits while reading', async () => {
  assert.equal(RESPONSE_CAP,8*1024*1024);assert.equal(AGG_CAP,16*1024*1024);
  const body=n=>new ReadableStream({start(c){for(let i=0;i<n;i+=16384)c.enqueue(Buffer.alloc(Math.min(16384,n-i),65));c.close();}});
  const response={responseCap:RESPONSE_CAP,aggregateCap:AGG_CAP,total:0};
  await assert.rejects(boundedText(body(RESPONSE_CAP+100),response,{}),/LIMIT_EXCEEDED/);
  assert.equal(response.total,RESPONSE_CAP+1);
  const aggregate={responseCap:RESPONSE_CAP,aggregateCap:AGG_CAP,total:0};
  assert.equal((await boundedText(body(RESPONSE_CAP),aggregate,{})).length,RESPONSE_CAP);
  assert.equal((await boundedText(body(RESPONSE_CAP),aggregate,{})).length,RESPONSE_CAP);
  await assert.rejects(boundedText(body(20),aggregate,{}),/LIMIT_EXCEEDED/);
  assert.equal(aggregate.total,AGG_CAP+1);
});
await test('short delayed stream reaches EOF and does not starve timer', async () => {
  let timerRan=false;setTimeout(()=>{timerRan=true},5);
  const body=new ReadableStream({start(c){c.enqueue(Buffer.from('small network body'));setTimeout(()=>c.close(),20)}});
  const budget={responseCap:64,aggregateCap:128,total:0};
  assert.equal(await boundedText(body,budget,{}),'small network body');assert.equal(timerRan,true);
});
await test('upstream Cobalt parser/selection uses play, anonymous cookies, no downloadAddr', async () => {
  const detail={id:'7692808825228807442',author:{uniqueId:'fixture'},video:{duration:27,playAddr:'https://media.tiktokcdn.com/play',downloadAddr:'https://media.tiktokcdn.com/watermarked'}};
  const html='<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'+JSON.stringify({__DEFAULT_SCOPE__:{'webapp.video-detail':{statusCode:0,itemInfo:{itemStruct:detail}}}})+'</script>';
  globalThis.fetch=async () => ({headers:new Headers(),text:async()=>html});
  const result=await resolver({postId:detail.id,h265:false,isAudioOnly:false,alwaysProxy:false});
  assert.equal(result.urls,detail.video.playAddr);assert.equal(result.lab.id,detail.id);assert.equal(String(result.headers.cookie),'');
});
await test('metadata AbortSignal rejects delayed library request', async () => {
  const mock=new MockAgent();mock.disableNetConnect();mock.get('https://www.tiktok.com').intercept({path:'/slow',method:'GET'}).reply(200,'slow').delay(500);
  const transport=createTransport({report:{requests:[]},dispatcher:mock,signal:AbortSignal.timeout(20)});
  await assert.rejects(transport.fetch('https://www.tiktok.com/slow'));await mock.close();
});
await test('redaction and HTTPS gate', async () => {
  assert.doesNotMatch(safe('https://FAKE:FAKEPASS@host.invalid/FAKEPATH/token/FAKEPATH2?token=FAKEQUERY#FAKEFRAGMENT\nCookie: FAKECOOKIE'),/FAKE/);
  const t=createTransport({report:{requests:[]},dispatcher:new MockAgent()});
  await assert.rejects(t.fetch('http://127.0.0.1/'),/INVALID_HTTPS/);
});
console.log(JSON.stringify({fixtures:passed,network:'none; MockAgent only; no source request'}));
