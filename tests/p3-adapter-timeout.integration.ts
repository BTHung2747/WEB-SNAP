import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { watch } from 'node:fs';
import { mkdir, readFile, readlink, readdir, stat, writeFile } from 'node:fs/promises';
import { after, db, filePath, limits, limitsSchema, queue } from '../packages/shared/src/core';
import { analyze, call, client, close, events, exists, guard, job, pause, wait, type Marker } from './p3-support';

type ProcessMarker = Marker & { pgid: number; partialBytes?: number; ignored?: boolean; phase: string };
const bounds = { fallback: 2000, allowance: 4000, cleanup: 8000, http: 5000, suite: 90000 };
const log = (detail: object) => console.log(JSON.stringify({ date: new Date().toISOString(), fixtureOnly: true, ...detail }));
const originalFetch = globalThis.fetch;
globalThis.fetch = (input, init) => originalFetch(input, { ...init, signal: AbortSignal.timeout(bounds.http) });
const history = async (id: string) => await events(id) as ProcessMarker[];
const ownedIds: string[] = [];
const observedProcesses: { id: string; marker: ProcessMarker }[] = [];

async function osProcess(pid: number) {
  try {
    const p = (await readFile(`/proc/${pid}/stat`, 'utf8')).split(') ')[1].split(' ');
    return { state: p[0], pgid: Number(p[2]), startTicks: p[19] };
  } catch (e: any) { if (['ENOENT', 'ESRCH'].includes(e.code)) return null; throw e; }
}
async function alive(m: ProcessMarker) {
  assert.equal(await readlink('/proc/self/ns/pid'), m.namespace, 'Observer must share worker PID namespace');
  const p = await osProcess(m.pid);
  return !!p && p.startTicks === m.startTicks && p.pgid === m.pgid && !['Z', 'X'].includes(p.state);
}
async function group(m: ProcessMarker) {
  assert.equal(await readlink('/proc/self/ns/pid'), m.namespace);
  const live: number[] = [];
  for (const name of await readdir('/proc')) {
    if (!/^\d+$/.test(name)) continue;
    const p = await osProcess(Number(name));
    if (p && p.pgid === m.pgid && !['Z', 'X'].includes(p.state)) live.push(Number(name));
  }
  return live;
}
async function noSuccess(id: string, phase: string, metadata: number) {
  const j = await job(id), e = await history(id);
  assert.notEqual(j.state, 'ready'); assert.notEqual(j.asset?.state, 'available');
  assert.equal(await db.mediaItem.count({ where: { jobId: id } }), metadata);
  assert.equal(e.filter(m => m.event === 'adapter_invoked').length, 1);
  assert.equal(e.filter(m => m.event === 'adapter_started').length, 1);
  assert.equal(e.filter(m => m.event === 'adapter_invoked' && m.phase === 'prepare').length, phase === 'prepare' ? 1 : 0);
  const metrics = await db.auditLog.findMany({ where: { actor: 'worker', action: 'worker.metrics' } });
  assert.equal(metrics.filter(r => (r.detail as any).id === id && (r.detail as any).phase === phase && (r.detail as any).result === 'complete').length, 0);
}
async function failed(id: string, phase: string, metadata: number) {
  const j = await job(id);
  assert.equal(j.state, 'failed'); assert.equal(j.errorCode, 'SOURCE_TIMEOUT');
  assert.equal(j.workerToken, null); assert.equal(j.processUntil, null); assert.equal(j.sourceUrl, null);
  assert.ok(j.ownerUntil > new Date()); assert.equal(j.releaseAt, null);
  if (phase === 'analyze') { assert.equal(j.asset, null); assert.equal(j.title, null); assert.equal(j.duration, null); }
  await noSuccess(id, phase, metadata);
}
async function twoSweeps(id: string, phase: string, metadata: number, sessionId: string) {
  for (let cycle = 1; cycle <= 2; cycle++) {
    await failed(id, phase, metadata);
    const probe = await db.downloadJob.create({ data: { sessionId, platform: 'youtube', state: 'ready', ownerUntil: after(120) } });
    ownedIds.push(probe.id);
    await mkdir(filePath(probe.id)); await writeFile(filePath(`${probe.id}/media.mp4`), 'sweep sentinel');
    const asset = await db.temporaryAsset.create({ data: { jobId: probe.id, path: `${probe.id}/media.mp4`, state: 'available', readyUntil: after(120) } });
    await db.temporaryAsset.update({ where: { id: asset.id }, data: { readyUntil: after(-1) } });
    const start = Date.now();
    await wait('background sweep sentinel', async () => {
      await failed(id, phase, metadata);
      const j = await job(probe.id);
      return j.state === 'expired' && j.asset?.state === 'deleted' && !(await exists(filePath(probe.id)));
    }, bounds.cleanup);
    log({ stage: 'sweep-observed', id, cycle, intervalMs: 1000, elapsedMs: Date.now() - start, invocationCount: 1, publish: false, ownerValid: true });
  }
}

