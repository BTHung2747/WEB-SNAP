import { Worker } from 'bullmq';
import { mkdir } from 'node:fs/promises';
import { db, limits, mediaRoot, redis } from '../../../packages/shared/src/core';
import { sweep } from './lifecycle';
import { processJob } from './processor';
async function main() {
  const configuredConcurrency = process.env.WORKER_CONCURRENCY;
  if (configuredConcurrency !== undefined && configuredConcurrency !== '1' && configuredConcurrency !== '2') {
    throw new Error('INVALID_WORKER_CONCURRENCY');
  }
  const options = {
    connection: redis as any,
    concurrency: 1,
    maxStalledCount: 1,
  };
  if (configuredConcurrency === '2') options.concurrency = 2;
  await mkdir(mediaRoot, { recursive: true });
  await sweep();
  const worker = new Worker('media', processJob, options);
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
  console.log(JSON.stringify({ event: 'worker_ready', concurrency: worker.concurrency }));
}
main().catch(() => {
  console.error('WORKER_START_FAILED');
  process.exit(1);
});
