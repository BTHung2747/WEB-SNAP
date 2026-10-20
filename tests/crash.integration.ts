import assert from 'node:assert/strict';
import http from 'node:http';
import { readFile, writeFile, mkdir, access, unlink } from 'node:fs/promises';
import {
  db,
  queue,
  redis,
  hash,
  secret,
  after,
  filePath,
  enqueue,
  defaults,
} from '../packages/shared/src/core';

const record = filePath('crash-test-state.json');
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
async function exists(path: string) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}
async function wait(check: () => Promise<boolean>, seconds: number) {
  const end = Date.now() + seconds * 1000;
  while (Date.now() < end) {
    if (await check()) return;
    await pause(500);
  }
  throw new Error('Crash recovery deadline');
}
async function main() {
  assert.equal(process.env.APP_ORIGIN, 'http://localhost:5174', 'Disposable test stack only');
  const mode = process.argv[2];
  if (mode.endsWith('-start')) {
    const token = secret();
    const session = await db.session.create({
      data: { id: hash(token), csrf: secret(), expiresAt: after(3600) },
    });
    const job = await db.downloadJob.create({
      data: {
        sessionId: session.id,
        platform: 'youtube',
        ownerUntil: after(120),
        state: mode === 'worker-start' ? 'analyzing' : 'ready',
        sourceUrl: mode === 'worker-start' ? 'https://www.youtube.com/watch?v=delay000001' : null,
      },
    });
    const ticket = secret();
    await writeFile(record, JSON.stringify({ id: job.id, token, ticket }));
    if (mode === 'worker-start') {
      await enqueue(job.id, 'analyze');
      await wait(
        async () =>
          !!(await db.downloadJob.findUniqueOrThrow({ where: { id: job.id } })).workerToken &&
          (await exists(filePath(`${job.id}/media.mp4.part`))),
        10,
      );
      assert.equal((await db.downloadJob.findUniqueOrThrow({ where: { id: job.id } })).state, 'analyzing');
      console.log('WORKER_ANALYZE_CHILD_RUNNING');
    } else {
      // Socket backpressure fixture; these bytes are not media/platform evidence.
      await mkdir(filePath(job.id), { recursive: true });
      await writeFile(filePath(`${job.id}/media.mp4`), Buffer.alloc(32 * 1024 * 1024));
      await db.temporaryAsset.create({
        data: {
          jobId: job.id,
          path: `${job.id}/media.mp4`,
          size: 33554432n,
          state: 'available',
          readyUntil: after(120),
        },
      });
      await db.downloadTicket.create({
        data: { id: hash(ticket), jobId: job.id, expiresAt: after(120) },
      });
      await db.settings.upsert({
        where: { id: 'main' },
        create: { value: { ...defaults, leaseTtl: 30 } },
        update: { value: { ...defaults, leaseTtl: 30 } },
      });
      console.log('API_CRASH_FIXTURE_READY');
    }
    return;
  }
  const state = JSON.parse(await readFile(record, 'utf8'));
  if (mode === 'api-hold') {
    await new Promise<void>((resolve, reject) => {
      const req = http.get(
        `http://api:3000/api/v1/downloads/${state.ticket}`,
        { headers: { cookie: `ws_session=${state.token}` } },
        (res) => {
          assert.equal(res.statusCode, 200);
          res.pause();
          console.log('TRANSFER_HELD');
          const timer = setTimeout(() => {
            res.destroy();
            reject(new Error('API was not killed'));
          }, 45000);
          res.on('close', () => {
            clearTimeout(timer);
            resolve();
          });
          res.on('error', () => {});
        },
      );
      req.on('error', reject);
    });
    return;
  }
  if (mode === 'worker-check') {
    await wait(async () => {
      const job = await db.downloadJob.findUniqueOrThrow({ where: { id: state.id } });
      return (
        job.workerToken === null &&
        ['failed', 'expired', 'cancelled'].includes(job.state) &&
        !(await exists(filePath(state.id)))
      );
    }, 30);
    console.log('PASS actual worker SIGKILL during analyzing: expired process lease recovered and partial removed');
  } else if (mode === 'api-check') {
    await wait(
      async () =>
        (await db.temporaryAsset.findUniqueOrThrow({ where: { jobId: state.id } })).state ===
        'deleted',
      45,
    );
    const lease = await db.transferLease.findFirstOrThrow({
      where: { asset: { jobId: state.id } },
    });
    assert.equal(lease.state, 'timed_out');
    assert.equal(await exists(filePath(state.id)), false);
    const response = await fetch(`http://api:3000/api/v1/downloads/${state.ticket}`, {
      headers: { cookie: `ws_session=${state.token}` },
    });
    assert.equal(response.status, 410);
    console.log(
      'PASS actual API SIGKILL during transfer: lease expiry, grace, cleanup, ticket 410',
    );
    await db.settings.update({ where: { id: 'main' }, data: { value: defaults } });
  } else throw new Error('Unknown crash mode');
  await unlink(record);
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
