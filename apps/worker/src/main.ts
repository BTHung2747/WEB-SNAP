import { Worker } from 'bullmq';
import { mkdir } from 'node:fs/promises';
import { db, limits, mediaRoot, redis } from '../../../packages/shared/src/core';
import { sweep } from './lifecycle';
import { processJob } from './processor';
async function main() {
  await mkdir(mediaRoot, { recursive: true });
  await sweep();
  const worker = new Worker('media', processJob, {
    connection: redis as any,
    concurrency: 1,
    maxStalledCount: 1,
  });
  let activeSweep: Promise<void> | undefined;
  let stopping = false;
  let shutdownPromise: Promise<void> | undefined;
  const every = (await limits()).sweepSeconds;
  const timer = setInterval(() => {
    if (stopping || activeSweep) return;
    activeSweep = sweep()
      .catch(() => console.error('{"event":"sweep_failed"}'))
      .finally(() => { activeSweep = undefined; });
  }, every * 1000);
  worker.on('error', () => console.error('{"event":"queue_error"}'));
  const shutdown = () => {
    if (shutdownPromise) return shutdownPromise;
    stopping = true;
    clearInterval(timer);
    shutdownPromise = (async () => {
      await activeSweep;
      await worker.close();
      await db.$disconnect();
      redis.disconnect();
      process.exit(0);
    })();
    return shutdownPromise;
  };
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, shutdown);
  console.log('{"event":"worker_ready","concurrency":1}');
}
main().catch(() => {
  console.error('WORKER_START_FAILED');
  process.exit(1);
});
