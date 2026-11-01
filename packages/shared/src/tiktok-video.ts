import { AppError } from './core';
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { shortTikTok } from './tiktok-short';

export const fullHdVideo = (w: unknown, h: unknown): boolean =>
  Number.isSafeInteger(w) && Number.isSafeInteger(h) && Number(w) > 0 && Number(h) > 0 &&
  Math.min(Number(w), Number(h)) <= 1080 && Math.max(Number(w), Number(h)) <= 1920;
const descriptor = z.object({ id: z.string().regex(/^(play|(?:h264|h265|bytevc1)_[0-9]+p_[0-9]+)$/),
  vcodec: z.enum(['h264','avc1','h265','hevc','hvc1','hev1']), acodec: z.enum(['aac','none']),
  width: z.number().int().positive(), height: z.number().int().positive() }).strict();
const selectionSchema = z.object({ version: z.literal('tt-video-v2'), contentId: z.string().regex(/^[0-9]{15,22}$/),
  duration: z.number().positive().max(600), video: descriptor, audioSource: descriptor.nullable(),defaultVideo: descriptor.nullable() }).strict();
const formatSchema = z.object({ id: z.string().regex(/^tt2_[a-f0-9]{64}$/), label: z.string().max(100),
  size: z.number().int().positive().max(209715200).nullable(), width: z.number().int(), height: z.number().int(),
  kind: z.literal('video'), selection: selectionSchema, sourceDefault: z.boolean(), highest: z.boolean() }).strict();
function canonical(v: any): string {
  if (v && typeof v === 'object') return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canonical(v[k])).join(',') + '}';
  return JSON.stringify(v);
}
const reject = (): never => { throw new AppError('FORMAT_UNAVAILABLE'); };
export function checkedVideoFormats(value: unknown, expected: string) {
  const parsed = z.array(formatSchema).min(1).max(30).safeParse(value);
  if (!parsed.success) return reject();
  const rows = parsed.data;
  const spatial = (r: typeof rows[number]) => [r.width * r.height, Math.min(r.width,r.height),Math.max(r.width,r.height)];
  const compare = (a: number[],b: number[]) => a[0]-b[0] || a[1]-b[1] || a[2]-b[2];
  const best = rows.map(spatial).sort(compare).at(-1)!;
  for (const f of rows) {
    const s = f.selection, v = s.video, a = s.audioSource;
    if (s.contentId !== expected || !fullHdVideo(v.width,v.height) || f.width !== v.width || f.height !== v.height ||
        f.id !== 'tt2_' + createHash('sha256').update(canonical(s)).digest('hex') ||
        f.sourceDefault !== (s.defaultVideo !== null && canonical(v) === canonical(s.defaultVideo)) || f.highest !== (compare(spatial(f),best) === 0)) return reject();
    const hevc = !['h264','avc1'].includes(v.vcodec);
    if (a ? (!hevc || v.acodec !== 'none' || !['h264','avc1'].includes(a.vcodec) || a.acodec !== 'aac' ||
             !fullHdVideo(a.width,a.height) || !/^(play|h264_[0-9]+p_[0-9]+)$/.test(a.id)) : v.acodec !== 'aac') return reject();
    if (v.id !== 'play' && /^h264_/.test(v.id) === hevc) return reject();
  }
  if (new Set(rows.map(f => f.id)).size !== rows.length) return reject();
  return rows;
}
export function selectedVideo(items: any[], id: string, expected: string) {
  if (items.length !== 1 || items[0].kind !== 'video') return reject();
  const row = checkedVideoFormats(items[0].formats,expected).find(f => f.id === id);
  return row ?? reject();
}
export function videoTransfer(items: any[], id: string, expected: string) {
  const row = selectedVideo(items,id,expected);
  return row.selection.audioSource ? { profile: 'hevc-copy-pair' as const, selection: row.id } : undefined;
}

// Canonical video admission only. Resolve/share redirects need their own assigned scope.
export function videoPostId(raw: string): string | null {
  let u: URL; try { u = new URL(raw); } catch { return null; }
  if (!['tiktok.com', 'www.tiktok.com', 'vt.tiktok.com', 'vm.tiktok.com'].includes(u.hostname)) return null;
  if (shortTikTok(raw)) return null;
  if (u.pathname.includes('/photo/')) return null;
  const match = /^\/@[A-Za-z0-9_.-]+\/video\/([0-9]{15,22})$/.exec(u.pathname);
  if (!['tiktok.com', 'www.tiktok.com'].includes(u.hostname) || !match) throw new AppError('UNSUPPORTED_CONTENT');
  if (u.protocol !== 'https:' || u.username || u.password || u.port || u.search || u.hash) throw new AppError('INVALID_URL');
  return match[1];
}
export function requireVideoEnabled(enabled: readonly string[]) {
  if (process.env.TIKTOK_ADAPTER_ENABLED !== '1' || process.env.TIKTOK_VIDEO_ENABLED !== '1' ||
      process.env.TIKTOK_EGRESS_POLICY_ENABLED !== '1' ||
      !/^[a-f0-9]{64}$/.test(process.env.TIKTOK_EGRESS_CONTROL_SECRET || '') ||
      !(process.env.VERIFIED_PLATFORMS || '').split(',').includes('tiktok') || !enabled.includes('tiktok'))
    throw new AppError('UNSUPPORTED_PLATFORM');
}
export function videoLimits<T extends { maxDuration: number; maxBytes: number; maxInputBytes: number; analyzeTimeout: number; prepareTimeout: number }>(l: T): T {
  return { ...l, maxDuration: Math.min(l.maxDuration, 600), maxBytes: Math.min(l.maxBytes, 200 * 1024 * 1024),
    maxInputBytes: Math.min(l.maxInputBytes, 250 * 1024 * 1024), analyzeTimeout: Math.min(l.analyzeTimeout, 30),
    prepareTimeout: Math.min(l.prepareTimeout, 180) };
}