async function run(mode: 'analyze-hang' | 'prepare-term' | 'prepare-ignore' | 'prepare-parent-close') {
  const phase = mode === 'analyze-hang' ? 'analyze' : 'prepare', deadline = phase === 'analyze' ? 5000 : 10000;
  const c = await client();
  let id: string, requestAt: number;
  if (phase === 'analyze') {
    requestAt = Date.now();
    ({ jobId: id } = await call(c, 'jobs/analyze', { url: 'https://youtu.be/toana000001' }));
  } else {
    const selected = await analyze(c, mode === 'prepare-term' ? 'toprep00001' : mode === 'prepare-parent-close' ? 'toclose0001' : 'toign000001');
    id = selected.id;
    assert.equal((await job(id)).state, 'selectable');
    requestAt = Date.now(); await call(c, `jobs/${id}/prepare`, selected.selection);
  }
  ownedIds.push(id);
  const responseAt = Date.now();
  let claimObservedAt = 0;
  await wait('worker claim', async () => {
    const j = await job(id);
    if (j.workerToken && j.processUntil) { claimObservedAt = Date.now(); return true; }
    return false;
  });
  await wait('child started/heartbeat marker', async () => (await history(id)).some(m => m.event === 'adapter_started') && await exists(`/control/${id}/heartbeat.json`));
  const marker = (await history(id)).find(m => m.event === 'adapter_invoked')!;
  observedProcesses.push({ id, marker });
  assert.equal(marker.pgid, marker.pid, 'runAdapter must detach its child process group');
  let helper: ProcessMarker | undefined;
  if (mode === 'prepare-ignore' || mode === 'prepare-parent-close') {
    await wait('helper process started', async () => (await history(id)).some(m => m.event === 'helper_started'));
    helper = (await history(id)).find(m => m.event === 'helper_started')!;
    observedProcesses.push({ id, marker: helper });
    assert.equal(helper.pgid, marker.pgid); assert.equal(await alive(helper), true);
  }
  const heartbeat = JSON.parse(await readFile(`/control/${id}/heartbeat.json`, 'utf8'));
  await wait('real child heartbeat advances', async () => {
    const b = JSON.parse(await readFile(`/control/${id}/heartbeat.json`, 'utf8'));
    assert.equal(b.pid, marker.pid); assert.equal(b.startTicks, marker.startTicks);
    return b.counter > heartbeat.counter && await alive(marker);
  });
  const pre = await job(id), partial = filePath(`${id}/media.mp4.part`), bytes = (await stat(partial)).size;
  assert.equal(pre.state, phase === 'analyze' ? 'analyzing' : 'preparing');
  assert.ok(pre.workerToken && pre.processUntil && pre.processUntil > new Date());
  assert.ok(pre.ownerUntil > after(30)); assert.equal(pre.releaseAt, null); assert.equal(pre.cancelRequested, false);
  if (phase === 'prepare') assert.equal(pre.asset!.state, 'staging'); else assert.equal(pre.asset, null);
  assert.equal(await alive(marker), true); assert.equal(bytes, 3072);
  assert.ok(Date.now() < marker.at + deadline - 1000, 'Assert pre-state before watchdog deadline');
  await noSuccess(id, phase, phase === 'analyze' ? 0 : 1);
  log({ test: mode, stage: 'pre-timeout', id, requestAt: new Date(requestAt).toISOString(), responseAt: new Date(responseAt).toISOString(), claimObservedAt: new Date(claimObservedAt).toISOString(), dbClaimAt: pre.updatedAt.toISOString(), invocationAt: new Date(marker.at).toISOString(), state: pre.state, asset: pre.asset?.state ?? null, tokenPresent: true, processLease: pre.processUntil!.toISOString(), ownerUntil: pre.ownerUntil.toISOString(), partialBytes: bytes, process: marker, helper: helper ?? null, deadlineMs: deadline, bounds, releaseCalls: 0, cancelCalls: 0, manualKillCalls: 0 });

  let deadAt: number | undefined, failedAt: number | undefined, cleanupAt: number | undefined;
  let deletionObservation: Promise<{ at: number; live: number[] } | null> | undefined;
  const watcher = watch(filePath(id), (event, name) => {
    if (event !== 'rename' || name !== 'media.mp4.part') return;
    deletionObservation ??= (async () => {
      if (await exists(partial)) return null;
      const live = await group(marker), at = Date.now();
      if (!live.length) deadAt ??= at;
      return { at, live };
    })();
    void deletionObservation.catch(() => {});
  });
  let termAliveObserved = false, ignoredStillAliveObserved = false;
  let parentStoppedHelperProgress = false;
  let parentStoppedAt: number | undefined;
  let helperCounterAfterParent: number | undefined;
  try {
    await wait('watchdog failure/process death/lifecycle cleanup', async () => {
      const j = await job(id), e = await history(id), live = await group(marker);
      const term = e.find(m => m.event === 'term_received');
      if (mode === 'prepare-parent-close' && term && helper && !(await alive(marker)) && await alive(helper)) {
        parentStoppedAt ??= Date.now();
        const h = JSON.parse(await readFile(`/control/${id}/helper-heartbeat.json`, 'utf8'));
        if (helperCounterAfterParent === undefined) helperCounterAfterParent = h.counter;
        else if (h.counter > helperCounterAfterParent && !parentStoppedHelperProgress) {
          parentStoppedHelperProgress = true;
          log({ test: mode, stage: 'parent-stopped-helper-progress', id, parentStoppedAt: new Date(parentStoppedAt).toISOString(), state: j.state, tokenPresent: !!j.workerToken, leasePresent: !!j.processUntil, partialPresent: await exists(partial), folderPresent: await exists(filePath(id)), helperCounterBefore: helperCounterAfterParent, helperCounterAfter: h.counter, parentAlive: false, helperAlive: true });
          assert.ok(j.workerToken && j.processUntil, 'R15: token/lease released while helper remains live');
          assert.equal(await exists(partial), true, 'R15: partial deleted while helper remains live');
        }
        if (!parentStoppedHelperProgress) return false;
      }
      if (term && live.includes(marker.pid) && await exists(partial)) {
        termAliveObserved = true;
        if (helper && Date.now() >= term.at + 1000 && await alive(helper)) ignoredStillAliveObserved = true;
      }
      if (!live.length) deadAt ??= Date.now();
      if (!(await exists(partial))) assert.deepEqual(live, [], 'No cleanup while any group member still runs');
      if (j.state === 'failed') {
        failedAt ??= Date.now();
        assert.equal(j.errorCode, 'SOURCE_TIMEOUT'); assert.deepEqual(live, []);
        assert.ok(j.ownerUntil > new Date()); assert.equal(j.workerToken, null); assert.equal(j.processUntil, null);
      }
      assert.notEqual(j.state, 'ready'); assert.notEqual(j.asset?.state, 'available');
      if (!deadAt) assert.ok(Date.now() <= requestAt + deadline + bounds.fallback + bounds.allowance, 'Child death upper bound');
      if (!failedAt) assert.ok(Date.now() <= requestAt + deadline + bounds.fallback + bounds.allowance, 'Failure upper bound');
      if (deadAt) assert.ok(Date.now() <= deadAt + bounds.cleanup, 'Cleanup upper bound after group death');
      if (j.state !== 'failed' || j.workerToken || j.processUntil || !deadAt || await exists(filePath(id)) || (phase === 'prepare' && j.asset?.state !== 'deleted')) return false;
      cleanupAt = Date.now(); return true;
    }, deadline + bounds.fallback + bounds.allowance + bounds.cleanup);
    const e = await history(id), term = e.find(m => m.event === 'term_received')!;
    assert.ok(term, 'Actual SIGTERM handler must record watchdog signal');
    assert.ok(term.at >= requestAt + deadline - 250, 'No premature owner/disk/test-watchdog timeout');
    assert.equal(term.ignored, mode === 'prepare-ignore'); assert.equal(term.partialExists, true);
    assert.equal(termAliveObserved, true);
    assert.ok(deadAt! <= requestAt + deadline + bounds.fallback + bounds.allowance);
    assert.ok(failedAt! <= requestAt + deadline + bounds.fallback + bounds.allowance);
    assert.ok(cleanupAt! <= deadAt! + bounds.cleanup);
    assert.ok(deletionObservation, 'Actual partial deletion event required');
    const deletion = await deletionObservation; assert.ok(deletion); assert.deepEqual(deletion.live, []);
    if (helper && mode === 'prepare-ignore') {
      assert.equal(ignoredStillAliveObserved, true);
      assert.ok(e.some(m => m.event === 'helper_term_received' && m.ignored));
      assert.equal(await alive(helper), false);
      assert.ok(deadAt! - term.at >= 1800, 'Ignored SIGTERM proceeds through ~2s fallback');
      assert.equal(e.some(m => m.event === 'before_exit'), false);
    } else assert.ok(e.some(m => m.event === 'before_exit' && m.partialExists));
    if (mode === 'prepare-parent-close') {
      assert.equal(parentStoppedHelperProgress, true);
      assert.ok(e.some(m => m.event === 'helper_term_received' && m.ignored));
      assert.equal(await alive(helper!), false);
      assert.ok(deadAt! - term.at >= 1800);
    }
    await failed(id, phase, phase === 'analyze' ? 0 : 1);
    const entry = await queue.getJob(`${phase}-${id}`);
    assert.ok(!entry || ['completed', 'failed'].includes(await entry.getState()));
    log({ test: mode, stage: 'timeout-cleaned', id, termAt: new Date(term.at).toISOString(), deadAt: new Date(deadAt!).toISOString(), failedAt: new Date(failedAt!).toISOString(), deletionObservedAt: new Date(deletion.at).toISOString(), cleanupAt: new Date(cleanupAt!).toISOString(), termAfterRequestMs: term.at - requestAt, deathAfterTermMs: deadAt! - term.at, cleanupAfterDeadMs: cleanupAt! - deadAt!, partialBytes: bytes, childDeadAtDeletion: true, groupLiveAtDeletion: deletion.live, ignoredStillAliveObserved, signalKillDirectlyObserved: false, state: 'failed', errorCode: 'SOURCE_TIMEOUT', asset: phase === 'prepare' ? 'deleted' : null });
    await twoSweeps(id, phase, phase === 'analyze' ? 0 : 1, pre.sessionId);
    assert.deepEqual(await group(marker), []);
    log({ test: mode, result: 'PASS', id, elapsedMs: Date.now() - requestAt, invocationCount: 1, prepareInvocations: phase === 'prepare' ? 1 : 0, successfulCompletions: 0, observedSweepCycles: 2 });
  } finally { watcher.close(); }
}

