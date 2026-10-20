import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { watch } from 'node:fs';
import { mkdir, readFile, readlink, readdir, stat, writeFile } from 'node:fs/promises';
import { after, db, filePath, limitsSchema } from '../packages/shared/src/core';
import { analyze, call, client, close, controlPath, events, exists, guard, job, live, wait, type Marker } from './p3-support';

const bounds = { http: 5000, gate: 5000, watchdog: 60000, owner: 120000, cleanup: 8000, failure: 35000 };
const matrix = [
  { mode: 'control', source: 'sockctrl001', code: null, requests: [1, 1], bound: 15000 },
  { mode: 'close', source: 'sockclose01', code: 'CONTENT_UNAVAILABLE', requests: [2, 2], bound: 15000 },
  { mode: 'stall', source: 'sockstall01', code: 'SOURCE_TIMEOUT', requests: [2, 2], bound: 35000 },
] as const;
type Process = Marker & { pgid: number };
type ServerEvent = { at: number; event: string; job?: string; mode?: string; attempt?: number; sentBytes?: number; declaredBytes?: number; reason?: string };
const runId = randomUUID(), owned: string[] = [];
const root = `/control/socket-runs/${runId}`;
const server = 'http://socket-test:8765';
const log = (detail: object) => console.log(JSON.stringify({ date: new Date().toISOString(), localSocketOnly: true, ...detail }));
const hash = (data: Buffer) => createHash('sha256').update(data).digest('hex');
const originalFetch = globalThis.fetch;
globalThis.fetch = (input, init) => originalFetch(input, { ...init, signal: AbortSignal.timeout(bounds.http) });
const charged = async () => (await db.egressBudget.findMany()).reduce((n, r) => n + r.charged, 0n);
async function serverEvents(id?: string): Promise<ServerEvent[]> {
  const records = (await readFile(`${root}/server.jsonl`, 'utf8')).trim().split('\n').filter(Boolean).map(s => JSON.parse(s));
  return id ? records.filter(r => r.job === id) : records;
}
async function group(m: Process) {
  assert.equal(await readlink('/proc/self/ns/pid'), m.namespace);
  const members: number[] = [];
  for (const name of await readdir('/proc')) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const p = (await readFile(`/proc/${name}/stat`, 'utf8')).split(') ')[1].split(' ');
      if (Number(p[2]) === m.pgid && !['Z', 'X'].includes(p[0])) members.push(Number(name));
    } catch (e: any) { if (!['ENOENT', 'ESRCH'].includes(e.code)) throw e; }
  }
  return members;
}
async function completions(id: string) {
  const rows = await db.auditLog.findMany({ where: { actor: 'worker', action: 'worker.metrics' } });
  return rows.filter(r => (r.detail as any).id === id && (r.detail as any).phase === 'prepare' && (r.detail as any).result === 'complete').length;
}
async function assertFailed(id: string, code: string, m: Process) {
  const j = await job(id);
  assert.equal(j.state, 'failed'); assert.equal(j.errorCode, code); assert.equal(j.asset?.state, 'deleted');
  assert.equal(j.workerToken, null); assert.equal(j.processUntil, null); assert.equal(j.sourceUrl, null);
  assert.equal(j.releaseAt, null); assert.ok(j.ownerUntil > new Date());
  assert.equal(await completions(id), 0); assert.equal(await exists(filePath(id)), false);
  assert.deepEqual(await group(m), []); assert.equal(await live(m), false);
  assert.equal((await events(id)).filter(e => e.event === 'socket_invoked').length, 1);
}
async function twoSweeps(id: string, code: string, m: Process, sessionId: string) {
  for (let cycle = 1; cycle <= 2; cycle++) {
    await assertFailed(id, code, m);
    const probe = await db.downloadJob.create({ data: { sessionId, platform: 'youtube', state: 'ready', ownerUntil: after(120) } });
    owned.push(probe.id);
    await mkdir(filePath(probe.id)); await writeFile(filePath(`${probe.id}/media.mp4`), 'owned sweep sentinel');
    const a = await db.temporaryAsset.create({ data: { jobId: probe.id, path: `${probe.id}/media.mp4`, state: 'available', readyUntil: after(120) } });
    await db.temporaryAsset.update({ where: { id: a.id }, data: { readyUntil: after(-1) } });
    const start = Date.now();
    await wait('next real background sweep', async () => {
      await assertFailed(id, code, m);
      const p = await job(probe.id);
      return p.state === 'expired' && p.asset?.state === 'deleted' && !(await exists(filePath(probe.id)));
    }, bounds.cleanup);
    log({ stage: 'sweep-observed', id, cycle, elapsedMs: Date.now() - start, group: [], invocation: 1, completion: 0, noReappearance: true });
  }
}
async function run(test: typeof matrix[number], sourceSha: string, payload: { bytes: number; sha256: string }) {
  const c = await client(), selected = await analyze(c, test.source), id = selected.id;
  owned.push(id);
  assert.equal((await job(id)).state, 'selectable');
  assert.equal(await db.temporaryAsset.count({ where: { jobId: id } }), 0);
  await mkdir(`/control/${id}`, { recursive: true });
  await writeFile(controlPath(id, 'socket.json'), JSON.stringify({ run: runId, mode: test.mode, sourceSha }));
  const start = Date.now();
  await call(c, `jobs/${id}/prepare`, selected.selection);
  const partial = filePath(`${id}/media.mp4.part`);
  await wait('real download partial before server fault', async () => {
    const j = await job(id), ev = await events(id), se = await serverEvents(id);
    return j.state === 'preparing' && j.asset?.state === 'staging' && !!j.workerToken &&
      ev.some(e => e.event === 'download_progress' && (e as any).downloadedBytes > 0) &&
      se.some(e => e.event === 'partial_sent') && await exists(partial) && (await stat(partial)).size > 0;
  }, bounds.gate);
  const m = (await events(id)).find(e => e.event === 'socket_invoked') as Process;
  assert.ok(m); assert.equal(m.pgid, m.pid); assert.equal(await live(m), true); assert.deepEqual(await group(m), [m.pid]);
  const pre = await job(id), bytes = (await stat(partial)).size, before = await serverEvents(id);
  assert.equal(pre.state, 'preparing'); assert.equal(pre.asset?.state, 'staging');
  assert.ok(pre.workerToken && pre.processUntil && pre.processUntil > new Date());
  assert.ok(pre.ownerUntil > after(60)); assert.equal(pre.cancelRequested, false); assert.equal(pre.releaseAt, null);
  assert.equal(await completions(id), 0); assert.equal(before.filter(e => e.event === 'trigger').length, 0);
  assert.equal(before.filter(e => e.event === 'request').length, 1);
  log({ stage: 'pre-fault', mode: test.mode, id, state: pre.state, asset: pre.asset?.state,
    tokenPresent: true, processLease: pre.processUntil!.toISOString(), ownerUntil: pre.ownerUntil.toISOString(),
    partialBytes: bytes, process: m, sourceSha, expectedCode: test.code, bounds, server: before });
  let deletion: Promise<{ at: number; group: number[] } | null> | undefined, deadAt: number | undefined;
  const watcher = watch(filePath(id), (event, name) => {
    if (event !== 'rename' || name !== 'media.mp4.part' || deletion) return;
    deletion = (async () => {
      if (await exists(partial)) return null;
      return { at: Date.now(), group: await group(m) };
    })();
    void deletion.catch(() => {});
  });
  try {
    const triggerAt = Date.now(); await writeFile(`${root}/${id}.allow`, 'pre-state asserted; allow server behavior');
    if (test.code) {
      await wait('production socket error and lifecycle cleanup', async () => {
        const j = await job(id), members = await group(m);
        assert.notEqual(j.state, 'ready'); assert.notEqual(j.asset?.state, 'available');
        if (!members.length) deadAt ??= Date.now();
        if (!(await exists(partial))) assert.deepEqual(members, [], 'process group must stop before deletion');
        if (j.state === 'failed') assert.equal(j.errorCode, test.code);
        return j.state === 'failed' && j.asset?.state === 'deleted' && !(await exists(filePath(id)));
      }, test.bound);
      assert.ok(deadAt && deletion); const d = await deletion; assert.ok(d); assert.deepEqual(d.group, []);
      assert.ok(Date.now() - deadAt <= bounds.cleanup); assert.ok(Date.now() - start < test.bound);
      assert.ok(Date.now() - m.at < bounds.watchdog, 'socket fault before runtime watchdog');
      await assertFailed(id, test.code, m);
      const se = await serverEvents(id), req = se.filter(e => e.event === 'request');
      assert.equal(req.length, test.requests[0]);
      if (test.mode === 'stall') {
        assert.ok(Date.now() - triggerAt >= 19000, 'two actual 10s socket read timeouts');
        assert.equal(se.some(e => e.event === 'close' && e.at < triggerAt + 10000), false, 'server cannot close early to manufacture timeout');
      }
      log({ stage: 'failed-cleaned', mode: test.mode, id, code: test.code, elapsedMs: Date.now() - start,
        deadObservedAt: new Date(deadAt).toISOString(), deletionObservedAt: new Date(d.at).toISOString(),
        groupAtDeletion: d.group, cleanupAfterDeadMs: Date.now() - deadAt, invocation: 1, completion: 0,
        downloaderRequests: req.length, downloaderRetries: req.length - 1, server: se, client: await events(id) });
      await twoSweeps(id, test.code, m, pre.sessionId);
    } else {
      await wait('real MP4 production probe -> ready', async () => (await job(id)).state === 'ready' && await completions(id) === 1, test.bound);
      const j = await job(id); assert.equal(j.asset?.state, 'available'); assert.equal(j.asset!.size, BigInt(payload.bytes));
      assert.equal(j.workerToken, null); assert.equal(j.processUntil, null); assert.deepEqual(await group(m), []);
      assert.equal(hash(await readFile(filePath(`${id}/media.mp4`))), payload.sha256);
      const budget = await charged(), ticket = await call(c, `jobs/${id}/download-ticket`);
      const response = await fetch('http://api:3000' + ticket.url, { headers: { cookie: c.cookie } });
      assert.equal(response.status, 200); assert.equal(Number(response.headers.get('content-length')), payload.bytes);
      const data = Buffer.from(await response.arrayBuffer()); assert.equal(data.length, payload.bytes); assert.equal(hash(data), payload.sha256);
      await wait('transfer finalized exact bytes', async () => {
        const leases = await db.transferLease.findMany({ where: { assetId: j.asset!.id } });
        return leases.length === 1 && leases[0].state === 'server_finished' && !!leases[0].endedAt && leases[0].bytes === BigInt(payload.bytes);
      });
      assert.equal(await charged() - budget, BigInt(payload.bytes));
      await wait('full-body grace and cleanup', async () => (await job(id)).asset?.state === 'deleted' && !(await exists(filePath(id))), bounds.cleanup);
      // HttpFD promotes .part to .mp4 BEFORE ffprobe/parent exit; that rename is not cleanup.
      assert.deepEqual(await group(m), []);
      log({ stage: 'control-full-cleaned', id, bytes: data.length, sha256: hash(data), http: 200, completion: 1,
        ffprobeProductionPassed: true, chargedDelta: String(await charged() - budget), server: await serverEvents(id), client: await events(id) });
    }
    const se = await serverEvents(id), requests = se.filter(e => e.event === 'request');
    assert.equal(requests.length, test.requests[1]); assert.ok(requests.every(e => e.declaredBytes! <= 262144));
    assert.equal((await events(id)).filter(e => e.event === 'socket_invoked').length, 1);
    assert.equal((await events(id)).filter(e => e.event === 'entry_finished').length, 1);
    log({ mode: test.mode, result: 'PASS', id, invocation: 1, requests: requests.length, elapsedMs: Date.now() - start });
  } finally { watcher.close(); }
}
async function main() {
  await guard();
  assert.equal(await db.downloadJob.count({ where: { state: { in: ['analyzing', 'queued', 'preparing'] } } }), 0);
  assert.equal(await db.transferLease.count({ where: { state: 'started' } }), 0);
  let serverGuard: any;
  await wait('guarded real socket server ready', async () => {
    try { serverGuard = await (await fetch(server + '/guard')).json(); return true; } catch { return false; }
  });
  assert.equal(serverGuard.guard, 'wed-snap-p3-test'); assert.equal(serverGuard.server, 'p3-real-socket-v1');
  assert.ok(serverGuard.pid && serverGuard.startTicks && serverGuard.namespace);
  assert.notEqual(serverGuard.namespace, await readlink('/proc/self/ns/pid'), 'server has isolated container PID namespace');
  const sourceSha = hash(await readFile('/app/production/media_adapter.py'));
  const saved = await db.settings.findUniqueOrThrow({ where: { id: 'main' } });
  const original = limitsSchema.parse(saved.value), budgetBefore = await charged();
  assert.equal(original.sweepSeconds, 1, 'Background worker interval is fixed at startup; require existing P3 sweep1s');
  const override = limitsSchema.parse({ ...original, prepareTimeout: 60, sessionTtl: 120, readyTtl: 30, sweepSeconds: 1, retryGrace: 2 });
  log({ stage: 'matrix-before-write', project: process.env.P3_TEST_GUARD, database: 'wed_snap_p3_test', redisDb: 14,
    workerNamespace: await readlink('/proc/self/ns/pid'), serverGuard, sourceSha, chargedBefore: String(budgetBefore),
    matrix, bounds, settingsOriginal: saved.value, settingsOverride: override,
    capsUnchanged: { maxInputBytes: original.maxInputBytes, maxBytes: original.maxBytes, maxDuration: original.maxDuration },
    stubs: ['metadata/extractor', 'private test route'], real: ['HTTP socket', 'yt-dlp HttpFD', 'bounded read', 'progress hook', 'error mapping', 'FFprobe', 'worker lifecycle'] });
  let passed = false;
  try {
    await db.settings.update({ where: { id: 'main' }, data: { value: override as any } });
    const arm = await originalFetch(server + '/arm', { method: 'POST', body: JSON.stringify({ run: runId }), signal: AbortSignal.timeout(20000) });
    assert.equal(arm.status, 200); const payload = await arm.json() as any;
    assert.ok(payload.bytes > 32768 && payload.bytes <= 262144); log({ stage: 'payload', ...payload });
    for (const test of matrix) await run(test, sourceSha, payload);
    // Wait for finite stall handlers to log actual closes, not just process/file existence.
    await wait('all source responses closed', async () => {
      const se = await serverEvents(); return se.filter(e => e.event === 'close').length === se.filter(e => e.event === 'request').length;
    }, 18000);
    log({ stage: 'server-final', events: await serverEvents() });
    assert.equal(hash(await readFile('/app/production/media_adapter.py')), sourceSha);
    passed = true;
  } finally {
    try {
      await guard();
      for (const id of owned) {
        const j = await job(id);
        if (j.workerToken) {
          log({ stage: 'cleanup-after-FAIL', id, runtimePass: false, action: 'unblock owned source gate, await natural socket/watchdog exit' });
          await writeFile(`${root}/${id}.allow`, 'finally only owned server gate');
          await wait('owned runtime finishes before finally cleanup', async () => !(await job(id)).workerToken, 70000);
        }
        if (await exists(filePath(id))) {
          await db.downloadJob.update({ where: { id }, data: { ownerUntil: after(-1) } });
          await wait('owned lifecycle cleanup', async () => !(await exists(filePath(id))), bounds.cleanup);
        }
      }
    } finally {
      await db.settings.update({ where: { id: 'main' }, data: { value: saved.value as any } });
      assert.deepEqual((await db.settings.findUniqueOrThrow({ where: { id: 'main' } })).value, saved.value);
      log({ stage: 'finally', result: passed ? 'PASS' : 'FAIL', settingsDeepEqual: true, sourceSha,
        chargedBefore: String(budgetBefore), chargedAfter: String(await charged()), ownedRowsKept: owned.length, reset: false });
    }
  }
}
main().catch(e => { console.error(e instanceof Error ? e.stack : 'P3_SOCKET_FAILED'); process.exitCode = 1; }).finally(close);
