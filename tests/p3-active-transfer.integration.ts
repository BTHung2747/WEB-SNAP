import assert from 'node:assert/strict';
import http from 'node:http';
import { createHash } from 'node:crypto';
import { mkdir, open } from 'node:fs/promises';
import {
  after,
  db,
  defaults,
  filePath,
  hash,
  limitsSchema,
  secret,
} from '../packages/shared/src/core';
import { call, close, exists, guard, job, pause, wait } from './p3-support';

const size = 32 * 1024 * 1024;
const month = new Date().toISOString().slice(0, 7);
const timeout = { renew: 22000, receive: 8000, finalize: 3000, cleanup: 8000 };
const block = Buffer.alloc(1024 * 1024);
for (let i = 0; i < block.length; i++) block[i] = (i * 31 + 7) & 255;
const expectedHash = createHash('sha256');
for (let i = 0; i < 32; i++) expectedHash.update(block);
const expectedDigest = expectedHash.digest('hex');
const log = (detail: object) =>
  console.log(JSON.stringify({ date: new Date().toISOString(), fixtureOnly: true, ...detail }));

async function seed() {
  const token = secret(),
    csrf = secret(),
    ticket = secret();
  const session = await db.session.create({
    data: { id: hash(token), csrf, expiresAt: after(3600) },
  });
  const j = await db.downloadJob.create({
    data: { sessionId: session.id, platform: 'youtube', state: 'ready', ownerUntil: after(5) },
  });
  await mkdir(filePath(j.id));
  const handle = await open(filePath(`${j.id}/media.mp4`), 'w');
  try {
    for (let i = 0; i < 32; i++) await handle.writeFile(block);
  } finally {
    await handle.close();
  }
  const asset = await db.temporaryAsset.create({
    data: {
      jobId: j.id,
      state: 'available',
      path: `${j.id}/media.mp4`,
      size: BigInt(size),
      readyUntil: after(5),
    },
  });
  await db.downloadTicket.create({
    data: { id: hash(ticket), jobId: j.id, expiresAt: after(120) },
  });
  return {
    id: j.id,
    assetId: asset.id,
    client: { cookie: `ws_session=${token}`, csrf },
    url: `http://api:3000/api/v1/downloads/${ticket}`,
  };
}
type Fixture = Awaited<ReturnType<typeof seed>>;

class HeldTransfer {
  response!: http.IncomingMessage;
  closed = false;
  ended = false;
  bytes = 0;
  digest = '';
  private hashing = createHash('sha256');
  private request!: http.ClientRequest;
  readonly done: Promise<void>;
  private receivedHeaders!: () => void;
  private rejectHeaders!: (error: Error) => void;
  readonly headers = new Promise<void>((resolve, reject) => {
    this.receivedHeaders = resolve;
    this.rejectHeaders = reject;
  });
  constructor(f: Fixture) {
    this.done = new Promise<void>((resolve, reject) => {
      this.request = http.get(f.url, { headers: { cookie: f.client.cookie } }, (response) => {
        this.response = response;
        response.on('data', (chunk: Buffer) => {
          this.bytes += chunk.length;
          this.hashing.update(chunk);
        });
        response.pause();
        response.on('end', () => {
          this.ended = true;
          this.digest = this.hashing.digest('hex');
          resolve();
        });
        response.on('error', reject);
        response.on('close', () => {
          this.closed = true;
          if (!this.ended) reject(new Error('Held stream closed before full body'));
        });
        this.receivedHeaders();
      });
      this.request.on('error', (e) => {
        this.rejectHeaders(e);
        reject(e);
      });
      const timer = setTimeout(() => {
        this.destroy();
        reject(new Error('Held transfer exceeded 45s'));
      }, 45000);
      this.request.once('close', () => clearTimeout(timer));
    });
    // Attach handlers while deliberately paused, so remote failures cannot be unhandled.
    void this.done.catch(() => {});
    void this.headers.catch(() => {});
  }
  assertOpen() {
    assert.equal(this.closed, false);
    assert.equal(this.ended, false);
    assert.equal(this.response.destroyed, false);
    assert.equal(this.response.readableEnded, false);
    assert.ok(this.bytes < size);
  }
  destroy() {
    this.response?.destroy();
    this.request.destroy();
  }
  async finish() {
    this.assertOpen();
    this.response.resume();
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        this.done,
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error('Full byte receive timeout')), timeout.receive);
        }),
      ]);
    } finally {
      if (timer) clearTimeout(timer);
    }
    assert.equal(this.bytes, size);
    assert.equal(this.digest, expectedDigest);
  }
}

