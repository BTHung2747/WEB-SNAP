import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { access, readFile, readlink, mkdir, writeFile } from 'node:fs/promises';
import { db, redis, queue, filePath } from '../packages/shared/src/core';

export const pause = (ms: number) => new Promise<void>(resolve => setTimeout(resolve, ms));
export type Client = { cookie: string; csrf: string };
export type Marker = { event: string; at: number; pid: number; startTicks: string; namespace: string; partialExists?: boolean };
export const controlPath = (id: string, name: string) => `/control/${id}/${name}`;
export async function guard() {
  assert.equal(process.env.P3_TEST_GUARD, 'wed-snap-p3-test');
  assert.equal(process.env.APP_ORIGIN, 'http://localhost:5174');
  const [database] = await db.$queryRaw<{ name: string }[]>`SELECT current_database() AS name`;
  assert.equal(database.name, 'wed_snap_p3_test');
  assert.equal(redis.options.db, 14);
}
export async function exists(path: string) {
  try { await access(path); return true; } catch { return false; }
}
export async function wait(name: string, check: () => Promise<boolean>, ms = 10000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await check()) return; await pause(50); }
  throw new Error(`P3 timeout: ${name}`);
}
export async function call(client: Client, path: string, body?: unknown, method = 'POST') {
  const r = await fetch('http://api:3000/api/v1/' + path, {
    method, headers: { cookie: client.cookie, origin: 'http://localhost:5174', 'x-csrf-token': client.csrf, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const result = await r.json() as any;
  assert.ok(r.ok, `Local HTTP failed: ${r.status} ${result.error?.code || ''}`);
  return result;
}
export async function client(): Promise<Client> {
  const r = await fetch('http://api:3000/api/v1/session');
  assert.equal(r.status, 200);
  const body = await r.json() as any;
  return { cookie: r.headers.get('set-cookie')!.split(';')[0], csrf: body.csrf };
}
export async function analyze(c: Client, source: string) {
  const { jobId } = await call(c, 'jobs/analyze', { url: `https://youtu.be/${source}` });
  await wait('analyze selectable', async () => (await job(jobId)).state === 'selectable');
  const result = await call(c, `jobs/${jobId}`, undefined, 'GET');
  assert.equal(result.state, 'selectable');
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].formats[0].id, '18');
  assert.equal((await events(jobId)).length, 0, 'Analyze must not enter the prepare barrier');
  return { id: jobId as string, selection: { itemId: result.items[0].id, formatId: '18', idempotencyKey: randomUUID() } };
}
export function job(id: string) { return db.downloadJob.findUniqueOrThrow({ where: { id }, include: { asset: true } }); }
export async function events(id: string): Promise<Marker[]> {
  try { return (await readFile(controlPath(id, 'events.jsonl'), 'utf8')).trim().split('\n').filter(Boolean).map(line => JSON.parse(line)); }
  catch (e: any) { if (e.code === 'ENOENT') return []; throw e; }
}
export async function live(marker: Marker) {
  if (await readlink('/proc/self/ns/pid') !== marker.namespace) return false;
  try {
    const parts = (await readFile(`/proc/${marker.pid}/stat`, 'utf8')).split(') ')[1].split(' ');
    const command = await readFile(`/proc/${marker.pid}/cmdline`, 'utf8');
    return !['Z', 'X'].includes(parts[0]) && parts[19] === marker.startTicks && command.includes('/app/infra/media_adapter.py');
  } catch (e: any) { if (e.code === 'ENOENT' || e.code === 'ESRCH') return false; throw e; }
}
export async function preparing(id: string) {
  await wait('preparing child and partial', async () => {
    const j = await job(id);
    const e = (await events(id)).filter(e => e.event === 'prepare_started');
    return j.state === 'preparing' && !!j.workerToken && j.asset?.state === 'staging' && e.length === 1 && await exists(filePath(`${id}/media.mp4.part`)) && await live(e[0]);
  });
  const j = await job(id), marker = (await events(id))[0];
  assert.equal(j.state, 'preparing');
  assert.ok(j.workerToken && j.processUntil && j.processUntil > new Date());
  assert.equal(await live(marker), true);
  assert.equal(await exists(filePath(`${id}/media.mp4.part`)), true);
  return { j, marker };
}
export async function allowExit(id: string) {
  await mkdir(`/control/${id}`, { recursive: true });
  await writeFile(controlPath(id, 'exit-allowed'), 'release fixture signal handler');
}
export async function noPublish(id: string) {
  const j = await job(id);
  assert.notEqual(j.state, 'ready');
  assert.notEqual(j.asset?.state, 'available');
  const metrics = await db.auditLog.findMany({ where: { actor: 'worker', action: 'worker.metrics' } });
  assert.equal(metrics.filter(row => (row.detail as any).id === id && (row.detail as any).phase === 'prepare' && (row.detail as any).result === 'complete').length, 0);
}
export async function close() { await queue.close(); redis.disconnect(); await db.$disconnect(); }
