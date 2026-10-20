import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import http from 'node:http';
import { db, redis, queue, defaults } from '../packages/shared/src/core';
const base = 'http://api:3000/api/v1/';
const origin = 'http://localhost:5174';
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
type Client = { cookie: string; csrf: string };
async function client(): Promise<Client> {
  const r = await fetch(base + 'session');
  const s = (await r.json()) as any;
  return { cookie: r.headers.get('set-cookie')!.split(';')[0], csrf: s.csrf };
}
async function call(c: Client, url: string, method = 'GET', body?: any, extra?: any) {
  const r = await fetch(base + url, {
    method,
    headers: {
      cookie: c.cookie,
      origin,
      'x-csrf-token': c.csrf,
      'content-type': 'application/json',
      ...extra,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: r.status, body: (await r.json()) as any };
}
async function waitJob(c: Client, id: string, state: string, ms = 40000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const r = await call(c, 'jobs/' + id);
    if (r.body.state === state) return r.body;
    if (['failed', 'expired', 'cancelled'].includes(r.body.state) && r.body.state !== state)
      throw new Error(`Expected ${state}, got ${JSON.stringify(r.body)}`);
    await pause(250);
  }
  throw new Error(`Timeout ${state}`);
}
const outcomes: any[] = [];
async function check(name: string, fn: () => Promise<void>) {
  await fn();
  outcomes.push({ name, result: 'PASS' });
  console.log('PASS ' + name);
}
async function prepare(c: Client, url = 'https://www.youtube.com/watch?v=fixture0001') {
  const a = await call(c, 'jobs/analyze', 'POST', { url });
  assert.equal(a.status, 202);
  const id = a.body.jobId;
  const j = await waitJob(c, id, 'selectable');
  const selection = { itemId: j.items[0].id, formatId: '18', idempotencyKey: randomUUID() };
  const p = await call(c, `jobs/${id}/prepare`, 'POST', selection);
  assert.equal(p.status, 202);
  return { id, selection };
}
async function ticket(c: Client, id: string) {
  const r = await call(c, `jobs/${id}/download-ticket`, 'POST');
  assert.equal(r.status, 201, JSON.stringify(r.body));
  return r.body.url.replace('/api/v1/', '');
}
async function main() {
  // Guard against running destructive tests against a real DB.
  if (process.env.APP_ORIGIN !== origin || process.env.VERIFIED_PLATFORMS !== 'youtube')
    throw new Error('Run ONLY with compose.test.yaml');
  let healthy = false;
  for (let i = 0; i < 30; i++) {
    try {
      healthy = (await fetch(base + 'health')).ok;
    } catch {}
    if (healthy) break;
    await pause(500);
  }
  assert.ok(healthy, 'API must be healthy');
  // Fixture campaign records are disposable in this isolated test database.
  await db.adCampaign.deleteMany({ where: { title: { startsWith: 'Fixture' } } });
  await db.settings.upsert({
    where: { id: 'main' },
    create: { value: defaults },
    update: { value: defaults },
  });
  const a = await client(),
    b = await client();
  await check('SSRF, shell injection and CSRF rejected', async () => {
    for (const url of [
      'http://127.0.0.1',
      'https://169.254.169.254',
      'https://youtube.com.evil.test/x',
      'https://youtube.com/watch?v=;touch%20/tmp/a',
    ])
      assert.equal((await call(a, 'jobs/analyze', 'POST', { url })).status, 400);
    const r = await call(
      a,
      'jobs/analyze',
      'POST',
      { url: 'https://youtu.be/fixture0001' },
      { 'x-csrf-token': 'wrong' },
    );
    assert.equal(r.status, 403);
  });
  const job = await prepare(a);
  await check('Double prepare creates one asset and one preparation', async () => {
    const p = await call(a, `jobs/${job.id}/prepare`, 'POST', job.selection);
    assert.equal(p.status, 202);
    await waitJob(a, job.id, 'ready');
    assert.equal(await db.temporaryAsset.count({ where: { jobId: job.id } }), 1);
  });
  await check('Session B cannot read/prepare/download session A', async () => {
    assert.equal((await call(b, 'jobs/' + job.id)).status, 404);
    assert.equal((await call(b, `jobs/${job.id}/prepare`, 'POST', job.selection)).status, 404);
    const t = await ticket(a, job.id);
    assert.equal((await fetch(base + t, { headers: { cookie: b.cookie } })).status, 410);
  });
  let t = await ticket(a, job.id);
  await check('Range 206, invalid 416, suffix and parallel requests', async () => {
    const r = await fetch(base + t, { headers: { cookie: a.cookie, Range: 'bytes=0-99' } });
    assert.equal(r.status, 206);
    assert.equal((await r.arrayBuffer()).byteLength, 100);
    assert.match(r.headers.get('content-range')!, /^bytes 0-99\//);
    const bad = await fetch(base + t, { headers: { cookie: a.cookie, Range: 'bytes=999999999-' } });
    assert.equal(bad.status, 416);
    assert.match(bad.headers.get('content-range')!, /^bytes \*\//);
    const chunks = await Promise.all(
      [0, 1, 2].map(async (i) => {
        const r = await fetch(base + t, {
          headers: {
            cookie: a.cookie,
            Range: i === 2 ? 'bytes=-100' : `bytes=${i * 100}-${i * 100 + 99}`,
          },
        });
        assert.equal(r.status, 206);
        return (await r.arrayBuffer()).byteLength;
      }),
    );
    assert.deepEqual(chunks, [100, 100, 100]);
  });
  await check(
    'Release while active transfer does not stop stream; retry survives expired page',
    async () => {
      const body = await new Promise<Buffer>((resolve, reject) => {
        http
          .get(base + t, { headers: { cookie: a.cookie } }, (res) => {
            res.pause();
            setTimeout(async () => {
              try {
                const r = await call(a, `jobs/${job.id}/release`, 'POST');
                assert.equal(r.status, 201);
                await pause(2500);
                const leases = await db.transferLease.count({
                  where: { asset: { jobId: job.id }, state: 'started' },
                });
                assert.ok(leases >= 1);
                const j = await db.downloadJob.findUniqueOrThrow({ where: { id: job.id } });
                assert.equal(j.cancelRequested, false);
                const chunks: Buffer[] = [];
                res.on('data', (chunk) => chunks.push(chunk));
                res.on('end', () => resolve(Buffer.concat(chunks)));
                res.resume();
              } catch (e) {
                reject(e);
                res.destroy();
              }
            }, 500);
            res.on('error', reject);
          })
          .on('error', reject);
      });
      assert.ok(body.length > 1000000);
      const r = await fetch(base + t, { headers: { cookie: a.cookie, Range: 'bytes=100-199' } });
      assert.equal(r.status, 206);
      assert.equal((await r.arrayBuffer()).byteLength, 100);
    },
  );
  await check('Safe cleanup after retry grace, tickets return 410', async () => {
    await pause(5000);
    const asset = await db.temporaryAsset.findUniqueOrThrow({ where: { jobId: job.id } });
    assert.equal(asset.state, 'deleted');
    assert.equal((await fetch(base + t, { headers: { cookie: a.cookie } })).status, 410);
  });
  await check('Release during analyzing delay reaches terminal state', async () => {
    const r = await call(b, 'jobs/analyze', 'POST', {
      url: 'https://www.youtube.com/watch?v=delay000001',
    });
    assert.equal(r.status, 202);
    await pause(1000);
    const beforeRelease = await db.downloadJob.findUniqueOrThrow({ where: { id: r.body.jobId } });
    assert.equal(beforeRelease.state, 'analyzing');
    assert.ok(beforeRelease.workerToken);
    await call(b, `jobs/${r.body.jobId}/release`, 'POST');
    await pause(5000);
    const j = await db.downloadJob.findUniqueOrThrow({ where: { id: r.body.jobId } });
    assert.ok(['cancelled', 'expired'].includes(j.state));
    assert.equal(j.workerToken, null);
  });
  // Reset admission window to avoid conflating policy checks with rate-limit tests.
  const c = await client();
  const second = await prepare(c);
  await waitJob(c, second.id, 'ready');
  const t2 = await ticket(c, second.id);
  await check('Budget blocks a new transfer; existing files remain', async () => {
    const current = await db.settings.findUniqueOrThrow({ where: { id: 'main' } });
    const value = { ...(current.value as any), monthlyBytes: 0 };
    await db.settings.update({ where: { id: 'main' }, data: { value } });
    assert.equal((await fetch(base + t2, { headers: { cookie: c.cookie } })).status, 503);
    assert.equal(
      (await db.temporaryAsset.findUniqueOrThrow({ where: { jobId: second.id } })).state,
      'available',
    );
    await db.settings.update({ where: { id: 'main' }, data: { value: current.value as any } });
  });
  await check('Disconnect ends transfer lease; cleanup is deferred', async () => {
    await new Promise<void>((resolve, reject) => {
      http
        .get(base + t2, { headers: { cookie: c.cookie } }, (res) => {
          res.once('data', () => {
            res.destroy();
            resolve();
          });
          res.on('error', () => {});
        })
        .on('error', reject);
    });
    await pause(300);
    const leases = await db.transferLease.findMany({ where: { asset: { jobId: second.id } } });
    assert.ok(leases.some((x) => x.state === 'disconnected'));
    assert.equal(
      (await db.temporaryAsset.findUniqueOrThrow({ where: { jobId: second.id } })).state,
      'available',
    );
  });
  await check('No ads returns null; ad events deduplicate', async () => {
    assert.equal((await call(c, 'ads')).body, null);
    const campaign = await db.adCampaign.create({
      data: {
        title: 'Fixture ad',
        targetUrl: 'https://example.com',
        enabled: true,
        startsAt: new Date(Date.now() - 1000),
        endsAt: new Date(Date.now() + 60000),
      },
    });
    const event = { id: randomUUID(), campaignId: campaign.id, type: 'impression' };
    await call(c, 'ad-events', 'POST', event);
    await call(c, 'ad-events', 'POST', event);
    assert.equal(await db.adEvent.count({ where: { id: event.id } }), 1);
  });
  await check('Rate limit enforced per session', async () => {
    // Use a new session and retire each accepted job; 429 alone could be QUEUE_FULL.
    const d = await client();
    const ipKeys = await redis.keys('rate:analyze:ip:*');
    if (ipKeys.length) await redis.del(...ipKeys);
    let limited = false;
    for (let i = 0; i < 15; i++) {
      const r = await call(d, 'jobs/analyze', 'POST', { url: 'https://youtu.be/fixture0001' });
      if (r.status === 429) {
        assert.equal(r.body.error.code, 'RATE_LIMITED');
        limited = true;
        break;
      }
      assert.equal(r.status, 202);
      await call(d, `jobs/${r.body.jobId}/cancel`, 'POST');
    }
    assert.equal(limited, true);
  });
  console.log(
    JSON.stringify({ date: new Date().toISOString(), fixtureOnly: true, tests: outcomes }, null, 2),
  );
}
main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await queue.close();
    redis.disconnect();
    await db.$disconnect();
  });
