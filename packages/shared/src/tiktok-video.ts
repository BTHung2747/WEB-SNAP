import { AppError } from './core';

// Canonical video admission only. Resolve/share redirects need their own assigned scope.
export function videoPostId(raw: string): string | null {
  let u: URL; try { u = new URL(raw); } catch { return null; }
  if (!['tiktok.com', 'www.tiktok.com', 'vt.tiktok.com', 'vm.tiktok.com'].includes(u.hostname)) return null;
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