async function budget() {
  return (await db.egressBudget.findUniqueOrThrow({ where: { month } })).charged;
}
async function active(f: Fixture, stream: HeldTransfer, leaseId: string, deadline: number) {
  stream.assertOpen();
  const [j, lease] = await Promise.all([
    job(f.id),
    db.transferLease.findUniqueOrThrow({ where: { id: leaseId } }),
  ]);
  assert.equal(j.state, 'ready');
  assert.equal(j.cancelRequested, false);
  assert.equal(j.releaseAt, null);
  assert.equal(j.asset?.state, 'available');
  assert.equal(j.asset.transferDeadline?.getTime(), deadline);
  assert.equal(j.asset.retryUntil, null);
  assert.equal(lease.state, 'started');
  assert.equal(lease.endedAt, null);
  assert.ok(lease.expiresAt > new Date());
  assert.equal(await exists(filePath(f.id)), true);
  return { j, lease };
}

async function range(f: Fixture, start: number) {
  const response = await fetch(f.url, {
    headers: { cookie: f.client.cookie, Range: `bytes=${start}-${start + 99}` },
  });
  assert.equal(response.status, 206);
  assert.equal(response.headers.get('content-range'), `bytes ${start}-${start + 99}/${size}`);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), block.subarray(start, start + 100));
}

async function finalized(f: Fixture, count: number) {
  await wait(
    'all admitted leases server_finished with exact bytes',
    async () => {
      const rows = await db.transferLease.findMany({ where: { assetId: f.assetId } });
      if (rows.length !== count || rows.some((r) => r.state === 'started')) return false;
      assert.ok(
        rows.every((r) => r.state === 'server_finished' && r.endedAt && r.bytes === r.reserved),
      );
      assert.equal(rows.filter((r) => r.reserved === BigInt(size)).length, 1);
      return true;
    },
    timeout.finalize,
  );
}

async function cleanup(f: Fixture, deadline: number, count: number) {
  await finalized(f, count);
  const a = (await job(f.id)).asset!;
  assert.equal(a.state, 'available');
  assert.equal(a.transferDeadline?.getTime(), deadline);
  assert.ok(a.retryUntil && a.retryUntil.getTime() > Date.now());
  const rows = await db.transferLease.findMany({ where: { assetId: f.assetId } });
  const lastEnded = Math.max(...rows.map((r) => r.endedAt!.getTime()));
  assert.ok(a.retryUntil.getTime() >= lastEnded + 4500, '5s grace starts after the final request');
  const retryDeadline = a.retryUntil.getTime();
  await wait(
    'cleanup after final request grace',
    async () => {
      const j = await job(f.id);
      if (Date.now() < retryDeadline - 100)
        assert.equal(j.asset?.state, 'available', 'No early grace cleanup');
      if (j.asset?.state !== 'deleted') return false;
      assert.ok(Date.now() >= retryDeadline);
      assert.equal(j.state, 'expired');
      assert.equal(j.workerToken, null);
      return !(await exists(filePath(f.id)));
    },
    timeout.cleanup,
  );
  assert.ok(Date.now() <= retryDeadline + 3000, 'Sweep cleanup bounded by grace deadline + 3s');
  const rejected = await fetch(f.url, {
    headers: { cookie: f.client.cookie, Range: 'bytes=0-99' },
  });
  assert.equal(rejected.status, 410);
  await rejected.arrayBuffer();
  assert.equal(await db.transferLease.count({ where: { assetId: f.assetId } }), count);
  return { cleanupAfterGraceMs: Date.now() - retryDeadline, graceMs: retryDeadline - lastEnded };
}

