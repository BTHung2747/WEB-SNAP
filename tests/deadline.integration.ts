import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdir, writeFile } from 'node:fs/promises';
import {
  after,
  db,
  filePath,
  hash,
  lockAsset,
  queue,
  redis,
  secret,
} from '../packages/shared/src/core';
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
async function main() {
  assert.equal(process.env.APP_ORIGIN, 'http://localhost:5174');
  const token = secret(),
    ticket = secret();
  const session = await db.session.create({
    data: { id: hash(token), csrf: secret(), expiresAt: after(3600) },
  });
  const job = await db.downloadJob.create({
    data: { sessionId: session.id, platform: 'youtube', state: 'ready', ownerUntil: after(120) },
  });
  await mkdir(filePath(job.id), { recursive: true });
  // Backpressure bytes only, not platform evidence.
  await writeFile(filePath(`${job.id}/media.mp4`), Buffer.alloc(32 * 1024 * 1024));
  const asset = await db.temporaryAsset.create({
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
  let unlock!: () => void, locked!: () => void;
  const release = new Promise<void>((r) => {
    unlock = r;
  });
  const acquired = new Promise<void>((r) => {
    locked = r;
  });
  const transaction = db.$transaction(
    async (tx) => {
      await lockAsset(tx, asset.id);
      locked();
      await release;
      // Simulates another Range request setting the asset's shared absolute deadline.
      await tx.temporaryAsset.update({
        where: { id: asset.id },
        data: { transferDeadline: after(2) },
      });
    },
    { timeout: 10000 },
  );
  await acquired;
  let headersSeen = false,
    aborted = false;
  const stream = new Promise<void>((resolve, reject) => {
    const request = http.get(
      `http://api:3000/api/v1/downloads/${ticket}`,
      { headers: { cookie: `ws_session=${token}` } },
      (response) => {
        assert.equal(response.statusCode, 200);
        headersSeen = true;
        response.pause();
        // A paused reader cannot observe remote EOF until it drains its buffered socket data.
        const drain = setTimeout(() => response.resume(), 3500);
        response.on('aborted', () => {
          aborted = true;
        });
        response.on('error', () => {});
        response.on('close', resolve);
        const timer = setTimeout(() => {
          response.destroy();
          reject(new Error('Transfer did not terminate'));
        }, 7000);
        response.on('close', () => {
          clearTimeout(timer);
          clearTimeout(drain);
        });
      },
    );
    request.on('error', reject);
  });
  try {
    let blocked = false;
    for (let i = 0; i < 40; i++) {
      const rows = await db.$queryRaw<
        { count: bigint }[]
      >`SELECT count(*) FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE '%TemporaryAsset%'`;
      if (Number(rows[0].count) > 0) {
        blocked = true;
        break;
      }
      await pause(50);
    }
    assert.equal(blocked, true, 'HTTP must read old asset then block at atomic lease lock');
    unlock();
    await transaction;
    await stream;
    assert.equal(headersSeen, true);
    assert.equal(aborted, true);
    const lease = await db.transferLease.findFirstOrThrow({ where: { assetId: asset.id } });
    assert.equal(lease.state, 'timed_out');
    console.log(
      'PASS concurrent Range admission uses deadline read under asset lock; paused transfer stops at shared deadline',
    );
  } finally {
    unlock();
    await transaction;
  }
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
