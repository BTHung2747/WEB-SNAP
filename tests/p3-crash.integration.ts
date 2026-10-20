import assert from 'node:assert/strict';
import { readFile, writeFile, readdir } from 'node:fs/promises';
import { db, filePath } from '../packages/shared/src/core';
import { guard, client, analyze, call, job, preparing, events, exists, wait, pause, noPublish, close } from './p3-support';

const record = '/control/crash-current.json';
async function main() {
  await guard();
  const mode = process.argv[2];
  if (mode === 'start') {
    const c = await client(), selected = await analyze(c, 'prepcrash01');
    await call(c, `jobs/${selected.id}/prepare`, selected.selection);
    const before = await preparing(selected.id);
    await call(c, `jobs/${selected.id}/heartbeat`);
    const j = await job(selected.id);
    assert.equal(j.state, 'preparing');
    assert.equal(j.asset?.state, 'staging');
    await writeFile(record, JSON.stringify({ id: j.id, client: c, marker: before.marker, token: j.workerToken }), { mode: 0o600 });
    console.log('PASS crash fixture analyzed normally, then preparing with live child, staging and partial');
    return;
  }
  const saved = JSON.parse(await readFile(record, 'utf8'));
  if (mode === 'pre-kill') {
    const { j } = await preparing(saved.id);
    await call(saved.client, `jobs/${saved.id}/heartbeat`);
    assert.equal(j.workerToken, saved.token);
    assert.equal((await events(saved.id)).filter(e => e.event === 'prepare_started').length, 1);
    console.log('PASS immediate pre-SIGKILL: state preparing, live matching PID, partial, fresh lease');
    return;
  }
  if (mode === 'killed') {
    const j = await job(saved.id);
    assert.equal(j.state, 'preparing'); assert.equal(j.workerToken, saved.token);
    assert.ok(j.processUntil && j.processUntil.getTime() > Date.now() + 1000, 'Observe a still-valid process lease before restart');
    assert.ok(j.ownerUntil.getTime() > j.processUntil.getTime(), 'Process lease must expire before owner TTL');
    assert.equal(await exists(filePath(`${saved.id}/media.mp4.part`)), true);
    saved.deadline = j.processUntil.getTime(); saved.killedAt = Date.now();
    saved.lastHeartbeat = await readFile(`/control/${saved.id}/heartbeat.json`, 'utf8');
    await pause(200);
    assert.equal(await readFile(`/control/${saved.id}/heartbeat.json`, 'utf8'), saved.lastHeartbeat, 'Killed child must stop updating the process marker');
    await writeFile(record, JSON.stringify(saved), { mode: 0o600 });
    console.log('PASS killed worker leaves staging/partial while process lease is still valid');
    return;
  }
  if (mode !== 'check') throw new Error('Invalid P3 crash mode');
  assert.ok(typeof saved.deadline === 'number');
  const started = Date.now();
  let cleanedAt = 0;
  await wait('crash process lease recovery', async () => {
    const j = await job(saved.id);
    await noPublish(saved.id);
    const partial = await exists(filePath(`${saved.id}/media.mp4.part`));
    if (Date.now() < saved.deadline) {
      assert.equal(partial, true, 'Do not remove staging before the persisted process lease expires');
      assert.equal(j.workerToken, saved.token);
    }
    if (j.workerToken === null && j.processUntil === null && ['failed', 'expired', 'cancelled'].includes(j.state) && j.asset?.state === 'deleted' && !await exists(filePath(saved.id))) {
      cleanedAt = Date.now();
      assert.ok(cleanedAt >= saved.deadline);
      assert.equal(j.errorCode, 'WORKER_INTERRUPTED');
      return true;
    }
    return false;
  }, 25000);
  assert.ok(cleanedAt <= saved.deadline + 8000, 'Crash cleanup bounded by lease deadline + 8s');
  console.log(JSON.stringify({ test: 'worker-SIGKILL-preparing-recovery', result: 'PASS', preState: 'preparing', cleanupAfterLeaseMs: cleanedAt - saved.deadline, recoveryMs: Date.now() - started }));
  // Default BullMQ lock/stalled scans are 30s. Observe two scans rather than assuming no retry.
  const settleUntil = saved.killedAt + 70000;
  while (Date.now() < settleUntil) {
    await noPublish(saved.id);
    assert.equal((await events(saved.id)).filter(e => e.event === 'prepare_started').length, 1);
    assert.equal(await exists(filePath(saved.id)), false);
    assert.equal(await readFile(`/control/${saved.id}/heartbeat.json`, 'utf8'), saved.lastHeartbeat, 'No surviving or duplicate child updates');
    await pause(250);
  }
  assert.equal(await db.temporaryAsset.count({ where: { jobId: saved.id } }), 1);
  const entries = await readdir('/media');
  assert.equal(entries.includes(saved.id), false, 'No managed orphan directory remains');
  console.log(JSON.stringify({ test: 'worker-SIGKILL-preparing-no-duplicate', result: 'PASS', observedAfterKillMs: Date.now() - saved.killedAt, prepareInvocations: 1, publishReady: false, partialOrphan: false, date: new Date().toISOString() }));
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'P3_CRASH_FAILED'); process.exitCode = 1; }).finally(close);
