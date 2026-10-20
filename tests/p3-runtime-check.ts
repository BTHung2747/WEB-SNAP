import assert from 'node:assert/strict';
import { db } from '../packages/shared/src/core';
import { close, guard, wait } from './p3-support';
async function main() {
  await guard();
  await wait('API healthy on isolated Docker network', async () => {
    try { return (await fetch('http://api:3000/api/v1/health')).ok; }
    catch { return false; }
  }, 15000);
  const idleVerified = process.argv.includes('--idle');
  if (idleVerified) {
    assert.equal(await db.downloadJob.count({ where: { state: { in: ['analyzing', 'queued', 'preparing'] } } }), 0, 'Refuse to recreate worker while test jobs are active');
    assert.equal(await db.transferLease.count({ where: { state: 'started' } }), 0, 'Refuse while another test transfer is active');
  }
  console.log(JSON.stringify({ date: new Date().toISOString(), result: 'PASS', project: 'wed-snap-p3-test', database: 'wed_snap_p3_test', redisDb: 14, origin: 'http://localhost:5174', node: process.version, apiHealthy: true, idleVerified }));
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'RUNTIME_GUARD_FAILED'); process.exitCode = 1; }).finally(close);
