import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { watch } from 'node:fs';
import { readFile, readlink, readdir, stat, writeFile } from 'node:fs/promises';
import { after, db, filePath, limits, limitsSchema } from '../packages/shared/src/core';
import { analyze, call, client, close, controlPath, events, exists, guard, job, live, pause, wait, type Marker } from './p3-support';

const cap = { input: 8192, output: 4096, duration: 600 };
const hardCaps = { maxDuration: 600, maxBytes: 209715200, maxInputBytes: 262144000 };
const bounds = { http: 5000, gate: 15000, state: 10000, cleanup: 8000, case: 20000 };
type ByteMarker = Marker & { pgid: number; actualBytes: number; reportedBytes: number; partialBytes: number };
const ownedIds: string[] = [];
const digest = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
const pattern = (size: number) => Buffer.from(Array.from({ length: size }, (_, i) => (i * 19 + 5) & 255));
const log = (detail: object) => console.log(JSON.stringify({ date: new Date().toISOString(), fixtureOnly: true, ...detail }));
const originalFetch = globalThis.fetch;
globalThis.fetch = (input, init) => originalFetch(input, { ...init, signal: AbortSignal.timeout(bounds.http) });

async function group(marker: ByteMarker) {
  assert.equal(await readlink('/proc/self/ns/pid'), marker.namespace, 'Observe actual worker namespace');
  const alive: number[] = [];
  for (const name of await readdir('/proc')) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const p = (await readFile(`/proc/${name}/stat`, 'utf8')).split(') ')[1].split(' ');
      if (Number(p[2]) === marker.pgid && !['Z', 'X'].includes(p[0])) alive.push(Number(name));
    } catch (e: any) { if (!['ENOENT', 'ESRCH'].includes(e.code)) throw e; }
  }
  return alive;
}
async function completions(id: string) {
  const rows = await db.auditLog.findMany({ where: { actor: 'worker', action: 'worker.metrics' } });
  return rows.filter(r => (r.detail as any).id === id && (r.detail as any).phase === 'prepare' && (r.detail as any).result === 'complete').length;
}
async function charged() {
  const rows = await db.egressBudget.findMany();
  return rows.reduce((sum, row) => sum + row.charged, 0n);
}
async function run(size: number) {
  const started = Date.now(), c = await client();
  const selected = await analyze(c, `limout0${size}`), id = selected.id;
  ownedIds.push(id);
  assert.equal((await job(id)).state, 'selectable');
  assert.equal(await db.temporaryAsset.count({ where: { jobId: id } }), 0);
  const requestedAt = Date.now();
  await call(c, `jobs/${id}/prepare`, selected.selection);
  await wait('byte fixture preparing and gate', async () => {
    const j = await job(id), records = await events(id);
    return j.state === 'preparing' && !!j.workerToken && !!j.processUntil && j.asset?.state === 'staging' && records.some(e => e.event === 'prepare_started');
  }, bounds.state);
  const marker = (await events(id)).find(e => e.event === 'prepare_started') as ByteMarker;
  assert.equal(marker.pgid, marker.pid);
  assert.equal(marker.actualBytes, size); assert.equal(marker.reportedBytes, size); assert.equal(marker.partialBytes, size);
  assert.equal(await live(marker), true); assert.deepEqual(await group(marker), [marker.pid]);
  const beat = JSON.parse(await readFile(controlPath(id, 'heartbeat.json'), 'utf8'));
  await wait('byte fixture real process progress', async () => {
    const current = JSON.parse(await readFile(controlPath(id, 'heartbeat.json'), 'utf8'));
    return current.counter > beat.counter && await live(marker);
  });
  const pre = await job(id), output = filePath(`${id}/media.mp4`), partial = filePath(`${id}/media.mp4.part`);
  const actual = await readFile(output);
  assert.equal(actual.length, size); assert.equal((await stat(partial)).size, size);
  assert.deepEqual(actual, pattern(size));
  assert.equal(pre.state, 'preparing'); assert.equal(pre.asset?.state, 'staging');
  assert.ok(pre.workerToken && pre.processUntil && pre.processUntil > new Date());
  assert.ok(pre.ownerUntil > after(30)); assert.equal(pre.cancelRequested, false); assert.equal(pre.releaseAt, null);
  assert.equal(await completions(id), 0);
  const configured = await limits(); assert.equal(configured.maxBytes, cap.output); assert.equal(configured.maxInputBytes, cap.input);
  log({ test: `output-${size}`, stage: 'pre-prepare-output', id, requestedAt: new Date(requestedAt).toISOString(),
    state: pre.state, asset: pre.asset?.state, tokenPresent: true, processLeaseValid: true, ownerValid: true,
    metadataFilesize: null, cap, actualBytes: actual.length, reportedBytes: marker.reportedBytes, partialBytes: size,
    hash: digest(actual), process: marker, bounds });

  let deletionObservation: Promise<{ at: number; groupLive: number[] } | null> | undefined;
  const watcher = watch(filePath(id), (event, name) => {
    if (event !== 'rename' || name !== 'media.mp4.part' || deletionObservation) return;
    deletionObservation = (async () => {
      if (await exists(partial)) return null;
      return { at: Date.now(), groupLive: await group(marker) };
    })();
    void deletionObservation.catch(() => {});
  });
  let deadAt: number | undefined;
  try {
    await writeFile(controlPath(id, 'output-allowed'), 'allow fixture to return its actual size, without injecting any error');
    if (size > cap.output) {
      const states = new Set<string>();
      await wait('production worker rejects reported output over cap', async () => {
        const j = await job(id), members = await group(marker);
        states.add(j.state); assert.notEqual(j.state, 'ready'); assert.notEqual(j.asset?.state, 'available');
        if (!members.length) deadAt ??= Date.now();
        if (!(await exists(partial))) assert.deepEqual(members, [], 'Output limit cleanup must wait for group death');
        if (j.state === 'failed') {
          assert.equal(j.errorCode, 'LIMIT_EXCEEDED'); assert.equal(j.workerToken, null); assert.equal(j.processUntil, null);
          assert.deepEqual(members, []);
        }
        return j.state === 'failed' && j.asset?.state === 'deleted' && !(await exists(filePath(id)));
      }, bounds.state + bounds.cleanup);
      assert.ok(deadAt); assert.ok(deletionObservation, 'Observe actual partial deletion');
      const deletion = await deletionObservation; assert.ok(deletion); assert.deepEqual(deletion.groupLive, []);
      const post = await job(id); assert.equal(post.state, 'failed'); assert.equal(post.errorCode, 'LIMIT_EXCEEDED');
      assert.equal(await completions(id), 0); assert.equal(post.sourceUrl, null);
      assert.ok(Date.now() <= deadAt + bounds.cleanup);
      log({ test: `output-${size}`, stage: 'failed-cleaned', id, actualBytes: size, reportedBytes: size, cap: cap.output,
        state: post.state, errorCode: post.errorCode, asset: post.asset?.state, deadObservedAt: new Date(deadAt).toISOString(),
        deletionObservedAt: new Date(deletion.at).toISOString(), groupLiveAtDeletion: deletion.groupLive,
        cleanupAfterDeadMs: Date.now() - deadAt, completionCount: 0, statesObserved: [...states], ready: false, available: false });
    } else {
      await wait('within cap ready and completion metric', async () => (await job(id)).state === 'ready' && await completions(id) === 1);
      const ready = await job(id);
      assert.equal(ready.asset?.state, 'available'); assert.equal(ready.asset!.size, BigInt(size));
      assert.equal(ready.workerToken, null); assert.equal(ready.processUntil, null); assert.deepEqual(await group(marker), []);
      assert.deepEqual(await readFile(output), pattern(size));
      const chargedBefore = await charged();
      const ticket = await call(c, `jobs/${id}/download-ticket`);
      const response = await fetch('http://api:3000' + ticket.url, { headers: { cookie: c.cookie } });
      assert.equal(response.status, 200); assert.equal(Number(response.headers.get('content-length')), size);
      const downloaded = Buffer.from(await response.arrayBuffer()); assert.deepEqual(downloaded, pattern(size));
      await wait('full body lease finalized', async () => {
        const leases = await db.transferLease.findMany({ where: { assetId: ready.asset!.id } });
        return leases.length === 1 && leases[0].state === 'server_finished' && !!leases[0].endedAt && leases[0].bytes === BigInt(size) && leases[0].reserved === BigInt(size);
      });
      assert.equal(await charged() - chargedBefore, BigInt(size));
      log({ test: `output-${size}`, stage: 'ready-full', id, state: 'ready', asset: 'available', actualBytes: size,
        reportedBytes: size, persistedSize: Number(ready.asset!.size), http: response.status, bodyBytes: downloaded.length,
        hash: digest(downloaded), completionCount: 1, chargedDelta: String(await charged() - chargedBefore), cap: cap.output });
      await wait('normal full transfer lifecycle cleanup', async () => (await job(id)).asset?.state === 'deleted' && !(await exists(filePath(id))), bounds.cleanup);
      assert.ok(deletionObservation); const deletion = await deletionObservation; assert.ok(deletion); assert.deepEqual(deletion.groupLive, []);
      log({ test: `output-${size}`, stage: 'normal-cleaned', id, groupLiveAtDeletion: deletion.groupLive,
        state: (await job(id)).state, asset: 'deleted', completionCount: await completions(id) });
    }
    const history = await events(id);
    assert.equal(history.filter(e => e.event === 'prepare_started').length, 1);
    assert.equal(history.filter(e => e.event === 'before_exit').length, 1);
    assert.equal(history.filter(e => e.event === 'fixture_gate_timeout').length, 0);
    assert.deepEqual(await group(marker), []); assert.ok(Date.now() - started < bounds.case);
    log({ test: `output-${size}`, result: 'PASS', elapsedMs: Date.now() - started, invocationCount: 1,
      completionCount: await completions(id), actualReportedMatch: true, platformCertified: false });
  } finally { watcher.close(); }
}

