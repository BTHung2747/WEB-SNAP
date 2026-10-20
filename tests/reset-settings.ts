import { db, redis, queue, defaults } from '../packages/shared/src/core';
async function main() {
  if (process.env.APP_ORIGIN !== 'http://localhost:5174') throw new Error('Only test environment');
  await db.settings.upsert({
    where: { id: 'main' },
    create: { value: defaults },
    update: { value: defaults },
  });
  console.log('Test settings reset to runtime defaults');
}
main()
  .catch(() => {
    process.exitCode = 1;
  })
  .finally(async () => {
    await queue.close();
    redis.disconnect();
    await db.$disconnect();
  });
