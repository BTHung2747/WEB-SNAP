import { fail } from '../../../../packages/shared/src/core';
export async function admission(tx: any, l: any) {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(8172401)`;
  if (!l.acceptJobs) fail('CAPACITY_UNAVAILABLE', 503);
  const pending = await tx.downloadJob.count({
    where: { state: { in: ['analyzing', 'queued', 'preparing'] } },
  });
  if (pending >= l.queueLimit) fail('QUEUE_FULL', 429);
}
