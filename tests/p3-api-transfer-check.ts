import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { db, filePath } from '../packages/shared/src/core';
import { guard, close } from './p3-support';
async function main() {
  await guard();
  const record = JSON.parse(await readFile(filePath('crash-test-state.json'), 'utf8'));
  const job = await db.downloadJob.findUniqueOrThrow({ where: { id: record.id }, include: { asset: true } });
  assert.equal(job.state, 'ready'); assert.equal(job.asset?.state, 'available');
  const leases = await db.transferLease.findMany({ where: { assetId: job.asset!.id, state: 'started', expiresAt: { gt: new Date() } } });
  assert.equal(leases.length, 1);
  assert.ok(leases[0].reserved > 1000000n);
  console.log('PASS immediate API pre-SIGKILL: ready asset and active server transfer lease');
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'P3_TRANSFER_GUARD_FAILED'); process.exitCode = 1; }).finally(close);
