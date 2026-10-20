import assert from 'node:assert/strict';
import { db, redis, queue, passwordHash, secret, defaults } from '../packages/shared/src/core';
async function main() {
  if (process.env.APP_ORIGIN !== 'http://localhost:5174') throw new Error('Test project only');
  const base = 'http://api:3000/api/v1/';
  const r = await fetch(base + 'session');
  const s = (await r.json()) as any;
  let cookie = r.headers.get('set-cookie')!.split(';')[0];
  const password = secret();
  const email = 'fixture-' + secret().slice(0, 8) + '@example.com';
  await db.adminUser.create({ data: { email, passwordHash: passwordHash(password) } });
  const call = async (url: string, method = 'GET', body?: any) =>
    fetch(base + url, {
      method,
      headers: {
        cookie,
        origin: 'http://localhost:5174',
        'x-csrf-token': s.csrf,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  assert.equal((await call('admin/dashboard')).status, 403);
  const login = await call('admin/login', 'POST', { email, password });
  assert.equal(login.status, 201);
  cookie += '; ' + login.headers.get('set-cookie')!.split(';')[0];
  assert.equal((await call('admin/dashboard')).status, 200);
  const settings = (await (await call('admin/settings')).json()) as any;
  assert.equal(
    (await call('admin/settings', 'PUT', { ...settings, enabledPlatforms: ['tiktok'] })).status,
    400,
  );
  assert.equal(
    (await call('admin/settings', 'PUT', { ...settings, acceptJobs: false })).status,
    200,
  );
  assert.equal(
    (await call('jobs/analyze', 'POST', { url: 'https://youtu.be/fixture0001' })).status,
    503,
  );
  await call('admin/settings', 'PUT', settings);
  const campaign = {
    title: 'Fixture admin',
    imageUrl: null,
    targetUrl: 'https://example.com',
    linkType: 'sponsored',
    placement: 'banner',
    enabled: true,
    startsAt: new Date(Date.now() - 1000).toISOString(),
    endsAt: new Date(Date.now() + 60000).toISOString(),
    weight: 1,
  };
  assert.equal(
    (await call('admin/campaigns', 'POST', { ...campaign, targetUrl: 'javascript:alert(1)' }))
      .status,
    400,
  );
  const created = await call('admin/campaigns', 'POST', campaign);
  assert.equal(created.status, 201);
  const c = (await created.json()) as any;
  assert.equal(
    (await call('admin/campaigns/' + c.id, 'PUT', { ...campaign, title: 'Fixture updated' }))
      .status,
    200,
  );
  assert.ok((await db.auditLog.count({ where: { actor: email } })) >= 3);
  assert.equal((await call('admin/campaigns/' + c.id, 'DELETE')).status, 200);
  assert.equal((await call('admin/logout', 'POST')).status, 201);
  assert.equal((await call('admin/dashboard')).status, 403);
  await db.adminUser.delete({ where: { email } });
  console.log('PASS admin auth, CSRF session, CRUD, audit, limits, verification gate and logout');
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
