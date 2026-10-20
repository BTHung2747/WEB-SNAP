import { Prisma, PrismaClient } from '@prisma/client';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import { z } from 'zod';

export const db = new PrismaClient();
export const redis = new IORedis(process.env.REDIS_URL || 'redis://redis:6379', {
  maxRetriesPerRequest: null,
});
export const queue = new Queue('media', { connection: redis as any });
export const mediaRoot = process.env.MEDIA_ROOT || '/media';
export const origin = process.env.APP_ORIGIN || 'http://localhost:5173';
export const verified = (process.env.VERIFIED_PLATFORMS || '').split(',').filter(Boolean);
export const limitsSchema = z
  .object({
    maxDuration: z.number().int().min(1).max(600),
    maxBytes: z.number().int().min(1024).max(209715200),
    maxInputBytes: z.number().int().min(1024).max(262144000),
    analyzeTimeout: z.number().int().min(5).max(30),
    prepareTimeout: z.number().int().min(10).max(180),
    sessionTtl: z.number().int().min(5).max(3600),
    releaseGrace: z.number().int().min(1).max(120),
    readyTtl: z.number().int().min(5).max(600),
    sweepSeconds: z.number().int().min(1).max(30),
    leaseTtl: z.number().int().min(30).max(90),
    retryGrace: z.number().int().min(1).max(120),
    transferMax: z.number().int().min(5).max(1800),
    monthlyBytes: z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),
    diskStopPercent: z.number().int().min(10).max(80),
    queueLimit: z.number().int().min(1).max(20),
    acceptJobs: z.boolean(),
    enabledPlatforms: z.array(z.enum(['youtube', 'tiktok', 'facebook', 'x'])).max(4),
  })
  .strict();
export type Limits = z.infer<typeof limitsSchema>;
const num = (name: string, fallback: number) => Number(process.env[name] || fallback);
export const defaults: Limits = limitsSchema.parse({
  maxDuration: num('MAX_DURATION_SECONDS', 600),
  maxBytes: num('MAX_BYTES', 209715200),
  maxInputBytes: num('MAX_INPUT_BYTES', 262144000),
  analyzeTimeout: num('ANALYZE_TIMEOUT_SECONDS', 30),
  prepareTimeout: num('PREPARE_TIMEOUT_SECONDS', 180),
  sessionTtl: num('SESSION_TTL_SECONDS', 120),
  releaseGrace: num('RELEASE_GRACE_SECONDS', 30),
  readyTtl: num('READY_TTL_SECONDS', 600),
  sweepSeconds: num('SWEEP_SECONDS', 30),
  leaseTtl: num('LEASE_TTL_SECONDS', 90),
  retryGrace: num('RETRY_GRACE_SECONDS', 120),
  transferMax: num('TRANSFER_MAX_SECONDS', 1800),
  monthlyBytes: num('MONTHLY_EGRESS_BYTES', 10737418240),
  diskStopPercent: num('DISK_STOP_PERCENT', 80),
  queueLimit: num('QUEUE_LIMIT', 20),
  acceptJobs: true,
  enabledPlatforms: verified.filter((p) => ['youtube', 'tiktok', 'facebook', 'x'].includes(p)),
});
export async function limits(): Promise<Limits> {
  const s = await db.settings.findUnique({ where: { id: 'main' } });
  const value = s ? limitsSchema.parse(s.value) : defaults;
  return { ...value, enabledPlatforms: value.enabledPlatforms.filter((p) => verified.includes(p)) };
}
export class AppError extends Error {
  constructor(
    public code: string,
    public status = 400,
  ) {
    super(code);
  }
}
export function fail(code: string, status = 400): never {
  throw new AppError(code, status);
}
export const secret = () => randomBytes(32).toString('hex');
export const hash = (s: string) => createHash('sha256').update(s).digest('hex');
export const after = (seconds: number, now = new Date()) =>
  new Date(now.getTime() + seconds * 1000);
