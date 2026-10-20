import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdir, writeFile, access } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { db, redis, queue, hash, secret, after, filePath } from '../packages/shared/src/core';
import { sweep } from '../apps/worker/src/lifecycle';
import { liveProcesses } from '../apps/worker/src/process-registry';
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
async function exists(p: string) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}
async function seed(state = 'ready') {
  const token = secret();
  const session = await db.session.create({
    data: { id: hash(token), csrf: secret(), expiresAt: after(3600) },
  });
  const job = await db.downloadJob.create({
    data: { sessionId: session.id, platform: 'youtube', state, ownerUntil: after(120) },
  });
  await mkdir(filePath(job.id), { recursive: true });
  const data = Buffer.alloc(8192, 7); // stream/lease fixture only; not platform/video evidence
  await writeFile(filePath(`${job.id}/media.mp4`), data);
  const asset = await db.temporaryAsset.create({
    data: {
      jobId: job.id,
      path: `${job.id}/media.mp4`,
      state: state === 'ready' ? 'available' : 'staging',
      size: BigInt(data.length),
      readyUntil: after(60),
    },
  });
  return { token, session, job, asset };
}
async function main() {
  if (process.env.APP_ORIGIN !== 'http://localhost:5174')
    throw new Error('Isolated test project only');
  const crashed = await seed('preparing');
  await db.downloadJob.update({
    where: { id: crashed.job.id },
    data: { workerToken: secret(), processUntil: after(-10) },
  });
  await writeFile(filePath(`${crashed.job.id}/media.mp4.part`), 'partial');
  await sweep();
  const recovered = await db.downloadJob.findUniqueOrThrow({ where: { id: crashed.job.id } });
  assert.equal(recovered.workerToken, null);
  assert.equal(recovered.errorCode, 'WORKER_INTERRUPTED');
  assert.equal(await exists(filePath(`${crashed.job.id}/media.mp4.part`)), false);
  console.log('PASS crashed worker record recovery removes staging/partial');

  const active = await seed('preparing');
  const workerToken = secret();
  await db.downloadJob.update({
    where: { id: active.job.id },
    data: { workerToken, processUntil: after(-10), ownerUntil: after(-5) },
  });
  const child = spawn(process.execPath, ['-e', 'setInterval(()=>{},1000)'], { stdio: 'ignore' });
  liveProcesses.add(workerToken);
  const closed = new Promise<void>((r) =>
    child.once('close', () => {
      liveProcesses.delete(workerToken);
      r();
    }),
  );
  try {
    await sweep();
    assert.equal(await exists(filePath(`${active.job.id}/media.mp4`)), true);
    child.kill('SIGTERM');
    await closed;
    await sweep();
    assert.equal(await exists(filePath(`${active.job.id}/media.mp4`)), false);
  } finally {
    child.kill('SIGKILL');
    liveProcesses.delete(workerToken);
  }
  console.log('PASS cleanup defers while real local child exists, then cleans after exit');

  const transfer = await seed();
  const month = new Date().toISOString().slice(0, 7);
  await db.temporaryAsset.update({
    where: { id: transfer.asset.id },
    data: { transferDeadline: after(1800) },
  });
  await db.egressBudget.upsert({ where: { month }, create: { month }, update: {} });
  const lease = await db.transferLease.create({
    data: { assetId: transfer.asset.id, expiresAt: after(-1), reserved: 8192n, month },
  });
  await sweep();
  assert.equal(
    (await db.transferLease.findUniqueOrThrow({ where: { id: lease.id } })).state,
    'timed_out',
  );
  assert.equal(
    (await db.temporaryAsset.findUniqueOrThrow({ where: { id: transfer.asset.id } })).state,
    'available',
  );
  await pause(4000);
  await sweep();
  assert.equal(
    (await db.temporaryAsset.findUniqueOrThrow({ where: { id: transfer.asset.id } })).state,
    'deleted',
  );
  console.log('PASS expired crash lease gives retry grace and then safe cleanup');

  for (let i = 0; i < 8; i++) {
    const race = await seed();
    const ticket = secret();
    await db.downloadTicket.create({
      data: { id: hash(ticket), jobId: race.job.id, expiresAt: after(60) },
    });
    await db.temporaryAsset.update({
      where: { id: race.asset.id },
      data: { readyUntil: new Date(Date.now() + 15) },
    });
    const [response] = await Promise.all([
      fetch(`http://api:3000/api/v1/downloads/${ticket}`, {
        headers: { cookie: `ws_session=${race.token}`, Range: 'bytes=0-99' },
      }),
      sweep(),
    ]);
    assert.ok([206, 410].includes(response.status), `race returned ${response.status}`);
    if (response.status === 206) assert.equal((await response.arrayBuffer()).byteLength, 100);
    else await response.arrayBuffer();
  }
  console.log('PASS 8 download/cleanup races: granted valid lease or explicit 410, no partial/500');
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
