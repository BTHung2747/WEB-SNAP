import assert from 'node:assert/strict';
import { guard, client, analyze, call, job, wait, close } from './p3-support';
async function main() {
  await guard();
  const c = await client(), selected = await analyze(c, 'fixture0001');
  await call(c, `jobs/${selected.id}/prepare`, selected.selection);
  await wait('normal fixture ready', async () => (await job(selected.id)).state === 'ready', 20000);
  const ticket = await call(c, `jobs/${selected.id}/download-ticket`);
  const url = 'http://api:3000' + ticket.url;
  const headers = { cookie: c.cookie };
  const head = await fetch(url, { method: 'HEAD', headers }); assert.equal(head.status, 200);
  const total = Number(head.headers.get('content-length')); assert.ok(total > 1000);
  const full = await fetch(url, { headers }); assert.equal(full.status, 200);
  const bytes = Buffer.from(await full.arrayBuffer()); assert.equal(bytes.length, total);
  for (const range of ['bytes=0-99', 'bytes=100-199', 'bytes=-100']) {
    const r = await fetch(url, { headers: { ...headers, range } }); assert.equal(r.status, 206);
    const chunk = Buffer.from(await r.arrayBuffer());
    assert.deepEqual(chunk, range === 'bytes=-100' ? bytes.subarray(total - 100) : range === 'bytes=0-99' ? bytes.subarray(0, 100) : bytes.subarray(100, 200));
  }
  const chunks = await Promise.all([200, 300].map(async start => {
    const r = await fetch(url, { headers: { ...headers, range: `bytes=${start}-${start + 99}` } });
    assert.equal(r.status, 206); return Buffer.from(await r.arrayBuffer());
  }));
  assert.deepEqual(chunks, [bytes.subarray(200, 300), bytes.subarray(300, 400)]);
  const bad = await fetch(url, { headers: { ...headers, range: `bytes=${total}-` } }); assert.equal(bad.status, 416);
  console.log(JSON.stringify({ test: 'normal-prepare-Range-regression', result: 'PASS', full: 200, head: 200, range: 206, suffix: 206, parallel: 2, invalid: 416, fixtureOnly: true, date: new Date().toISOString() }));
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'P3_RANGE_FAILED'); process.exitCode = 1; }).finally(close);
