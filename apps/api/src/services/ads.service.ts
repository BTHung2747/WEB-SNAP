import { Injectable } from '@nestjs/common';
import { Request, Response } from 'express';
import { z } from 'zod';
import { db, fail, rate, redis } from '../../../../packages/shared/src/core';
import { csrf, parse, session, uuid } from '../common';
@Injectable()
export class AdsService {
  async ads(req: Request, res: Response) {
    const s = await session(req);
    const placement = req.query.placement === 'sponsor' ? 'sponsor' : 'banner';
    const now = new Date();
    const campaigns = await db.adCampaign.findMany({
      where: { enabled: true, placement, startsAt: { lte: now }, endsAt: { gt: now } },
    });
    const total = campaigns.reduce((n, c) => n + c.weight, 0);
    let roll = Math.random() * total;
    const c = campaigns.find((c) => (roll -= c.weight) < 0);
    // A GET grant conservatively consumes cooldown even if its response is lost.
    // Select first: an empty placement must not consume the session's claim.
    if (c && placement === 'sponsor') {
      const granted = await redis.set(`ads:sponsor:${s.id}`, '1', 'EX', 600, 'NX');
      if (granted !== 'OK') return res.json(null);
    }
    res.json(
      c
        ? {
            id: c.id,
            title: c.title,
            imageUrl: c.imageUrl,
            targetUrl: c.targetUrl,
            linkType: c.linkType,
            placement,
          }
        : null,
    );
  }
  async adEvent(req: Request, body: any) {
    const s = await csrf(req);
    await rate(`ads:${s.id}`, 60);
    const event = parse(
      z.object({ id: uuid, campaignId: uuid, type: z.enum(['impression', 'click']) }).strict(),
      body,
    );
    const now = new Date();
    const c = await db.adCampaign.findFirst({
      where: { id: event.campaignId, enabled: true, startsAt: { lte: now }, endsAt: { gt: now } },
    });
    if (!c) fail('CAMPAIGN_UNAVAILABLE', 404);
    // One INSERT ON CONFLICT, including simultaneous retries of an event UUID.
    await db.adEvent.createMany({ data: event, skipDuplicates: true });
    return { ok: true };
  }
}
