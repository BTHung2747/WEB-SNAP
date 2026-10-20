import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdir, writeFile } from 'node:fs/promises';
import {
  db,
  redis,
  queue,
  defaults,
  after,
  hash,
  secret,
  passwordHash,
  filePath,
} from '../packages/shared/src/core';

const origin = 'http://localhost:5174';
const direct = process.argv.includes('--direct');
const reproduce = process.argv.includes('--reproduce');
const base = direct ? 'http://api:3000/api/v1/' : 'http://127.0.0.1:5173/api/v1/';
const outcomes: string[] = [];
type Client = { address: string; cookie: string; csrf: string };
async function request(
  address: string,
  path: string,
  method = 'GET',
  body?: unknown,
  headers: Record<string, string> = {},
) {
  return new Promise<{
    status: number;
    headers: http.IncomingHttpHeaders;
    bytes: Buffer;
    body: any;
  }>((resolve, reject) => {
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const req = http.request(
      base + path,
      {
        method,
        ...(direct ? {} : { localAddress: address }),
        headers: {
          origin,
          'content-type': 'application/json',
          ...(payload ? { 'content-length': String(Buffer.byteLength(payload)) } : {}),
          ...headers,
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const bytes = Buffer.concat(chunks);
          let data: any;
          if (res.headers['content-type']?.includes('application/json'))
            data = JSON.parse(bytes.toString());
          resolve({ status: res.statusCode!, headers: res.headers, bytes, body: data });
        });
        res.on('error', reject);
      },
    );
    req.on('error', reject);
    req.setTimeout(10000, () => req.destroy(new Error('Local request timeout')));
    req.end(payload);
  });
}
async function client(address: string): Promise<Client> {
  const r = await request(address, 'session');
  assert.equal(r.status, 200);
  return { address, cookie: r.headers['set-cookie']![0].split(';')[0], csrf: r.body.csrf };
}
function call(c: Client, path: string, body?: unknown, extra: Record<string, string> = {}) {
  return request(c.address, path, 'POST', body, {
    cookie: c.cookie,
    'x-csrf-token': c.csrf,
    ...extra,
  });
}
function limited(r: Awaited<ReturnType<typeof request>>) {
  assert.equal(r.status, 429);
  assert.equal(r.body.error.code, 'RATE_LIMITED');
}
async function clearRates() {
  // The DB-name + origin guards below run before this; Redis DB 15 is test-only.
  assert.equal(redis.options.db, 15);
  const keys = await redis.keys('rate:*');
  if (keys.length) await redis.del(...keys);
}
async function check(name: string, work: () => Promise<void>) {
  await clearRates();
  await work();
  outcomes.push(name);
  console.log('PASS ' + name);
}
async function analyze(c: Client, extra: Record<string, string> = {}) {
  const r = await call(c, 'jobs/analyze', { url: 'https://youtu.be/fixture0001' }, extra);
  if (r.status === 202) {
    // No worker runs in this rate-only stack; retire our own row to isolate admission.
    await db.downloadJob.update({
      where: { id: r.body.jobId },
      data: { state: 'cancelled', sourceUrl: null },
    });
  }
  return r;
}
async function ready(c: Client) {
  const sessionId = hash(c.cookie.split('=')[1]);
  const j = await db.downloadJob.create({
    data: { sessionId, platform: 'youtube', state: 'ready', ownerUntil: after(600) },
  });
  await mkdir(filePath(j.id), { recursive: true });
  const bytes = Buffer.from(Array.from({ length: 1024 }, (_, i) => i % 256));
  await writeFile(filePath(`${j.id}/media.mp4`), bytes);
  await db.temporaryAsset.create({
    data: {
      jobId: j.id,
      state: 'available',
      path: `${j.id}/media.mp4`,
      size: BigInt(bytes.length),
      readyUntil: after(600),
    },
  });
  return j.id;
}
async function main() {
  assert.equal(process.env.APP_ORIGIN, origin);
  const [database] = await db.$queryRaw<{ name: string }[]>`SELECT current_database() AS name`;
  assert.equal(database.name, 'wed_snap_rate_test', 'Dedicated rate-test DB required');
  assert.equal(redis.options.db, 15, 'Dedicated rate-test Redis DB required');
  let healthy = false;
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      healthy = (await request('127.0.0.2', 'health')).status === 200;
    } catch {}
    if (healthy) break;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  assert.ok(healthy, 'API and proxy must be ready before testing limits');
  await db.settings.upsert({
    where: { id: 'main' },
    create: { value: { ...defaults, enabledPlatforms: ['youtube'] } },
    update: { value: { ...defaults, enabledPlatforms: ['youtube'] } },
  });
  const email = `rate-${secret().slice(0, 8)}@example.com`,
    password = secret();
  const admin = await db.adminUser.create({
    data: { email, passwordHash: passwordHash(password) },
  });
  const credentials = { email, password: 'wrong-password-123' };
  try {
    if (reproduce) {
      await check(
        'BASELINE: two socket IPs collapse into one login IP bucket via Vite',
        async () => {
          const a = await client('127.0.0.2'),
            b = await client('127.0.0.3');
          for (let i = 0; i < 5; i++)
            assert.equal((await call(a, 'admin/login', credentials)).status, 403);
          limited(await call(b, 'admin/login', credentials));
        },
      );
      await check('BASELINE: session flood inserts beyond proposed 10/minute', async () => {
        const before = await db.session.count();
        for (let i = 0; i < 11; i++)
          assert.equal((await request('127.0.0.4', 'session')).status, 200);
        assert.equal(await db.session.count(), before + 11);
      });
      await check('BASELINE: ticket flood inserts beyond proposed 5/job/minute', async () => {
        const c = await client('127.0.0.5'),
          id = await ready(c);
        for (let i = 0; i < 6; i++)
          assert.equal((await call(c, `jobs/${id}/download-ticket`)).status, 201);
        assert.equal(await db.downloadTicket.count({ where: { jobId: id } }), 6);
      });
      return;
    }
    if (direct) {
      await check(
        'Untrusted direct API peer cannot rotate spoofed IPs to bypass session cap',
        async () => {
          const before = await db.session.count();
          for (let i = 0; i < 10; i++)
            assert.equal(
              (
                await request('', 'session', 'GET', undefined, {
                  'x-forwarded-for': `198.51.100.${i + 1}`,
                })
              ).status,
              200,
            );
          limited(
            await request('', 'session', 'GET', undefined, {
              'x-forwarded-for': '203.0.113.1',
              forwarded: 'for=203.0.113.1',
            }),
          );
          assert.equal(await db.session.count(), before + 10);
        },
      );
      await check(
        'Untrusted direct API peer cannot rotate spoofed IPs to bypass login cap',
        async () => {
          const c = await client('');
          for (let i = 0; i < 5; i++)
            assert.equal(
              (
                await call(c, 'admin/login', credentials, {
                  'x-forwarded-for': `198.51.100.${i + 1}`,
                })
              ).status,
              403,
            );
          limited(await call(c, 'admin/login', credentials, { 'x-forwarded-for': '203.0.113.8' }));
        },
      );
      return;
    }
    await check(
      'Session insert: 10/minute/IP, spoof cannot bypass, existing cookie remains usable',
      async () => {
        const before = await db.session.count();
        let saved: Client | undefined;
        for (let i = 0; i < 10; i++) {
          const r = await request('127.0.0.10', 'session', 'GET', undefined, {
            'x-forwarded-for': `198.51.100.${i + 1}`,
            forwarded: 'for=203.0.113.1',
          });
          assert.equal(r.status, 200);
          saved = {
            address: '127.0.0.10',
            cookie: r.headers['set-cookie']![0].split(';')[0],
            csrf: r.body.csrf,
          };
        }
        for (let i = 0; i < 3; i++)
          limited(
            await request('127.0.0.10', 'session', 'GET', undefined, {
              'x-forwarded-for': `203.0.113.${i + 1}`,
            }),
          );
        assert.equal(await db.session.count(), before + 10);
        assert.equal(
          (await request(saved!.address, 'session', 'GET', undefined, { cookie: saved!.cookie }))
            .status,
          200,
        );
        assert.equal(await db.session.count(), before + 10);
        assert.equal((await request('127.0.0.11', 'session')).status, 200);
      },
    );
    await check('Concurrent session flood checks Redis before DB insert', async () => {
      const before = await db.session.count();
      const rs = await Promise.all(
        Array.from({ length: 15 }, () => request('127.0.0.12', 'session')),
      );
      assert.equal(rs.filter((r) => r.status === 200).length, 10);
      rs.filter((r) => r.status !== 200).forEach(limited);
      assert.equal(await db.session.count(), before + 10);
    });
    await check(
      'Analyze: exact 10/minute/session; 11th is RATE_LIMITED without inserting job',
      async () => {
        const c = await client('127.0.0.20');
        for (let i = 0; i < 10; i++) assert.equal((await analyze(c)).status, 202);
        const before = await db.downloadJob.count();
        limited(await analyze(c));
        assert.equal(await db.downloadJob.count(), before);
      },
    );
    await check(
      'Analyze: same socket IP across sessions shares 30/minute; another IP has its own bucket',
      async () => {
        const cs = [];
        for (let i = 0; i < 4; i++) cs.push(await client('127.0.0.21'));
        const b = await client('127.0.0.22');
        for (let i = 0; i < 30; i++)
          assert.equal((await analyze(cs[Math.floor(i / 10)])).status, 202);
        const before = await db.downloadJob.count();
        limited(await analyze(cs[3]));
        assert.equal(await db.downloadJob.count(), before);
        assert.equal((await analyze(b)).status, 202);
      },
    );
    await check(
      'Proxy overwrites spoofed forwarding headers; analyze IP cap cannot be bypassed',
      async () => {
        const cs = [];
        for (let i = 0; i < 4; i++) cs.push(await client('127.0.0.23'));
        for (let i = 0; i < 30; i++)
          assert.equal(
            (
              await analyze(cs[Math.floor(i / 10)], {
                'x-forwarded-for': `198.51.100.${i + 1}`,
                'x-real-ip': `203.0.113.${i + 1}`,
                forwarded: `for=198.51.100.${i + 1}`,
              })
            ).status,
            202,
          );
        limited(await analyze(cs[3], { 'x-forwarded-for': '203.0.113.1, 198.51.100.2' }));
      },
    );
    await check(
      'Login: 5/300s/IP across cookies; another IP succeeds; spoof cannot bypass',
      async () => {
        const a = await client('127.0.0.30'),
          same = await client('127.0.0.30'),
          b = await client('127.0.0.31');
        for (let i = 0; i < 5; i++)
          assert.equal(
            (
              await call(i % 2 ? same : a, 'admin/login', credentials, {
                'x-forwarded-for': `198.51.100.${i + 1}`,
              })
            ).status,
            403,
          );
        limited(
          await call(
            same,
            'admin/login',
            { email, password },
            { 'x-forwarded-for': '203.0.113.9' },
          ),
        );
        assert.equal((await call(b, 'admin/login', { email, password })).status, 201);
        const ttl = await redis.ttl(`rate:login:${hash('127.0.0.30')}`);
        assert.ok(ttl > 290 && ttl <= 300, 'Login window must remain 300 seconds');
      },
    );
    await check('QUEUE_FULL has its own code and does not insert a job', async () => {
      const c = await client('127.0.0.40');
      await db.settings.update({
        where: { id: 'main' },
        data: { value: { ...defaults, enabledPlatforms: ['youtube'], queueLimit: 1 } },
      });
      const pending = await db.downloadJob.create({
        data: {
          sessionId: hash(c.cookie.split('=')[1]),
          platform: 'youtube',
          ownerUntil: after(600),
        },
      });
      const before = await db.downloadJob.count();
      const r = await call(c, 'jobs/analyze', { url: 'https://youtu.be/fixture0001' });
      assert.equal(r.status, 429);
      assert.equal(r.body.error.code, 'QUEUE_FULL');
      assert.equal(await db.downloadJob.count(), before);
      await db.downloadJob.update({ where: { id: pending.id }, data: { state: 'cancelled' } });
      await db.settings.update({
        where: { id: 'main' },
        data: { value: { ...defaults, enabledPlatforms: ['youtube'] } },
      });
    });
    await check(
      'Tickets: 5/job/minute, reject before insert; same ticket keeps supporting Range',
      async () => {
        const c = await client('127.0.0.50'),
          id = await ready(c);
        let url = '';
        for (let i = 0; i < 5; i++) {
          const r = await call(c, `jobs/${id}/download-ticket`);
          assert.equal(r.status, 201);
          url = r.body.url.slice('/api/v1/'.length);
        }
        limited(await call(c, `jobs/${id}/download-ticket`));
        assert.equal(await db.downloadTicket.count({ where: { jobId: id } }), 5);
        for (const range of ['bytes=0-99', 'bytes=100-199', 'bytes=-100']) {
          const r = await request(c.address, url, 'GET', undefined, { cookie: c.cookie, range });
          assert.equal(r.status, 206);
          assert.equal(r.bytes.length, 100);
        }
      },
    );
    await check(
      'Tickets: 10/session/minute across jobs, concurrent job flood stays at five rows',
      async () => {
        const c = await client('127.0.0.51');
        const ids = [await ready(c), await ready(c), await ready(c)];
        for (const id of ids.slice(0, 2))
          for (let i = 0; i < 5; i++)
            assert.equal((await call(c, `jobs/${id}/download-ticket`)).status, 201);
        const before = await db.downloadTicket.count();
        limited(await call(c, `jobs/${ids[2]}/download-ticket`));
        assert.equal(await db.downloadTicket.count(), before);
        await clearRates();
        const rs = await Promise.all(
          Array.from({ length: 8 }, () => call(c, `jobs/${ids[2]}/download-ticket`)),
        );
        assert.equal(rs.filter((r) => r.status === 201).length, 5);
        rs.filter((r) => r.status !== 201).forEach(limited);
        assert.equal(await db.downloadTicket.count({ where: { jobId: ids[2] } }), 5);
      },
    );
  } finally {
    await db.adminUser.delete({ where: { id: admin.id } });
    await clearRates();
  }
}
main()
  .then(() =>
    console.log(
      JSON.stringify(
        {
          date: new Date().toISOString(),
          mode: reproduce ? 'baseline' : direct ? 'untrusted-direct' : 'proxy',
          fixtureOnly: true,
          groups: outcomes.length,
          tests: outcomes,
        },
        null,
        2,
      ),
    ),
  )
  .catch((e) => {
    console.error(
      e instanceof assert.AssertionError ? `${e.message} (assertion failed)` : 'RATE_TEST_FAILED',
    );
    process.exitCode = 1;
  })
  .finally(async () => {
    await queue.close();
    redis.disconnect();
    await db.$disconnect();
  });
