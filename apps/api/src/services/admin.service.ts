import { Injectable } from '@nestjs/common';
import { Request, Response } from 'express';
import {
  db,
  fail,
  hash,
  limits,
  limitsSchema,
  queue,
  rate,
  redis,
  secret,
  verified,
  verifyPassword,
} from '../../../../packages/shared/src/core';
import { admin, campaignSchema, cookie, csrf, idSchema, loginSchema, parse, sign } from '../common';
import { clientIp } from '../security/client-ip';
import { ratePolicy } from '../security/rate-policy';
import { adStatisticsQuery } from '../validation';
@Injectable()
export class AdminService {
  async login(req: Request, body: any, res: Response) {
    await csrf(req);
    await rate(`login:${hash(clientIp(req))}`, ratePolicy.loginIp.max, ratePolicy.loginIp.seconds);
    const { email, password } = parse(loginSchema, body);
    const u = await db.adminUser.findUnique({ where: { email: email.toLowerCase() } });
    const dummy = '0'.repeat(64) + ':' + '0'.repeat(128);
    const ok = verifyPassword(password, u?.passwordHash || dummy);
    if (!u || !ok) fail('LOGIN_FAILED', 403);
    const token = secret();
    await redis.set(`admin:${hash(token)}`, u.email, 'EX', 3600);
    res.cookie('ws_admin', `${token}.${sign(token)}`, { ...cookie, maxAge: 3600000 });
    res.json({ ok: true });
  }
  async logout(req: Request, res: Response) {
    await csrf(req);
    const token = req.cookies?.ws_admin?.split('.')[0];
    if (token) await redis.del(`admin:${hash(token)}`);
    res.clearCookie('ws_admin', cookie);
    res.json({ ok: true });
  }
  async dashboard(req: Request) {
    await admin(req);
    const [groups, leases, budget, failed, events] = await Promise.all([
      db.downloadJob.groupBy({ by: ['state'], _count: true }),
      db.transferLease.groupBy({ by: ['state'], _count: true, _sum: { bytes: true } }),
      db.egressBudget.findMany(),
      db.downloadJob.findMany({
        where: { state: 'failed' },
        select: { id: true, platform: true, errorCode: true, updatedAt: true },
        take: 20,
        orderBy: { updatedAt: 'desc' },
      }),
      db.adEvent.groupBy({ by: ['campaignId', 'type'], _count: true }),
    ]);
    return {
      groups,
      leases: leases.map((x) => ({ ...x, _sum: { bytes: String(x._sum.bytes || 0) } })),
      budget: budget.map((x) => ({ ...x, charged: String(x.charged) })),
      failed,
      events,
      queue: { waiting: await queue.getWaitingCount(), active: await queue.getActiveCount() },
      verified,
    };
  }
  async settings(req: Request) {
    await admin(req);
    return limits();
  }
  async adStatistics(req: Request) {
    await admin(req);
    const query = parse(adStatisticsQuery, req.query);
    const to = query.to === undefined ? new Date() : new Date(query.to);
    const from = query.from === undefined ? new Date(to.getTime() - 7 * 86400000) : new Date(query.from);
    const { campaigns, events } = await db.$transaction(async (tx) => {
      const campaigns = await tx.adCampaign.findMany({ select: { id: true, title: true }, orderBy: { id: 'asc' } });
      const events = await tx.adEvent.groupBy({ by: ['campaignId', 'type'],
        where: { createdAt: { gte: from, lt: to }, type: { in: ['impression', 'click'] } }, _count: true });
      return { campaigns, events };
    });
    const counts = new Map(events.map((e) => [e.campaignId + ':' + e.type, e._count]));
    return {
      window: { from: from.toISOString(), to: to.toISOString(), timezone: 'UTC' },
      rows: campaigns.map((c) => {
        const impressions = counts.get(c.id + ':impression') || 0;
        const clicks = counts.get(c.id + ':click') || 0;
        return { campaignId: c.id, title: c.title, impressions, clicks,
          ctrPercent: impressions === 0 ? null : clicks / impressions * 100 };
      }),
    };
  }
  async saveSettings(req: Request, body: any) {
    const actor = await admin(req, true);
    const value = parse(limitsSchema, body);
    if (value.enabledPlatforms.some((p) => !verified.includes(p))) fail('PLATFORM_NOT_VERIFIED');
    await db.$transaction(async (tx) => {
      await tx.settings.upsert({ where: { id: 'main' }, create: { value }, update: { value } });
      await tx.auditLog.create({ data: { actor, action: 'settings.update', detail: value } });
    });
    return value;
  }
  async campaigns(req: Request) {
    await admin(req);
    return db.adCampaign.findMany({ orderBy: { startsAt: 'desc' } });
  }
  async createCampaign(req: Request, body: any) {
    const actor = await admin(req, true);
    const data = parse(campaignSchema, body);
    return db.$transaction(async (tx) => {
      const c = await tx.adCampaign.create({ data });
      await tx.auditLog.create({
        data: { actor, action: 'campaign.create', detail: { id: c.id, ...data } },
      });
      return c;
    });
  }
  async updateCampaign(req: Request, id: string, body: any) {
    parse(idSchema, { id });
    const actor = await admin(req, true);
    const data = parse(campaignSchema, body);
    return db.$transaction(async (tx) => {
      const c = await tx.adCampaign.update({ where: { id }, data });
      await tx.auditLog.create({
        data: { actor, action: 'campaign.update', detail: { id, ...data } },
      });
      return c;
    });
  }
  async deleteCampaign(req: Request, id: string) {
    parse(idSchema, { id });
    const actor = await admin(req, true);
    await db.$transaction(async (tx) => {
      await tx.adCampaign.delete({ where: { id } });
      await tx.auditLog.create({ data: { actor, action: 'campaign.delete', detail: { id } } });
    });
    return { ok: true };
  }
}
