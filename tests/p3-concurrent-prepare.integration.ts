import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { after, db, filePath, limits } from '../packages/shared/src/core';
import {
  analyze, call, client, close, controlPath, events, exists, guard, job, pause, wait,
  type Client,
} from './p3-support';

const timeout = { request: 10000, state: 10000, sweeps: 8000, cleanup: 8000, case: 60000 };
const expected = Buffer.from(Array.from({ length: 262144 }, (_, i) => (i * 17 + 3) & 255));
const fixtures: { id: string; c: Client }[] = [];
const itemIds = new Map<string, string>();
let caseSignal: AbortSignal | undefined;
const originalFetch = globalThis.fetch;
// Bound every HTTP call, including imported session/analyze/heartbeat helpers.
globalThis.fetch = (input, init) => originalFetch(input, {
  ...init,
  signal: AbortSignal.any([AbortSignal.timeout(timeout.request), ...(init?.signal ? [init.signal] : []), ...(caseSignal ? [caseSignal] : [])]),
});
const log = (detail: object) => console.log(JSON.stringify({ date: new Date().toISOString(), fixtureOnly: true, ...detail }));
type Selection = { itemId: string; formatId: string; idempotencyKey: string };

async function request(c: Client, id: string, selection: Selection) {
  const start = Date.now();
  const response = await fetch(`http://api:3000/api/v1/jobs/${id}/prepare`, {
    method: 'POST', signal: AbortSignal.timeout(timeout.request),
    headers: { cookie: c.cookie, origin: 'http://localhost:5174', 'x-csrf-token': c.csrf, 'content-type': 'application/json' },
    body: JSON.stringify(selection),
  });
  const body = await response.json() as any;
  return { start, end: Date.now(), status: response.status, body };
}
async function completions(id: string) {
  const rows = await db.auditLog.findMany({ where: { actor: 'worker', action: 'worker.metrics' } });
  return rows.filter(r => (r.detail as any).id === id && (r.detail as any).phase === 'prepare' && (r.detail as any).result === 'complete').length;
}
async function finish(id: string) {
  await mkdir(`/control/${id}`, { recursive: true });
  await writeFile(controlPath(id, 'finish-allowed'), 'allow successful fixture completion');
}
async function stable(id: string, state: 'queued' | 'preparing' | 'ready', key: string, assetId?: string) {
  caseSignal?.throwIfAborted();
  const j = await job(id), markers = await events(id);
  assert.equal(j.state, state);
  assert.equal(j.prepareKey, key);
  assert.equal(j.formatId, '18');
  assert.ok(j.ownerUntil > new Date());
  assert.equal(j.releaseAt, null);
  assert.equal(j.cancelRequested, false);
  const items = await db.mediaItem.findMany({ where: { jobId: id } });
  assert.equal(items.length, 1); assert.equal(items[0].id, itemIds.get(id));
  assert.equal(markers.filter(m => m.event === 'prepare_failed').length, 0);
  assert.equal(markers.filter(m => m.event === 'prepare_invoked').length, state === 'queued' ? 0 : 1);
  assert.equal(markers.filter(m => m.event === 'prepare_started').length, state === 'queued' ? 0 : 1);
  const invocations = markers.filter(m => m.event === 'prepare_invoked');
  assert.equal(new Set(invocations.map(m => `${m.namespace}:${m.pid}:${m.startTicks}`)).size, invocations.length);
  assert.equal(await db.temporaryAsset.count({ where: { jobId: id } }), state === 'queued' ? 0 : 1);
  assert.equal(await completions(id), state === 'ready' ? 1 : 0);
  if (state === 'queued') {
    assert.equal(j.asset, null);
    assert.equal(j.workerToken, null);
  } else {
    if (assetId) assert.equal(j.asset!.id, assetId);
    assert.equal(j.asset!.path, `${id}/media.mp4`);
    assert.equal(j.asset!.state, state === 'preparing' ? 'staging' : 'available');
    if (state === 'preparing') {
      assert.ok(j.workerToken && j.processUntil && j.processUntil > new Date());
      assert.equal(await exists(filePath(`${id}/media.mp4.part`)), true);
      assert.equal(markers.filter(m => m.event === 'prepare_complete').length, 0);
    } else {
      assert.equal(j.workerToken, null);
      assert.equal(j.processUntil, null);
      assert.equal(markers.filter(m => m.event === 'prepare_complete').length, 1);
      assert.equal(j.asset!.size, BigInt(expected.length));
    }
  }
  return j;
}
async function preparing(id: string) {
  await wait('claimed prepare and real child marker', async () => {
    const j = await job(id), e = await events(id);
    return j.state === 'preparing' && e.some(m => m.event === 'prepare_started');
  }, timeout.state);
  await wait('first child heartbeat written', () => exists(controlPath(id, 'heartbeat.json')));
  const a = JSON.parse(await readFile(controlPath(id, 'heartbeat.json'), 'utf8'));
  await wait('child heartbeat advances while gate closed', async () => {
    const b = JSON.parse(await readFile(controlPath(id, 'heartbeat.json'), 'utf8'));
    assert.equal(b.pid, a.pid); assert.equal(b.startTicks, a.startTicks); assert.equal(b.namespace, a.namespace);
    return b.counter > a.counter;
  });
  const j = await job(id);
  await stable(id, 'preparing', j.prepareKey!, j.asset!.id);
  log({ stage: 'child-live', state: j.state, workerTokenPresent: true, asset: j.asset!.state, pid: a.pid, namespace: a.namespace, startTicks: a.startTicks, heartbeatAdvancing: true });
  return j;
}
async function retry(c: Client, id: string, state: 'queued' | 'preparing' | 'ready', selection: Selection, key: string, assetId?: string) {
  await stable(id, state, key, assetId);
  const r = await request(c, id, selection);
  assert.equal(r.status, 202); assert.equal(r.body.jobId, id); assert.equal(r.body.state, state);
  await stable(id, state, key, assetId);
  log({ stage: 'retry', preState: state, status: r.status, state: r.body.state, sameJob: true, stableSelectionAssetInvocation: true });
}
async function conflict(c: Client, id: string, state: 'queued' | 'preparing' | 'ready', selection: Selection, key: string, assetId?: string) {
  for (const idempotencyKey of [key, randomUUID()]) {
    await stable(id, state, key, assetId);
    const r = await request(c, id, { ...selection, idempotencyKey, formatId: '22' });
    assert.equal(r.status, 409); assert.equal(r.body.error.code, 'IDEMPOTENCY_CONFLICT');
    await stable(id, state, key, assetId);
    log({ stage: 'conflict', preState: state, status: 409, code: r.body.error.code, sameKey: idempotencyKey === key, unchanged: true });
  }
}
async function sweepEvidence(id: string, key: string, assetId: string, sessionId: string, c: Client, interval: number) {
  const started = Date.now();
  // A second sentinel is created ONLY after the first was deleted. sweep() captures
  // its job list once: these two deletions cannot belong to the same iteration.
  for (let cycle = 1; cycle <= 2; cycle++) {
    await stable(id, 'ready', key, assetId);
    const sentinel = await db.downloadJob.create({ data: { sessionId, platform: 'youtube', state: 'ready', ownerUntil: after(60) } });
    fixtures.push({ id: sentinel.id, c });
    await mkdir(filePath(sentinel.id));
    await writeFile(filePath(`${sentinel.id}/media.mp4`), 'expired sweep sentinel');
    const sentinelAsset = await db.temporaryAsset.create({ data: { jobId: sentinel.id, path: `${sentinel.id}/media.mp4`, state: 'available', readyUntil: after(60) } });
    assert.equal((await job(sentinel.id)).state, 'ready');
    await db.temporaryAsset.update({ where: { id: sentinelAsset.id }, data: { readyUntil: after(-1) } });
    const created = Date.now();
    await wait('real background sweep deletes fresh expired sentinel', async () => {
      await stable(id, 'ready', key, assetId);
      const s = await job(sentinel.id);
      if (s.asset?.state !== 'deleted') return false;
      assert.equal(s.state, 'expired'); assert.equal(s.workerToken, null);
      assert.equal(await exists(filePath(sentinel.id)), false);
      return true;
    }, timeout.sweeps);
    log({ stage: 'real-sweep-observed', cycle, intervalMs: interval * 1000, created: new Date(created).toISOString(), deleted: new Date().toISOString(), elapsedMs: Date.now() - created, sentinelState: 'expired/deleted', targetState: 'ready', invocations: 1, completion: 1 });
  }
  while (Date.now() - started < interval * 2000) { await stable(id, 'ready', key, assetId); await pause(50); }
  log({ stage: 'sweep-observation-complete', distinctCycles: 2, elapsedMs: Date.now() - started, intervalMs: interval * 1000 });
}
async function download(c: Client, id: string, key: string, assetId: string) {
  await stable(id, 'ready', key, assetId);
  const ticket = await call(c, `jobs/${id}/download-ticket`), url = 'http://api:3000' + ticket.url;
  const headers = { cookie: c.cookie };
  const full = await fetch(url, { headers, signal: AbortSignal.timeout(timeout.request) });
  assert.equal(full.status, 200); assert.equal(Number(full.headers.get('content-length')), expected.length);
  const bytes = Buffer.from(await full.arrayBuffer()); assert.deepEqual(bytes, expected);
  const deadline = (await job(id)).asset!.transferDeadline!.getTime();
  for (const [range, start, end] of [['bytes=0-99', 0, 100], ['bytes=-100', expected.length - 100, expected.length]] as const) {
    const r = await fetch(url, { headers: { ...headers, range }, signal: AbortSignal.timeout(timeout.request) });
    assert.equal(r.status, 206);
    assert.equal(r.headers.get('content-range'), `bytes ${start}-${end - 1}/${expected.length}`);
    assert.deepEqual(Buffer.from(await r.arrayBuffer()), expected.subarray(start, end));
  }
  await wait('full and Range server finalized', async () => {
    const rows = await db.transferLease.findMany({ where: { assetId } });
    return rows.length === 3 && rows.every(r => r.state === 'server_finished' && r.endedAt && r.bytes === r.reserved);
  });
  await stable(id, 'ready', key, assetId);
  assert.equal((await job(id)).asset!.transferDeadline!.getTime(), deadline);
  log({ stage: 'download', full: 200, fullBytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), range: 206, rangeBytes: 200, sameTicket: true, leasesFinished: 3, sharedDeadlineUnchanged: true });
  const grace = (await job(id)).asset!.retryUntil!.getTime();
  await wait('natural grace cleanup', async () => {
    const j = await job(id);
    if (Date.now() < grace - 100) assert.equal(j.asset!.state, 'available');
    if (j.asset!.state !== 'deleted') return false;
    assert.ok(Date.now() >= grace); assert.equal(j.state, 'expired'); assert.equal(j.workerToken, null);
    return !(await exists(filePath(id)));
  }, timeout.cleanup);
  assert.equal((await events(id)).filter(m => m.event === 'prepare_invoked').length, 1);
  assert.equal(await completions(id), 1);
  log({ stage: 'cleanup', state: 'expired', asset: 'deleted', grace: new Date(grace).toISOString(), cleanupDelayMs: Date.now() - grace, invocations: 1, completion: 1 });
}

