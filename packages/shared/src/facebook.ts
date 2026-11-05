import { AppError } from './core';
const hosts = ['facebook.com', 'www.facebook.com', 'm.facebook.com', 'fb.watch'];
const numeric = /^[0-9]{6,22}$/;

export function normalizeFacebook(raw: string): string {
  let u: URL;
  try { u = new URL(raw); } catch { throw new AppError('INVALID_URL'); }
  const authority = /^https:\/\/([^/?#]+)/i.exec(raw)?.[1]?.toLowerCase();
  if (raw.length > 2048 || /[\x00-\x20\x7f\\]/.test(raw) || u.protocol !== 'https:' ||
      !authority || !hosts.includes(authority) || u.hash) throw new AppError('INVALID_URL');
  const path = u.pathname.replace(/\/$/, '');
  if (u.hostname === 'fb.watch') {
    if (!/^\/[A-Za-z0-9_-]{3,80}$/.test(path)) throw new AppError('UNSUPPORTED_CONTENT');
    return `https://fb.watch${path}/`;
  }
  const queryIds = ['v', 'video_id'].flatMap(k => u.searchParams.getAll(k));
  if (queryIds.length > 1 || queryIds.some(id => !numeric.test(id))) throw new AppError('INVALID_URL');
  if (['/watch', '/video.php', '/video/video.php'].includes(path)) {
    if (queryIds.length !== 1) throw new AppError('INVALID_URL');
    return `https://www.facebook.com/watch?v=${queryIds[0]}`;
  }
  const match = /^\/(?:reel\/|(?:[A-Za-z0-9_.-]+\/)?videos\/)([0-9]{6,22})$/.exec(path);
  if (match) {
    if (queryIds.length && queryIds[0] !== match[1]) throw new AppError('INVALID_URL');
    return `https://www.facebook.com/watch?v=${match[1]}`;
  }
  if (!/^\/share\/[vr]\/[A-Za-z0-9_-]{3,80}$/.test(path) || queryIds.length)
    throw new AppError('UNSUPPORTED_CONTENT');
  return `https://www.facebook.com${path}/`;
}

export function facebookPostId(raw: string): string | null {
  try {
    const u = new URL(raw);
    if (!hosts.includes(u.hostname)) return null;
    return new URL(normalizeFacebook(raw)).searchParams.get('v');
  } catch { return null; }
}

export function checkedFacebookResolved(value: any, original: string) {
  if (!value || Object.keys(value).sort().join(',') !== 'id,kind,url' || value.kind !== 'video' ||
      typeof value.id !== 'string' || !numeric.test(value.id) ||
      value.url !== `https://www.facebook.com/watch?v=${value.id}` ||
      (facebookPostId(original) && facebookPostId(original) !== value.id))
    throw new AppError('FORMAT_UNAVAILABLE');
  return value as {url: string; id: string; kind: 'video'};
}
