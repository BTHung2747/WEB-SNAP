import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { writeFile, statfs } from 'node:fs/promises';
import { JobsService } from '../apps/api/src/services/jobs.service';
import { diskAvailable } from '../apps/worker/src/lifecycle';
import { db, queue, redis, hash, secret, after, AppError } from '../packages/shared/src/core';
async function main() {
  assert.equal(process.env.APP_ORIGIN, 'http://localhost:5174');
  const disk = await statfs('/media');
  assert.ok(
    Number(disk.blocks) * Number(disk.bsize) <= 8388608,
    'Must use capacity tmpfs override, never host media disk',
  );
  assert.equal(await diskAvailable(80), true);
  await writeFile('/media/capacity-fixture', Buffer.alloc(7 * 1024 * 1024));
  assert.equal(await diskAvailable(80), false);
  const token = secret();
  const csrf = secret();
  const session = await db.session.create({
    data: { id: hash(token), csrf, expiresAt: after(3600) },
  });
  const job = await db.downloadJob.create({
    data: {
      sessionId: session.id,
      platform: 'youtube',
      state: 'selectable',
      ownerUntil: after(120),
    },
  });
  const item = await db.mediaItem.create({
    data: { jobId: job.id, kind: 'video', formats: [{ id: '18' }] },
  });
  const req: any = {
    cookies: { ws_session: token },
    get: (name: string) =>
      name.toLowerCase() === 'origin'
        ? 'http://localhost:5174'
        : name.toLowerCase() === 'x-csrf-token'
          ? csrf
          : undefined,
  };
  await assert.rejects(
    () =>
      new JobsService().prepare(
        req,
        job.id,
        { itemId: item.id, formatId: '18', idempotencyKey: randomUUID() },
        {} as any,
      ),
    (e: any) => e instanceof AppError && e.code === 'CAPACITY_UNAVAILABLE' && e.status === 503,
  );
  assert.equal(
    (await db.downloadJob.findUniqueOrThrow({ where: { id: job.id } })).state,
    'selectable',
  );
  assert.equal(await db.temporaryAsset.count({ where: { jobId: job.id } }), 0);
  await db.downloadJob.update({
    where: { id: job.id },
    data: { state: 'cancelled', cancelRequested: true },
  });
  console.log(
    'PASS actual 8 MiB tmpfs above 80%: API rejects prepare with 503, worker disk gate closed; host disk untouched',
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