async function run(mode: 'same-key' | 'different-key') {
  caseSignal = AbortSignal.timeout(timeout.case);
  const started = Date.now(), c = await client(), blockerClient = await client();
  const selected = await analyze(c, mode === 'same-key' ? 'cpsame00001' : 'cpdiff00001');
  fixtures.push({ id: selected.id, c });
  itemIds.set(selected.id, selected.selection.itemId);
  const blocker = await analyze(blockerClient, 'cpblock0001');
  fixtures.push({ id: blocker.id, c: blockerClient });
  itemIds.set(blocker.id, blocker.selection.itemId);
  let heartbeatError: unknown, pending = Promise.resolve(), blockerOwned = true, targetOwned = true;
  const beat = async () => {
    for (const f of [...(targetOwned ? [{ id: selected.id, c }] : []), ...(blockerOwned ? [{ id: blocker.id, c: blockerClient }] : [])]) {
      if (['selectable', 'queued', 'preparing', 'ready'].includes((await job(f.id)).state)) await call(f.c, `jobs/${f.id}/heartbeat`);
    }
  };
  const timer = setInterval(() => { pending = pending.then(beat).catch(e => { heartbeatError = e; }); }, 1000);
  try {
    await beat();
    await call(blockerClient, `jobs/${blocker.id}/prepare`, blocker.selection);
    await preparing(blocker.id);
    assert.equal((await job(selected.id)).state, 'selectable');
    assert.equal((await events(selected.id)).length, 0);
    assert.equal(await db.temporaryAsset.count({ where: { jobId: selected.id } }), 0);
    const selections = [selected.selection, { ...selected.selection, idempotencyKey: mode === 'same-key' ? selected.selection.idempotencyKey : randomUUID() }];
    let open!: () => void;
    const barrier = new Promise<void>(resolve => { open = resolve; });
    const waiting = selections.map(async s => { await barrier; return request(c, selected.id, s); });
    log({ test: mode, stage: 'pre-concurrent', state: 'selectable', workerOccupied: 'preparing', assetCount: 0, invocations: 0, timeout });
    open();
    const responses = await Promise.all(waiting);
    assert.ok(Math.max(...responses.map(r => r.start)) < Math.min(...responses.map(r => r.end)), 'Both client request intervals must overlap');
    for (const r of responses) { assert.equal(r.status, 202); assert.equal(r.body.jobId, selected.id); assert.equal(r.body.state, 'queued'); }
    const queued = await job(selected.id), key = queued.prepareKey!;
    assert.ok(selections.some(s => s.idempotencyKey === key));
    await stable(selected.id, 'queued', key);
    log({ test: mode, stage: 'concurrent-responses', requests: responses.map(r => ({ start: new Date(r.start).toISOString(), end: new Date(r.end).toISOString(), status: r.status, state: r.body.state })), overlapMs: Math.min(...responses.map(r => r.end)) - Math.max(...responses.map(r => r.start)), sameJob: true });
    for (const s of selections) await retry(c, selected.id, 'queued', s, key);
    await conflict(c, selected.id, 'queued', selections[0], key);
    await finish(blocker.id);
    await wait('blocker completes normally', async () => (await job(blocker.id)).state === 'ready');
    blockerOwned = false; await pending;
    await call(blockerClient, `jobs/${blocker.id}/release`);
    const claimed = await preparing(selected.id), assetId = claimed.asset!.id;
    for (const s of selections) await retry(c, selected.id, 'preparing', s, key, assetId);
    await conflict(c, selected.id, 'preparing', selections[0], key, assetId);
    await finish(selected.id);
    await wait('target ready and completion audit committed', async () => (await job(selected.id)).state === 'ready' && await completions(selected.id) === 1);
    for (const s of selections) await retry(c, selected.id, 'ready', s, key, assetId);
    await conflict(c, selected.id, 'ready', selections[0], key, assetId);
    await sweepEvidence(selected.id, key, assetId, claimed.sessionId, c, (await limits()).sweepSeconds);
    targetOwned = false; clearInterval(timer); await pending;
    if (heartbeatError) throw heartbeatError;
    log({ stage: 'heartbeat-stopped-before-transfer-cleanup', ownerStillValid: (await job(selected.id)).ownerUntil > new Date() });
    await download(c, selected.id, key, assetId);
    await wait('blocker cleaned through release grace', async () => (await job(blocker.id)).asset?.state === 'deleted' && !(await exists(filePath(blocker.id))));
    assert.equal((await events(blocker.id)).filter(m => m.event === 'prepare_invoked').length, 1);
    assert.equal(await completions(blocker.id), 1);
    assert.ok(Date.now() - started < timeout.case);
    if (heartbeatError) throw heartbeatError;
    log({ test: mode, result: 'PASS', elapsedMs: Date.now() - started, assetCount: 1, invocationCount: 1, completionCount: 1, retries: ['queued', 'preparing', 'ready'], conflicts: 6, settingsChanged: false });
  } finally {
    clearInterval(timer); await pending; caseSignal = undefined;
  }
}
async function main() {
  await guard();
  const savedSettings = await db.settings.findUnique({ where: { id: 'main' } });
  assert.equal((await limits()).sweepSeconds, 1);
  assert.equal(await db.downloadJob.count({ where: { state: { in: ['analyzing', 'queued', 'preparing'] } } }), 0, 'Test harness must be idle');
  log({ stage: 'guard', project: process.env.P3_TEST_GUARD, database: 'wed_snap_p3_test', redisDb: 14, media: '/media', node: process.version, sweepSeconds: 1 });
  try { await run('same-key'); await run('different-key'); }
  finally {
    caseSignal = undefined;
    // On failure release only this run's fixtures; never delete/reset DB or media directly.
    for (const f of fixtures) {
      if (!['expired', 'cancelled', 'failed'].includes((await job(f.id)).state)) {
        await call(f.c, `jobs/${f.id}/release`);
        await finish(f.id);
      }
      await wait('finally lifecycle cleanup', async () => {
        const j = await job(f.id);
        return !j.workerToken && (!j.asset || j.asset.state === 'deleted') && !(await exists(filePath(f.id)));
      }, timeout.cleanup);
    }
    assert.deepEqual((await db.settings.findUnique({ where: { id: 'main' } }))?.value ?? null, savedSettings?.value ?? null);
    log({ stage: 'finally', fixturesCleaned: fixtures.length, settingsChanged: false, dataReset: false });
  }
}
main().catch(e => { console.error(e instanceof Error ? e.stack : 'CONCURRENT_PREPARE_FAILED'); process.exitCode = 1; }).finally(close);
