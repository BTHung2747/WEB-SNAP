// Public WED SNAP glue only. Hashes bind album structure, not image pixels.
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { AppError } from './core';

const reject = (code = 'FORMAT_UNAVAILABLE'): never => { throw new AppError(code); };
const hex = z.string().regex(/^[a-f0-9]{64}$/);
const dimension = z.number().int().min(1).max(8192);
const image = z.object({ index: z.number().int().min(1).max(50), width: dimension, height: dimension, itemKey: hex }).strict();
const summarySchema = z.object({ version: z.literal('tt-photo-album-v1'), id: z.string().regex(/^[0-9]{15,22}$/),
  type: z.literal('photo'), imageCount: z.number().int().min(1).max(50), images: z.array(image).min(1).max(50), snapshotKey: hex }).strict();
const formatSchema = image.extend({ id: z.string().regex(/^ttp1_[0-9]{2}_[a-f0-9]{64}$/), label: z.string().max(40), size: z.null(),
  kind: z.literal('photo'), contentId: z.string().regex(/^[0-9]{15,22}$/), imageCount: z.number().int().min(1).max(50),
  mime: z.literal('image/jpeg'), snapshotKey: hex }).strict();
export type PhotoFormat = z.infer<typeof formatSchema>;
function parse<T extends z.ZodTypeAny>(schema: T, value: unknown): z.infer<T> {
  const result = schema.safeParse(value); return result.success ? result.data : reject();
}
function canonical(value: any): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
const digest = (value: any) => createHash('sha256').update(canonical(value)).digest('hex');
export function photoPostId(raw: string): string | null {
  let u: URL; try { u = new URL(raw); } catch { return null; }
  if (!['www.tiktok.com', 'tiktok.com'].includes(u.hostname) || !u.pathname.includes('/photo/')) return null;
  const m = /^\/@[A-Za-z0-9_.-]+\/photo\/([0-9]{15,22})$/.exec(u.pathname);
  if (!m) return reject('INVALID_URL');
  if (u.protocol !== 'https:' || u.username || u.password || u.port || u.search || u.hash) reject('INVALID_URL');
  return m[1];
}
export function requirePhotoEnabled(enabledPlatforms: readonly string[]) {
  if (process.env.TIKTOK_PHOTO_ENABLED !== '1' || process.env.TIKTOK_ADAPTER_ENABLED !== '1' ||
      !(process.env.VERIFIED_PLATFORMS || '').split(',').includes('tiktok') || !enabledPlatforms.includes('tiktok')) reject('UNSUPPORTED_PLATFORM');
}
export function photoLimits<T extends { maxBytes: number; maxInputBytes: number; analyzeTimeout: number; prepareTimeout: number }>(l: T): T {
  return { ...l, maxBytes: Math.min(l.maxBytes, 16 * 1024 * 1024), maxInputBytes: Math.min(l.maxInputBytes, 36 * 1024 * 1024),
    analyzeTimeout: Math.min(l.analyzeTimeout, 30), prepareTimeout: Math.min(l.prepareTimeout, 180) };
}
function checkedSummary(value: unknown, expected: string) {
  const s = parse(summarySchema, value);
  if (s.id !== expected || s.images.length !== s.imageCount) reject();
  s.images.forEach((r, i) => {
    if (r.index !== i + 1 || r.width * r.height > 16000000 || r.itemKey !== digest([expected, 'photo', r.index, r.width, r.height])) reject();
  });
  const { snapshotKey, ...structure } = s;
  if (snapshotKey !== digest(structure)) reject();
  return s;
}
export function checkedPhotoFormats(value: unknown, expected?: string): PhotoFormat[] {
  const rows = parse(z.array(formatSchema).min(1).max(50), value);
  const id = expected ?? rows[0].contentId;
  const summary = checkedSummary({ version: 'tt-photo-album-v1', id, type: 'photo', imageCount: rows.length,
    images: rows.map(({ index, width, height, itemKey }) => ({ index, width, height, itemKey })), snapshotKey: rows[0].snapshotKey }, id);
  rows.forEach((r, i) => {
    if (r.contentId !== id || r.imageCount !== rows.length || r.snapshotKey !== summary.snapshotKey ||
        r.id !== `ttp1_${String(i + 1).padStart(2, '0')}_${summary.snapshotKey}` || r.label !== `Ảnh ${i + 1}/${rows.length}`) reject();
  });
  return rows;
}
export function checkedPhotoMetadata(value: unknown, expected: string) {
  const p = parse(z.object({ kind: z.literal('photo'), title: z.literal('Album TikTok'), duration: z.null(),
    summary: summarySchema, formats: z.array(formatSchema).min(1).max(50) }).strict(), value);
  const s = checkedSummary(p.summary, expected), formats = checkedPhotoFormats(p.formats, expected);
  if (s.snapshotKey !== formats[0].snapshotKey) reject();
  return { kind: 'photo' as const, title: p.title, duration: null, formats };
}
export function selectedPhoto(items: any[], formatId: string, expected?: string): PhotoFormat {
  if (items.length !== 1 || items[0].kind !== 'photo') reject();
  const rows = checkedPhotoFormats(items[0].formats, expected);
  return rows.find(r => r.id === formatId) ?? reject();
}
export function checkedPhotoFile(value: unknown, selected: PhotoFormat, limits: { maxBytes: number; maxInputBytes: number }) {
  const p = parse(z.object({ file: z.literal('image.jpg'), size: z.number().int().positive().safe(), inputBytes: z.number().int().positive().safe(),
    sha256: hex, selectedIndex: z.number().int(), itemKey: hex,
    contract: z.object({ magic: z.literal('jpeg'), mime: z.literal('image/jpeg'), width: dimension, height: dimension,
      pixels: z.number().int(), frames: z.literal(1), fullDecode: z.literal('PASS') }).strict() }).strict(), value);
  const cap = photoLimits({ ...limits, analyzeTimeout: 30, prepareTimeout: 180 });
  if (p.size > cap.maxBytes || p.inputBytes > cap.maxInputBytes || p.inputBytes < p.size ||
      p.selectedIndex !== selected.index || p.itemKey !== selected.itemKey || p.contract.width !== selected.width ||
      p.contract.height !== selected.height || p.contract.pixels !== selected.width * selected.height) reject();
  return p;
}
export function assetDescriptor(jobId: string, items: any[], asset: { path: string }, formatId: string | null) {
  if (items.length !== 1) reject('INVALID_ASSET_PATH');
  const photo = items[0].kind === 'photo';
  if (photo) selectedPhoto(items, formatId || '');
  else if (items[0].kind !== 'video') reject('INVALID_ASSET_PATH');
  const name = photo ? 'image.jpg' : 'media.mp4';
  if (asset.path !== `${jobId}/${name}`) reject('INVALID_ASSET_PATH');
  return { photo, mime: photo ? 'image/jpeg' : 'video/mp4', filename: photo ? 'wed-snap-image.jpg' : 'wed-snap-video.mp4' };
}
