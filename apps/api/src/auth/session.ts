import { Request } from 'express';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { db, fail, hash, origin, redis } from '../../../../packages/shared/src/core';
import { idSchema, parse } from '../validation';
export const secure = process.env.COOKIE_SECURE === 'true';
export const signing = process.env.ADMIN_SESSION_SECRET || '';
export const cookie = {
  httpOnly: true,
  secure,
  sameSite: 'lax' as const,
  path: '/api',
  maxAge: 86400000,
};
if (signing.length < 32)
  throw new Error('ADMIN_SESSION_SECRET must contain at least 32 characters');
export async function session(req: Request) {
  const token = req.cookies?.ws_session;
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) fail('SESSION_REQUIRED', 403);
  const s = await db.session.findUnique({ where: { id: hash(token) } });
  if (!s || s.expiresAt < new Date()) fail('SESSION_REQUIRED', 403);
  return s;
}
export async function csrf(req: Request) {
  const s = await session(req);
  const token = req.get('x-csrf-token') || req.body?.csrf;
  if (req.get('origin') !== origin || typeof token !== 'string' || token !== s.csrf)
    fail('CSRF_INVALID', 403);
  return s;
}
export async function own(req: Request, id: string, write = false) {
  parse(idSchema, { id });
  const s = write ? await csrf(req) : await session(req);
  const j = await db.downloadJob.findFirst({
    where: { id, sessionId: s.id },
    include: { items: true, asset: true },
  });
  if (!j) fail('JOB_NOT_FOUND', 404);
  return { s, j };
}
export function sign(value: string) {
  return createHmac('sha256', signing).update(value).digest('hex');
}
export async function admin(req: Request, write = false) {
  if (write) await csrf(req);
  const raw = req.cookies?.ws_admin;
  if (typeof raw !== 'string') fail('ADMIN_REQUIRED', 403);
  const [token, mac] = raw.split('.');
  if (
    !token ||
    !mac ||
    !/^[a-f0-9]{64}$/.test(token) ||
    !/^[a-f0-9]{64}$/.test(mac) ||
    !timingSafeEqual(Buffer.from(sign(token), 'hex'), Buffer.from(mac, 'hex'))
  )
    fail('ADMIN_REQUIRED', 403);
  const actor = await redis.get(`admin:${hash(token)}`);
  if (!actor) fail('ADMIN_REQUIRED', 403);
  return actor;
}