async function main() {
  await guard();
  assert.equal(await db.downloadJob.count({ where: { state: { in: ['analyzing', 'queued', 'preparing'] } } }), 0, 'P3 must be idle');
  assert.equal(await db.transferLease.count({ where: { state: 'started' } }), 0, 'No unrelated active transfer');
  const saved = await db.settings.findUniqueOrThrow({ where: { id: 'main' } });
  const original = limitsSchema.parse(saved.value);
  limitsSchema.parse({ ...original, ...hardCaps });
  for (const [field, maximum] of Object.entries(hardCaps)) {
    assert.equal(limitsSchema.safeParse({ ...original, ...hardCaps, [field]: maximum + 1 }).success, false);
  }
  const override = limitsSchema.parse({ ...original, maxDuration: cap.duration, maxBytes: cap.output, maxInputBytes: cap.input,
    sessionTtl: 120, readyTtl: 30, releaseGrace: 2, retryGrace: 2, sweepSeconds: 1, prepareTimeout: 30 });
  log({ stage: 'guard-schema-matrix', project: process.env.P3_TEST_GUARD, database: 'wed_snap_p3_test', redisDb: 14,
    node: process.version, namespace: await readlink('/proc/self/ns/pid'), cap, hardCaps, hardCapsAccepted: true,
    hardCapsPlusOneRejected: true, settingsOverrideValid: true, bounds, chargedPreserved: String(await charged()) });
  let passed = false;
  try {
    await db.settings.update({ where: { id: 'main' }, data: { value: override as any } });
    for (const size of [cap.output - 1, cap.output, cap.output + 1]) await run(size);
    passed = true;
  } finally {
    try {
      await guard();
      for (const id of ownedIds) {
        const j = await job(id);
        if (j.workerToken) {
          log({ stage: 'finally-unblock-after-FAIL', runtimePass: false, id, fixtureOwned: true });
          await writeFile(controlPath(id, 'output-allowed'), 'finally unblock owned fixture only');
        }
        await wait('fixture worker finishes before finally cleanup', async () => !(await job(id)).workerToken, bounds.gate + bounds.cleanup);
        if (await exists(filePath(id))) {
          await db.downloadJob.update({ where: { id }, data: { ownerUntil: after(-1) } });
          await wait('finally owned fixture lifecycle cleanup', async () => !(await exists(filePath(id))) && (await job(id)).asset?.state === 'deleted', bounds.cleanup);
        }
      }
    } finally {
      await db.settings.update({ where: { id: 'main' }, data: { value: saved.value as any } });
      assert.deepEqual((await db.settings.findUniqueOrThrow({ where: { id: 'main' } })).value, saved.value);
      log({ stage: 'finally', settingsExactlyRestored: true, fixtureCount: ownedIds.length, dataReset: false,
        chargedPreserved: String(await charged()), result: passed ? 'PASS' : 'FAIL' });
    }
  }
}
main().catch(e => { console.error(e instanceof Error ? e.stack : 'P2_BYTE_LIMITS_FAILED'); process.exitCode = 1; }).finally(close);
