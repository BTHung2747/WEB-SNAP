import assert from 'node:assert/strict';
import { watch } from 'node:fs';
import { filePath, queue } from '../packages/shared/src/core';
import { guard, client, analyze, call, job, preparing, events, exists, live, wait, pause, allowExit, noPublish, close } from './p3-support';

async function main() {
  await guard();
  const a = await client(), b = await client();
  // Both analyses must finish before the only worker slot is occupied by A's prepare.
  const blocker = await analyze(a, 'prepwait001'), queued = await analyze(b, 'prepqueue01');
  await call(a, `jobs/${blocker.id}/prepare`, blocker.selection);
  const { marker } = await preparing(blocker.id);
  const beat = setInterval(() => { void call(a, `jobs/${blocker.id}/heartbeat`).catch(() => {}); }, 1000);
  try {
    await call(b, `jobs/${queued.id}/prepare`, queued.selection);
    const before = await job(queued.id);
    assert.equal(before.state, 'queued'); assert.equal(before.workerToken, null); assert.equal(before.asset, null);
    assert.equal((await events(queued.id)).length, 0);
    assert.equal(await live(marker), true);
    const releasedAt = Date.now();
    await call(b, `jobs/${queued.id}/release`);
    const released = await job(queued.id);
    assert.equal(released.state, 'queued'); assert.ok(released.releaseAt && released.releaseAt.getTime() >= releasedAt + 1500);
    await wait('queued release terminal and folder removed', async () => {
      const j = await job(queued.id);
      assert.notEqual(j.state, 'ready'); assert.equal((await events(queued.id)).length, 0);
      return ['expired', 'cancelled'].includes(j.state) && j.cancelRequested && !await exists(filePath(queued.id));
    }, 8000);
    assert.equal(await live(marker), true, 'Worker must remain occupied through queued release grace');
    assert.equal((await job(queued.id)).asset, null);
    console.log(JSON.stringify({ test: 'release-queued', result: 'PASS', preState: 'queued', elapsedMs: Date.now() - releasedAt, prepareInvocations: 0, publishReady: false }));

    // Assert the actual live prepare state immediately before releasing A.
    await preparing(blocker.id);
    clearInterval(beat);
    let deletionObservation: Promise<boolean> | undefined;
    const watcher = watch(filePath(blocker.id), (_event, name) => {
      if (name === 'media.mp4.part') deletionObservation ??= (async () => {
        if (await exists(filePath(`${blocker.id}/media.mp4.part`))) return false;
        return !await live(marker);
      })();
    });
    const prepareReleasedAt = Date.now();
    try {
      await call(a, `jobs/${blocker.id}/release`);
      await wait('SIGTERM handler reached', async () => (await events(blocker.id)).some(e => e.event === 'term_received'), 8000);
      assert.equal(await live(marker), true);
      assert.equal(await exists(filePath(`${blocker.id}/media.mp4.part`)), true, 'Do not delete while child handles SIGTERM');
      await allowExit(blocker.id);
      await wait('prepare child exited and staging cleaned', async () => {
        const j = await job(blocker.id);
        assert.notEqual(j.state, 'ready');
        return ['expired', 'cancelled'].includes(j.state) && j.workerToken === null && j.processUntil === null && j.asset?.state === 'deleted' && !await exists(filePath(blocker.id)) && !await live(marker);
      }, 8000);
      assert.ok(deletionObservation, 'Observe the actual partial deletion');
      assert.equal(await deletionObservation, true, 'Child must already be dead when deletion is observed');
      const history = await events(blocker.id);
      assert.equal(history.filter(e => e.event === 'prepare_started').length, 1);
      assert.ok(history.some(e => e.event === 'before_exit' && e.partialExists === true));
      await noPublish(blocker.id);
      console.log(JSON.stringify({ test: 'release-preparing', result: 'PASS', preState: 'preparing', childAliveAtSignal: true, partialPresentUntilExit: true, childDeadAtDeletion: true, elapsedMs: Date.now() - prepareReleasedAt }));
    } finally { watcher.close(); }
    // Once the worker becomes free, BullMQ drains the stale queued entry without preparing it.
    await wait('released queued entry drained', async () => {
      const entry = await queue.getJob(`prepare-${queued.id}`);
      return !entry || ['completed', 'failed'].includes(await entry.getState());
    }, 5000);
    await pause(500);
    assert.equal((await events(queued.id)).length, 0);
    assert.equal((await job(queued.id)).workerToken, null);
    assert.equal((await job(queued.id)).asset, null);
    await noPublish(queued.id);
    console.log('PASS queued job never prepared/published after worker became free');
  } finally { clearInterval(beat); await allowExit(blocker.id); }
}
main().catch(e => { console.error(e instanceof Error ? e.message : 'P3_RELEASE_FAILED'); process.exitCode = 1; }).finally(close);
