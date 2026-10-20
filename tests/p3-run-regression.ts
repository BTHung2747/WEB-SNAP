import { guard, close } from './p3-support';
async function main() {
  await guard();
  const target = process.argv[2], mode = process.argv[3];
  if (target === 'lifecycle') await import('./lifecycle.integration');
  else if (target === 'deadline') await import('./deadline.integration');
  else if (target === 'crash' && ['api-start', 'api-hold', 'api-check'].includes(mode)) {
    process.argv[2] = mode;
    await import('./crash.integration');
  } else throw new Error('Invalid guarded regression target');
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'P3_REGRESSION_GUARD_FAILED'); process.exitCode = 1; void close(); });
