import { Injectable } from '@nestjs/common';
import { Request, Response } from 'express';
import {
  after,
  AppError,
  db,
  hash,
  limits,
  rate,
  redis,
  secret,
  verified,
} from '../../../../packages/shared/src/core';
import { cookie, session } from '../common';
import { clientIp } from '../security/client-ip';
import { ratePolicy } from '../security/rate-policy';
import { requirePhotoEnabled } from '../../../../packages/shared/src/tiktok-photo';
@Injectable()
export class SessionService {
  async health() {
    await db.$queryRaw`SELECT 1`;
    await redis.ping();
    return { ok: true };
  }
  async createSession(req: Request, res: Response) {
    let s;
    try {
      s = await session(req);
    } catch (e) {
      if (!(e instanceof AppError) || e.code !== 'SESSION_REQUIRED') throw e;
    }
    if (!s) {
      const policy = ratePolicy.sessionCreate;
      await rate(`session:create:ip:${hash(clientIp(req))}`, policy.max, policy.seconds);
      const token = secret();
      s = await db.session.create({
        data: { id: hash(token), csrf: secret(), expiresAt: after(86400) },
      });
      res.cookie('ws_session', token, cookie);
    }
    const l = await limits();
    // Configuration capability only; the worker still requires each phase's proof.
    let tiktokPhoto = false;
    try {
      requirePhotoEnabled(l.enabledPlatforms);
      tiktokPhoto = process.env.TIKTOK_EGRESS_POLICY_ENABLED === '1' &&
        /^[a-f0-9]{64}$/.test(process.env.TIKTOK_EGRESS_CONTROL_SECRET || '');
    } catch (e) {
      if (!(e instanceof AppError) || e.code !== 'UNSUPPORTED_PLATFORM') throw e;
    }
    res.json({
      csrf: s.csrf,
      supported: l.enabledPlatforms,
      verified,
      contact: process.env.CONTACT_EMAIL || null,
      productName: (process.env.PRODUCT_NAME || 'WED SNAP').slice(0, 60),
      heartbeatSeconds: 15,
      capabilities: { tiktokPhoto },
    });
  }
}