async function main() {
  await guard();
  assert.equal(await db.downloadJob.count({ where: { state: { in: ['analyzing', 'queued', 'preparing'] } } }), 0, 'Dedicated test harness must be idle');
  const saved = await db.settings.findUnique({ where: { id: 'main' } });
  const settings = limitsSchema.parse({ ...await limits(), analyzeTimeout: 5, prepareTimeout: 10, sessionTtl: 120, sweepSeconds: 1 });
  const start = Date.now();
  try {
    await db.settings.upsert({ where: { id: 'main' }, create: { value: settings }, update: { value: settings } });
    assert.equal((await limits()).analyzeTimeout, 5); assert.equal((await limits()).prepareTimeout, 10);
    log({ stage: 'guard-settings', project: process.env.P3_TEST_GUARD, database: 'wed_snap_p3_test', redisDb: 14, namespace: await readlink('/proc/self/ns/pid'), node: process.version, analyzeSeconds: 5, prepareSeconds: 10, ownerSeconds: 120, sweepSeconds: 1, bounds });
    if (!process.argv.includes('--r15-only')) {
      await run('analyze-hang'); await run('prepare-term'); await run('prepare-ignore');
    }
    await run('prepare-parent-close');
    assert.ok(Date.now() - start < bounds.suite);
  } finally {
    try {
    // Emergency cleanup is logged separately and NEVER turns a failed assertion into PASS.
    for (const observed of observedProcesses) {
      if (await alive(observed.marker)) {
        await guard();
        await promisify(execFile)('python3', ['/app/tests/p3-kill-fixture.py', JSON.stringify(observed.marker), observed.id], { timeout: 5000 });
        log({ stage: 'emergency-cleanup-after-FAIL', runtimePass: false, id: observed.id, pid: observed.marker.pid, namespace: observed.marker.namespace, identityGuarded: true, signal: 'SIGKILL-pidfd' });
        await wait('emergency fixture stopped', async () => !(await alive(observed.marker)), 5000);
      }
    }
    // Wait for the actual supervisor/lifecycle, including on assertion failure.
    // Never cancel/release/manual-kill to manufacture SOURCE_TIMEOUT.
      for (const id of ownedIds) await wait('finally fixture lifecycle cleanup', async () => {
        const j = await job(id);
        return !j.workerToken && !j.processUntil && (!j.asset || j.asset.state === 'deleted') && !(await exists(filePath(id)));
      }, 25000);
    } finally {
      if (saved) await db.settings.update({ where: { id: 'main' }, data: { value: saved.value! } });
      else await db.settings.deleteMany({ where: { id: 'main' } });
      assert.deepEqual((await db.settings.findUnique({ where: { id: 'main' } }))?.value ?? null, saved?.value ?? null);
      globalThis.fetch = originalFetch;
      log({ stage: 'finally', settingsExactlyRestored: true, fixtureCount: ownedIds.length, dataReset: false });
    }
  }
}
main().catch(e => { console.error(e instanceof Error ? e.stack : 'ADAPTER_TIMEOUT_FAILED'); process.exitCode = 1; }).finally(close);
