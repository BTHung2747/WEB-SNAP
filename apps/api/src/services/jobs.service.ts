import { Injectable } from '@nestjs/common';
import { Request, Response } from 'express';
import { open, statfs } from 'node:fs/promises';
import { pipeline } from 'node:stream/promises';
import {
  after,
  assetExpired,
  db,
  enqueue,
  expireSelectableMetadata,
  expiredMetadataJob,
  fail,
  filePath,
  hash,
  limits,
  lockJob,
  mediaRoot,
  ownerExpired,
  rate,
  secret,
} from '../../../../packages/shared/src/core';
import { admission, csrf, inputSchema, own, parse, prepareSchema } from '../common';
import { clientIp } from '../security/client-ip';
import { ratePolicy } from '../security/rate-policy';
import { photoPostId, requirePhotoEnabled, selectedPhoto, checkedPhotoFormats } from '../../../../packages/shared/src/tiktok-photo';
import { videoPostId, requireVideoEnabled } from '../../../../packages/shared/src/tiktok-video';
@Injectable()
export class JobsService {
  async analyze(req: Request, body: any, res: Response) {
    const s = await csrf(req);
    const { url: raw } = parse(inputSchema, body);
    const { validateUrl } = await import('../../../../packages/shared/src/core');
    const { url, platform } = validateUrl(raw);
    const photoId = photoPostId(url);
    const videoId = videoPostId(url);
    const l = await limits();
    if (!l.enabledPlatforms.includes(platform as any)) fail('UNSUPPORTED_PLATFORM');
    if (photoId) requirePhotoEnabled(l.enabledPlatforms);
    if (videoId) requireVideoEnabled(l.enabledPlatforms);
    await rate(
      `analyze:s:${s.id}`,
      ratePolicy.analyzeSession.max,
      ratePolicy.analyzeSession.seconds,
    );
    await rate(
      `analyze:ip:${hash(clientIp(req))}`,
      ratePolicy.analyzeIp.max,
      ratePolicy.analyzeIp.seconds,
    );
    const j = await db.$transaction(async (tx) => {
      await admission(tx, l);
      return tx.downloadJob.create({
        data: { sessionId: s.id, sourceUrl: url, platform, ownerUntil: after(l.sessionTtl) },
      });
    });
    // Durable DB state is an outbox; the worker reconciles missed enqueue operations.
    try {
      await enqueue(j.id, 'analyze');
    } catch {}
    res.status(202).json({ jobId: j.id });
  }
  async status(req: Request, id: string) {
    await own(req, id);
    const j = await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const current = await tx.downloadJob.findUniqueOrThrow({ where: { id }, include: { items: true } });
      if (await expireSelectableMetadata(tx, current) || expiredMetadataJob(current)) return null;
      return current;
    });
    if (!j) fail('JOB_EXPIRED', 410);
    return {
      id: j.id,
      state: j.state,
      errorCode: j.errorCode,
      title: j.title,
      duration: j.duration,
      metadataAcceptedAt: j.metadataAcceptedAt,
      metadataExpiresAt: j.metadataExpiresAt,
      items: ['failed', 'cancelled', 'expired'].includes(j.state) ? [] : j.items.map((i) => ({ id: i.id, kind: i.kind, formats: i.kind === 'photo' ? checkedPhotoFormats(i.formats) : i.formats })),
      previewUrl: j.title && !j.items.some(i => i.kind === 'photo') && !['failed', 'cancelled', 'expired'].includes(j.state) ? `/api/v1/jobs/${j.id}/preview` : null,
      mode: 'temporary',
      serverMeaning: 'server_finished không chứng minh tệp đã lưu vào thiết bị',
    };
  }
  async preview(req: Request, id: string, res: Response) {
    await own(req, id);
    const result = await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const j = await tx.downloadJob.findUniqueOrThrow({ where: { id } });
      if (await expireSelectableMetadata(tx, j) || j.cancelRequested || ['expired', 'cancelled', 'failed'].includes(j.state))
        return { expired: true, handle: null };
      // Acquire the handle under the same lock used to mark expiry/deletion.
      try { return { expired: false, handle: await open(filePath(`${id}/preview`), 'r') }; }
      catch { return { expired: false, handle: null }; }
    });
    if (result.expired) fail('JOB_EXPIRED', 410);
    const handle = result.handle;
    if (!handle) return res.status(404).end();
    try {
      const b = Buffer.alloc(8);
      await handle.read(b, 0, 8, 0);
      res.setHeader('Content-Type', b[0] === 0xff ? 'image/jpeg' : 'image/png');
      res.setHeader('Cache-Control', 'private, no-store');
      await pipeline(handle.createReadStream({ start: 0 }), res);
    } finally {
      await handle.close().catch(() => {});
    }
  }
  async prepare(req: Request, id: string, body: any, res: Response) {
    const { s } = await own(req, id, true);
    const selected = parse(prepareSchema, body);
    const l = await limits();
    const disk = await statfs(mediaRoot);
    if ((1 - Number(disk.bavail) / Number(disk.blocks)) * 100 >= l.diskStopPercent)
      fail('CAPACITY_UNAVAILABLE', 503);
    const result = await db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(8172401)`;
      await lockJob(tx, id);
      const j = await tx.downloadJob.findUniqueOrThrow({ where: { id }, include: { items: true } });
      if (await expireSelectableMetadata(tx, j)) return null;
      if (expiredMetadataJob(j)) fail('JOB_EXPIRED', 410);
      if (j.cancelRequested || ownerExpired(j)) fail('JOB_EXPIRED', 410);
      if (j.platform === 'tiktok' && (j.items.some(i => i.kind === 'video') ||
          (j.sourceUrl && videoPostId(j.sourceUrl)))) requireVideoEnabled(l.enabledPlatforms);
      if (j.items.some(i => i.kind === 'photo') || (j.sourceUrl && photoPostId(j.sourceUrl))) {
        requirePhotoEnabled(l.enabledPlatforms);
        selectedPhoto(j.items, selected.formatId, j.sourceUrl ? photoPostId(j.sourceUrl) || undefined : undefined);
        if (j.items[0].id !== selected.itemId) fail('FORMAT_UNAVAILABLE');
      }
      if (j.prepareKey) {
        if (j.prepareKey === selected.idempotencyKey && j.formatId === selected.formatId) return j;
        if (j.formatId === selected.formatId && ['queued', 'preparing', 'ready'].includes(j.state))
          return j;
        fail('IDEMPOTENCY_CONFLICT', 409);
      }
      if (j.state !== 'selectable') fail('FORMAT_UNAVAILABLE');
      const item = j.items.find((i) => i.id === selected.itemId);
      if (!item || !(item.formats as any[]).some((f) => f.id === selected.formatId))
        fail('FORMAT_UNAVAILABLE');
      if (!l.enabledPlatforms.includes(j.platform as any)) fail('UNSUPPORTED_PLATFORM');
      await admission(tx, l);
      if (
        await tx.downloadJob.count({
          where: { sessionId: s.id, state: { in: ['queued', 'preparing'] } },
        })
      )
        fail('RATE_LIMITED', 429);
      return tx.downloadJob.update({
        where: { id },
        data: {
          prepareKey: selected.idempotencyKey,
          formatId: selected.formatId,
          state: 'queued',
          ownerUntil: after(l.sessionTtl),
        },
      });
    });
    if (!result) fail('JOB_EXPIRED', 410);
    try {
      if (result.state === 'queued') await enqueue(id, 'prepare');
    } catch {}
    res.status(202).json({ jobId: id, state: result.state });
  }
  async heartbeat(req: Request, id: string) {
    await own(req, id, true);
    const l = await limits();
    const alive = await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const j = await tx.downloadJob.findUniqueOrThrow({ where: { id } });
      if (await expireSelectableMetadata(tx, j)) return false;
      if (
        j.cancelRequested ||
        ownerExpired(j) ||
        ['expired', 'cancelled', 'failed'].includes(j.state)
      )
        fail('JOB_EXPIRED', 410);
      await tx.downloadJob.update({
        where: { id },
        data: { ownerUntil: after(l.sessionTtl), releaseAt: null },
      });
      return true;
    });
    if (!alive) fail('JOB_EXPIRED', 410);
    return { ok: true };
  }
  async release(req: Request, id: string) {
    await own(req, id, true);
    const l = await limits();
    await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      await tx.downloadJob.update({ where: { id }, data: { releaseAt: after(l.releaseGrace) } });
    });
    return { ok: true };
  }
  async cancel(req: Request, id: string) {
    await own(req, id, true);
    const active = await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const j = await tx.downloadJob.findUniqueOrThrow({ where: { id } });
      if (await expireSelectableMetadata(tx, j) || expiredMetadataJob(j)) return false;
      // Repeated cancellation must not refresh terminal retention or reopen cleanup.
      if (j.state === 'cancelled' && j.cancelRequested) return true;
      await tx.downloadJob.update({
        where: { id },
        data: { cancelRequested: true, state: 'cancelled', sourceUrl: null },
      });
      return true;
    });
    if (!active) fail('JOB_EXPIRED', 410);
    return { ok: true };
  }
  async ticket(req: Request, id: string) {
    const { s, j } = await own(req, id, true);
    const l = await limits();
    if (
      j.state !== 'ready' ||
      j.cancelRequested ||
      !j.asset ||
      j.asset.state !== 'available' ||
      assetExpired(j.asset, ownerExpired(j))
    )
      fail('JOB_EXPIRED', 410);
    await rate(`ticket:s:${s.id}`, ratePolicy.ticketSession.max, ratePolicy.ticketSession.seconds);
    await rate(`ticket:j:${j.id}`, ratePolicy.ticketJob.max, ratePolicy.ticketJob.seconds);
    const token = secret();
    await db.downloadTicket.create({
      data: { id: hash(token), jobId: id, expiresAt: after(l.transferMax) },
    });
    return { url: `/api/v1/downloads/${token}`, expiresIn: l.transferMax };
  }
}
