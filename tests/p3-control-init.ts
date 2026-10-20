import { chown, chmod, lstat } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { guard, close } from './p3-support';
async function main() {
  await guard();
  const info = await lstat('/control');
  assert.equal(info.isDirectory(), true); assert.equal(info.isSymbolicLink(), false);
  // CAP_CHOWN belongs only to this guarded initializer. Set mode while root
  // owns the directory, then hand ownership back to the unprivileged worker.
  await chown('/control', 0, 0);
  await chmod('/control', 0o700);
  await chown('/control', 1000, 1000);
  console.log('PASS guarded test control volume initialized for runtime user');
}
main().catch(e => { console.error('P3_CONTROL_GUARD_FAILED: ' + (e.code || e.constructor?.name || 'unknown')); process.exitCode = 1; }).finally(close);