async function run(mode: 'heartbeat' | 'budget') {
  await guard();
  await wait(
    'test DB has no other started transfer',
    async () => (await db.transferLease.count({ where: { state: 'started' } })) === 0,
    5000,
  );
  const saved = await db.settings.findUnique({ where: { id: 'main' } });
  await db.egressBudget.upsert({ where: { month }, create: { month }, update: {} });
  const baseCharge = await budget();
  const settings = limitsSchema.parse({
    ...((saved?.value as object) || defaults),
    sessionTtl: 5,
    readyTtl: 5,
    leaseTtl: 30,
    retryGrace: 5,
    transferMax: 60,
    monthlyBytes: Number(baseCharge) + size * 4,
  });
  let held: HeldTransfer | undefined;
  let ticker: NodeJS.Timeout | undefined;
  let pendingBeat = Promise.resolve();
  let beats = 0;
  let heartbeatError: unknown;
  const started = Date.now();
  try {
    await db.settings.upsert({
      where: { id: 'main' },
      create: { value: settings },
      update: { value: settings },
    });
    const f = await seed();
    if (mode === 'heartbeat') {
      const beat = async () => {
        await call(f.client, `jobs/${f.id}/heartbeat`);
        beats++;
      };
      await beat();
      ticker = setInterval(() => {
        pendingBeat = pendingBeat.then(beat).catch((e) => {
          heartbeatError = e;
        });
      }, 1000);
    }
    held = new HeldTransfer(f);
    await held.headers;
    assert.equal(held.response.statusCode, 200);
    assert.equal(Number(held.response.headers['content-length']), size);
    const lease = await db.transferLease.findFirstOrThrow({ where: { assetId: f.assetId } });
    assert.equal(lease.reserved, BigInt(size));
    const deadline = (await job(f.id)).asset!.transferDeadline!.getTime();
    const pre = await active(f, held, lease.id, deadline);
    assert.ok(pre.j.ownerUntil > new Date());
    assert.equal(await budget(), baseCharge + BigInt(size));
    log({
      test: mode,
      stage: 'pre-trigger',
      state: pre.j.state,
      asset: pre.j.asset!.state,
      lease: pre.lease.state,
      streamClosed: held.closed,
      ownerUntil: pre.j.ownerUntil.toISOString(),
      leaseUntil: lease.expiresAt.toISOString(),
      deadline: new Date(deadline).toISOString(),
      reserved: String(lease.reserved),
      receivedBytes: held.bytes,
      charged: String(await budget()),
      timeout,
    });
    if (ticker) clearInterval(ticker);
    await pendingBeat;
    if (heartbeatError) throw heartbeatError;
    const stoppedOwner = (await job(f.id)).ownerUntil.getTime();
    const stoppedBeats = beats;
    if (mode === 'budget') {
      const beforeCount = await db.transferLease.count({ where: { assetId: f.assetId } });
      const beforeReserved = (
        await db.transferLease.aggregate({
          where: { assetId: f.assetId },
          _sum: { reserved: true },
        })
      )._sum.reserved;
      const beforeCharge = await budget();
      await active(f, held, lease.id, deadline);
      await db.settings.update({
        where: { id: 'main' },
        data: { value: { ...settings, monthlyBytes: 0 } },
      });
      const rejected = await fetch(f.url, {
        headers: { cookie: f.client.cookie, Range: 'bytes=0-99' },
      });
      const error = (await rejected.json()) as any;
      assert.equal(rejected.status, 503);
      assert.equal(error.error.code, 'CAPACITY_UNAVAILABLE');
      assert.equal(await db.transferLease.count({ where: { assetId: f.assetId } }), beforeCount);
      assert.equal(
        (
          await db.transferLease.aggregate({
            where: { assetId: f.assetId },
            _sum: { reserved: true },
          })
        )._sum.reserved,
        beforeReserved,
      );
      assert.equal(await budget(), beforeCharge);
      await active(f, held, lease.id, deadline);
      log({
        test: mode,
        stage: 'new-request-rejected',
        monthlyBytes: 0,
        status: 503,
        code: error.error.code,
        leaseCount: beforeCount,
        reservationUnchanged: true,
        chargedUnchanged: true,
        existingStreamOpen: true,
      });
    }
    let renewedBytes = 0,
      renewedUntil = '';
    await wait(
      'owner expired and server renew while stream remains active',
      async () => {
        const current = await active(f, held!, lease.id, deadline);
        assert.equal(current.j.ownerUntil.getTime(), stoppedOwner);
        assert.equal(beats, stoppedBeats);
        if (
          Date.now() <= stoppedOwner ||
          current.lease.expiresAt.getTime() <= lease.expiresAt.getTime() + 1000
        )
          return false;
        assert.ok(
          current.lease.bytes > 0n && current.lease.bytes < current.lease.reserved,
          'Renew captures genuine server backpressure',
        );
        renewedBytes = Number(current.lease.bytes);
        renewedUntil = current.lease.expiresAt.toISOString();
        return true;
      },
      timeout.renew,
    );
    log({
      test: mode,
      stage: 'renewed-after-owner-expiry',
      heartbeatCalls: beats,
      releaseCalls: 0,
      cancelCalls: 0,
      ownerExpired: true,
      serverRenewed: true,
      leaseUntil: renewedUntil,
      serverBytesWhilePaused: renewedBytes,
      streamClosed: held.closed,
      asset: 'available',
    });
    let requests = 1;
    if (mode === 'heartbeat') {
      await range(f, 0);
      requests++;
      await wait(
        'active Range finalized while full lease still started',
        async () =>
          (await db.transferLease.count({
            where: { assetId: f.assetId, state: 'server_finished' },
          })) === 1,
        timeout.finalize,
      );
      await active(f, held, lease.id, deadline);
    }
    await held.finish();
    await finalized(f, requests);
    assert.equal(await budget(), baseCharge + BigInt(size + (requests - 1) * 100));
    assert.equal(
      await db.transferLease.count({ where: { assetId: f.assetId, state: 'started' } }),
      0,
    );
    if (mode === 'heartbeat') {
      await range(f, 100);
      requests++;
      await finalized(f, requests);
      assert.equal(
        (await job(f.id)).asset!.transferDeadline!.getTime(),
        deadline,
        'Range never extends shared absolute deadline',
      );
      assert.equal(await budget(), baseCharge + BigInt(size + 200));
    }
    const cleaned = await cleanup(f, deadline, requests);
    log({
      test: mode,
      result: 'PASS',
      elapsedMs: Date.now() - started,
      fullBytes: held.bytes,
      sha256: held.digest,
      serverFinishedLeases: requests,
      chargedDelta: String((await budget()) - baseCharge),
      sharedDeadlineUnchanged: true,
      ...cleaned,
    });
  } finally {
    if (ticker) clearInterval(ticker);
    await pendingBeat;
    held?.destroy();
    await held?.done.catch(() => {});
    if (saved) await db.settings.update({ where: { id: 'main' }, data: { value: saved.value! } });
    else await db.settings.deleteMany({ where: { id: 'main' } });
    const restored = await db.settings.findUnique({ where: { id: 'main' } });
    assert.deepEqual(restored?.value ?? null, saved?.value ?? null);
    log({ test: mode, stage: 'finally-settings-restored', exactOriginal: true });
  }
}
async function main() {
  await run('heartbeat');
  await run('budget');
}
main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : 'ACTIVE_TRANSFER_FAILED');
    process.exitCode = 1;
  })
  .finally(close);
