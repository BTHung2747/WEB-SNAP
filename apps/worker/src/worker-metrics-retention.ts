import { after, db } from '../../../packages/shared/src/core';

/** One batch per sweep. This policy applies only to worker metrics, never admin audits. */
export async function purgeWorkerMetrics(now = new Date()) {
  const cutoff = after(-30 * 86400, now);
  const expired = await db.auditLog.findMany({
    where: { actor: 'worker', action: 'worker.metrics', createdAt: { lt: cutoff } },
    select: { id: true },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    take: 500,
  });
  if (!expired.length) return { count: 0 };
  // Rows may change after selection. Recheck the exact scope and the same cutoff.
  return db.auditLog.deleteMany({
    where: {
      id: { in: expired.map((row) => row.id) },
      actor: 'worker',
      action: 'worker.metrics',
      createdAt: { lt: cutoff },
    },
  });
}