export const terminal = ['failed', 'cancelled', 'expired'];
export const metadataMaxAgeMs = 120000;
/** Only an adapter's explicit trusted absolute Unix-ms expiry is accepted. */
export function metadataDeadline(acceptedAt: Date, sourceExpiresAt?: unknown): Date {
  let deadline = acceptedAt.getTime() + metadataMaxAgeMs;
  if (sourceExpiresAt !== undefined && sourceExpiresAt !== null) {
    if (typeof sourceExpiresAt !== 'number' || !Number.isSafeInteger(sourceExpiresAt))
      fail('CONTENT_UNAVAILABLE');
    deadline = Math.min(deadline, sourceExpiresAt);
  }
  return new Date(deadline);
}
type MetadataJob = {
  id: string; state: string; prepareKey: string | null;
  metadataAcceptedAt: Date | null; metadataExpiresAt: Date | null;
};
export function metadataExpired(j: MetadataJob, now = new Date()): boolean {
  if (j.state !== 'selectable' || j.prepareKey) return false;
  // NULL legacy stamps are unusable; updatedAt/ownership are never a fallback.
  return !j.metadataAcceptedAt || !j.metadataExpiresAt ||
    now.getTime() >= Math.min(j.metadataExpiresAt.getTime(), j.metadataAcceptedAt.getTime() + metadataMaxAgeMs);
}
export function expiredMetadataJob(j: MetadataJob): boolean {
  return j.state === 'expired' && !j.prepareKey;
}
/** Caller holds lockJob. Return an expiry result, then throw AFTER commit. */
export async function expireSelectableMetadata(tx: Prisma.TransactionClient, j: MetadataJob, now = new Date()) {
  if (!metadataExpired(j, now)) return false;
  await tx.mediaItem.deleteMany({ where: { jobId: j.id } });
  await tx.downloadJob.update({ where: { id: j.id }, data: {
    state: 'expired', errorCode: 'JOB_EXPIRED', sourceUrl: null, releaseAt: now,
  } });
  // Cancellation and cleanup completion are independent. The sweeper retries
  // terminal rows while cleanupCompletedAt is null, including expired metadata.
  return true;
}
export function ownerExpired(
  j: { ownerUntil: Date; releaseAt: Date | null },
  now = new Date(),
): boolean {
  return j.ownerUntil <= now || !!(j.releaseAt && j.releaseAt <= now);
}
export function assetExpired(
  a: { readyUntil: Date | null; transferDeadline: Date | null; retryUntil: Date | null },
  ownerDead: boolean,
  now = new Date(),
): boolean {
  if (a.transferDeadline)
    return a.transferDeadline <= now || !!(a.retryUntil && a.retryUntil <= now);
  return ownerDead || !a.readyUntil || a.readyUntil <= now;
}
export function filePath(relative: string) {
  const target = path.resolve(mediaRoot, relative);
  if (!target.startsWith(path.resolve(mediaRoot) + path.sep)) fail('INVALID_ASSET_PATH', 500);
  return target;
}
export function validateUrl(value: unknown): { url: string; platform: string } {
  if (typeof value !== 'string' || value.length > 2048) fail('INVALID_URL');
  let u: URL;
  try {
    u = new URL(value);
  } catch {
    return fail('INVALID_URL');
  }
  if (u.protocol !== 'https:' || u.username || u.password || u.port || u.hash) fail('INVALID_URL');
  const h = u.hostname.toLowerCase();
  const groups: Record<string, string[]> = {
    youtube: ['youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be'],
    tiktok: ['tiktok.com', 'www.tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com'],
    facebook: ['facebook.com', 'www.facebook.com', 'm.facebook.com', 'fb.watch'],
    x: ['x.com', 'www.x.com', 'twitter.com', 'www.twitter.com'],
  };
  const platform = Object.keys(groups).find((p) => groups[p].includes(h));
  if (!platform) fail('UNSUPPORTED_PLATFORM');
  if (platform === 'youtube' && (u.searchParams.has('list') || u.pathname.startsWith('/live')))
    fail('UNSUPPORTED_CONTENT');
  // Strip tracking/query data; short-link redirects are checked again by the egress proxy.
  if (platform === 'youtube') {
    const id =
      h === 'youtu.be' ? u.pathname.slice(1) : u.searchParams.get('v') || u.pathname.split('/')[2];
    if (!id || !/^[-\w]{11}$/.test(id)) fail('INVALID_URL');
    return { platform, url: `https://www.youtube.com/watch?v=${id}` };
  }
  u.search = '';
  return { platform: platform!, url: u.toString() };
}
export function parseRange(
  header: string | undefined,
  size: number,
): { start: number; end: number; partial: boolean } {
  if (!header) return { start: 0, end: size - 1, partial: false };
  const m = /^bytes=(\d*)-(\d*)$/.exec(header);
  if (!m || (!m[1] && !m[2])) fail('INVALID_RANGE', 416);
  const start = m[1] ? Number(m[1]) : Math.max(0, size - Number(m[2]));
  const end = m[1] ? (m[2] ? Math.min(Number(m[2]), size - 1) : size - 1) : size - 1;
  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(end) ||
    start < 0 ||
    start >= size ||
    end < start ||
    (!m[1] && Number(m[2]) === 0)
  )
    fail('INVALID_RANGE', 416);
  return { start, end, partial: true };
}
export async function lockJob(tx: Prisma.TransactionClient, id: string) {
  await tx.$queryRaw`SELECT id FROM "DownloadJob" WHERE id=${id} FOR UPDATE`;
}
export async function lockAsset(tx: Prisma.TransactionClient, id: string) {
  await tx.$queryRaw`SELECT id FROM "TemporaryAsset" WHERE id=${id} FOR UPDATE`;
}
export async function rate(key: string, max: number, seconds = 60) {
  const result = await redis.eval(
    "local n=redis.call('INCR',KEYS[1]);if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end;return n",
    1,
    `rate:${key}`,
    seconds,
  );
  if (Number(result) > max) fail('RATE_LIMITED', 429);
}
export function passwordHash(password: string) {
  const salt = secret();
  return `${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
}
export function verifyPassword(password: string, stored: string) {
  const [salt, key] = stored.split(':');
  const expected = Buffer.from(key, 'hex');
  const actual = scryptSync(password, salt, 64);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}
export async function enqueue(id: string, phase: 'analyze' | 'prepare') {
  await queue.add(
    phase,
    { id },
    { jobId: `${phase}-${id}`, attempts: 1, removeOnComplete: true, removeOnFail: 100 },
  );
}
