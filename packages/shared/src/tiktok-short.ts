import { createHash } from 'node:crypto';
import { AppError } from './core';
export function normalizeTikTok(raw: string): string {
  let u: URL; try { u = new URL(raw); } catch { throw new AppError('INVALID_URL'); }
  const authority = /^https:\/\/([^/?#]+)/i.exec(raw)?.[1]?.toLowerCase();
  if (raw.length > 2048 || /[\x00-\x20\x7f\\]/.test(raw) || u.protocol !== 'https:' ||
      !authority || !['tiktok.com','www.tiktok.com','vt.tiktok.com','vm.tiktok.com'].includes(authority)) throw new AppError('INVALID_URL');
  const shortHost = ['vt.tiktok.com','vm.tiktok.com'].includes(u.hostname);
  const path = u.pathname.replace(/\/$/,'');
  if (!(shortHost ? /^\/[A-Za-z0-9_-]{3,64}$/.test(path) :
      /^\/(?:t\/[A-Za-z0-9_-]{3,64}|@[A-Za-z0-9_.-]+\/(?:photo|video)\/[0-9]{15,22})$/.test(path))) throw new AppError('UNSUPPORTED_CONTENT');
  u.pathname=path;u.search='';u.hash='';
  if (u.hostname==='tiktok.com') u.hostname='www.tiktok.com';
  return u.toString();
}
export function shortTikTok(raw: string): string | null {
  let u: URL; try { u = new URL(raw); } catch { return null; }
  if (!['vt.tiktok.com','vm.tiktok.com'].includes(u.hostname) &&
      !(['tiktok.com','www.tiktok.com'].includes(u.hostname) && u.pathname.startsWith('/t/'))) return null;
  return normalizeTikTok(raw);
}
export function requireShortEnabled(enabled: readonly string[]) {
  if (process.env.TIKTOK_ADAPTER_ENABLED !== '1' || process.env.TIKTOK_EGRESS_POLICY_ENABLED !== '1' ||
      !/^[a-f0-9]{64}$/.test(process.env.TIKTOK_EGRESS_CONTROL_SECRET || '') ||
      !(process.env.VERIFIED_PLATFORMS || '').split(',').includes('tiktok') || !enabled.includes('tiktok') ||
      (process.env.TIKTOK_VIDEO_ENABLED !== '1' && process.env.TIKTOK_PHOTO_ENABLED !== '1')) throw new AppError('UNSUPPORTED_PLATFORM');
}
export function shortTransfer(url: string) {
  const checked = shortTikTok(url); if (!checked) throw new AppError('INVALID_URL');
  return { profile: 'tiktok-short-analyze' as const, selection: 'ts1_' + createHash('sha256').update(checked).digest('hex') };
}
export function checkedResolved(value: any) {
  if (!value || Object.keys(value).sort().join(',') !== 'id,kind,url' || !['photo','video'].includes(value.kind) ||
      typeof value.id !== 'string' || !/^[0-9]{15,22}$/.test(value.id) || typeof value.url !== 'string') throw new AppError('FORMAT_UNAVAILABLE');
  const expected = new RegExp('^https://www\\.tiktok\\.com/@[A-Za-z0-9_.-]+/' + value.kind + '/' + value.id + '$');
  if (!expected.test(value.url)) throw new AppError('FORMAT_UNAVAILABLE');
  return value as { url: string; id: string; kind: 'photo' | 'video' };
}
