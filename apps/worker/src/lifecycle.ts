import { readdir, rm, stat, statfs } from 'node:fs/promises';
import { liveProcesses } from './process-registry';
import { purgeAdEvents } from './ad-event-retention';
import { purgeWorkerMetrics } from './worker-metrics-retention';
import {
  after,
  assetExpired,
  db,
  enqueue,
  expireSelectableMetadata,
  filePath,
  limits,
  lockAsset,
  lockJob,
  mediaRoot,
  ownerExpired,
} from '../../../packages/shared/src/core';
export async function diskAvailable(stopPercent: number) {
  const s = await statfs(mediaRoot);
  return (1 - Number(s.bavail) / Number(s.blocks)) * 100 < stopPercent;
}
export async function sweep() {
  const l = await limits();
  const now = new Date();
  // Crash lease expiry conservatively charges the full reservation, never understates the budget.
  const stale = await db.transferLease.findMany({
    where: { state: 'started', expiresAt: { lte: now } },
    take: 100,
  });
  for (const lease of stale)
    await db.$transaction(async (tx) => {
      await lockAsset(tx, lease.assetId);
      const current = await tx.transferLease.findUnique({ where: { id: lease.id } });
      if (!current || current.state !== 'started' || current.expiresAt > new Date()) return;
      await tx.transferLease.update({
        where: { id: lease.id },
        data: { state: 'timed_out', endedAt: now },
      });
      if (
        !(await tx.transferLease.count({
          where: { assetId: lease.assetId, state: 'started', expiresAt: { gt: now } },
        }))
      )
        await tx.temporaryAsset.update({
          where: { id: lease.assetId },
          data: { retryUntil: after(l.retryGrace, now) },
        });
    });
  const jobs = await db.downloadJob.findMany({
    where: {
      OR: [
        { workerToken: { not: null } },
        { state: { in: ['analyzing', 'selectable', 'queued', 'preparing', 'ready'] } },
        { asset: { is: { state: { in: ['staging', 'available', 'deleting'] } } } },
        { cleanupCompletedAt: null, state: { in: ['failed', 'cancelled', 'expired'] } },
      ],
    },
    include: { asset: true },
    take: 500,
    orderBy: { updatedAt: 'asc' },
  });
  for (const job of jobs) {
    const clean = await db.$transaction(async (tx) => {
      await lockJob(tx, job.id);
      let j = await tx.downloadJob.findUniqueOrThrow({
        where: { id: job.id },
        include: { asset: true },
      });
      if (await expireSelectableMetadata(tx, j, now))
        j = await tx.downloadJob.findUniqueOrThrow({ where: { id: j.id }, include: { asset: true } });
      const ownerDead = ownerExpired(j, now) || j.cancelRequested;
      const workerAlive =
        liveProcesses.has(j.workerToken || '') ||
        !!(j.workerToken && j.processUntil && j.processUntil > now);
      if (j.workerToken && !workerAlive) {
        await tx.downloadJob.update({
          where: { id: j.id },
          data: {
            workerToken: null,
            processUntil: null,
            state: j.cancelRequested ? 'cancelled' : 'failed',
            errorCode: 'WORKER_INTERRUPTED',
            sourceUrl: null,
          },
        });
      }
      // A started transfer detaches file lifetime from page lifetime, including Range grace.
      if (ownerDead && !j.cancelRequested && !j.asset?.transferDeadline)
        await tx.downloadJob.update({
          where: { id: j.id },
          data: {
            cancelRequested: true,
            state: j.state === 'ready' ? 'ready' : 'expired',
            sourceUrl: null,
          },
        });
      if (workerAlive) return false; // Worker terminates and awaits subprocess exit before cleanup.
      if (j.asset) {
        await lockAsset(tx, j.asset.id);
        const a = await tx.temporaryAsset.findUniqueOrThrow({ where: { id: j.asset.id } });
        const live = await tx.transferLease.count({
          where: { assetId: a.id, state: 'started', expiresAt: { gt: now } },
        });
        if (live) return false;
        if (a.state === 'deleted') return ownerDead || ['cancelled', 'failed'].includes(j.state);
        if (
          a.state === 'deleting' ||
          (a.state === 'staging' && (ownerDead || j.state === 'failed' || !workerAlive)) ||
          (a.state === 'available' && (j.cancelRequested || assetExpired(a, ownerDead, now)))
        ) {
          await tx.temporaryAsset.update({ where: { id: a.id }, data: { state: 'deleting' } });
          await tx.downloadJob.update({
            where: { id: j.id },
            data: {
              state:
                j.state === 'failed' ? 'failed' : j.state === 'cancelled' ? 'cancelled' : 'expired',
              sourceUrl: null,
              workerToken: null,
            },
          });
          return true;
        }
      } else if (ownerDead || ['failed', 'cancelled', 'expired'].includes(j.state)) return true;
      return false;
    });
    if (clean) {
      try {
        // The first transaction fences admissions by committing terminal/deleting.
        // Recheck under the same job -> asset lock order before touching files.
        await db.$transaction(async (tx) => {
          await lockJob(tx, job.id);
          const j = await tx.downloadJob.findUnique({
            where: { id: job.id }, include: { asset: true },
          });
          const cleanupNow = new Date();
          if (!j || j.cleanupCompletedAt || !['failed', 'cancelled', 'expired'].includes(j.state))
            return;
          if (j.workerToken || liveProcesses.has(j.workerToken || '')) return;
          if (j.asset) {
            await lockAsset(tx, j.asset.id);
            const a = await tx.temporaryAsset.findUniqueOrThrow({ where: { id: j.asset.id } });
            if (!['deleting', 'deleted'].includes(a.state)) return;
            if (await tx.transferLease.count({
              where: { assetId: a.id, state: 'started', expiresAt: { gt: cleanupNow } },
            })) return;
          }
          await rm(filePath(j.id), { recursive: true, force: true });
          await tx.mediaItem.deleteMany({ where: { jobId: j.id } });
          await tx.temporaryAsset.updateMany({
            where: { jobId: j.id, state: 'deleting' }, data: { state: 'deleted' },
          });
          await tx.downloadJob.update({
            where: { id: j.id },
            data: { cancelRequested: true, processUntil: null, cleanupCompletedAt: new Date() },
          });
        });
      } catch (error) {
        // Failed rm/commit leaves completion null and the row eligible next sweep.
        // One failing directory must not block cleanup or the outbox for other jobs.
        console.warn(JSON.stringify({ event: 'cleanup_failed', jobId: job.id,
          code: (error as NodeJS.ErrnoException).code || 'CLEANUP_FAILED' }));
      }
    }
  }
  // Outbox recovery: jobs committed before Redis enqueue crashed are still processed.
  const pending = await db.downloadJob.findMany({
    where: {
      state: { in: ['analyzing', 'queued'] },
      workerToken: null,
      cancelRequested: false,
      ownerUntil: { gt: now },
    },
    take: 20,
  });
  for (const j of pending) await enqueue(j.id, j.state === 'analyzing' ? 'analyze' : 'prepare');
  // Orphan directories only UUIDs; never follow symlinks or delete outside mediaRoot.
  for (const entry of await readdir(mediaRoot, { withFileTypes: true })) {
    if (!entry.isDirectory() || !/^[-a-f0-9]{36}$/.test(entry.name)) continue;
    const p = filePath(entry.name);
    const st = await stat(p);
    if (st.mtimeMs > Date.now() - 3600000) continue;
    if (!(await db.downloadJob.findUnique({ where: { id: entry.name } })))
      await rm(p, { recursive: true, force: true });
  }
  await purgeAdEvents();
  await purgeWorkerMetrics(now);
  await db.downloadTicket.deleteMany({ where: { expiresAt: { lt: now } } });
  // Purge metadata after 24h. FK keeps sessions with remaining jobs.
  const old = await db.downloadJob.findMany({
    where: {
      state: { in: ['expired', 'cancelled', 'failed'] },
      workerToken: null,
      cleanupCompletedAt: { not: null },
      updatedAt: { lt: after(-86400) },
      OR: [{ asset: { is: null } }, { asset: { state: 'deleted' } }],
    },
    select: { id: true },
    take: 100,
  });
  await db.downloadJob.deleteMany({ where: { id: { in: old.map((j) => j.id) } } });
  await db.session.deleteMany({ where: { expiresAt: { lt: now }, jobs: { none: {} } } });
}
