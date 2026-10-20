import { after, db } from '../../../packages/shared/src/core';

/** One bounded batch per sweep; raw events keep the existing strict 30-day TTL. */
export async function purgeAdEvents(now = new Date()) {
  const cutoff = after(-30 * 86400, now);
  const expired = await db.adEvent.findMany({
    where: { createdAt: { lt: cutoff } },
    select: { id: true },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    take: 500,
  });
  if (!expired.length) return { count: 0 };
  // A row changed between selection and deletion must still satisfy this cutoff.
  return db.adEvent.deleteMany({
    where: { id: { in: expired.map((event) => event.id) }, createdAt: { lt: cutoff } },
  });
}
