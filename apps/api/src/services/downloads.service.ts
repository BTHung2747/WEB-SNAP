import { Injectable } from '@nestjs/common';
import { Request, Response } from 'express';
import { open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import {
  after,
  assetExpired,
  db,
  fail,
  filePath,
  hash,
  limits,
  lockAsset,
  lockJob,
  ownerExpired,
  parseRange,
  rate,
} from '../../../../packages/shared/src/core';
import { session } from '../common';
import { assetDescriptor } from '../../../../packages/shared/src/tiktok-photo';
@Injectable()
export class DownloadsService {
  async download(req: Request, token: string, res: Response) {
    const s = await session(req);
    if (!/^[a-f0-9]{64}$/.test(token)) fail('JOB_EXPIRED', 410);
    await rate(`download:${s.id}`, 60);
    const t = await db.downloadTicket.findUnique({
      where: { id: hash(token) },
      include: { job: { include: { asset: true, items: true } } },
    });
    if (!t || t.expiresAt < new Date() || t.job.sessionId !== s.id) fail('JOB_EXPIRED', 410);
    const a = t.job.asset;
    if (!a) fail('JOB_EXPIRED', 410);
    const descriptor = assetDescriptor(t.jobId, t.job.items, a, t.job.formatId);
    let range;
    try {
      range = parseRange(req.get('range'), Number(a.size));
    } catch (e) {
      res.setHeader('Content-Range', `bytes */${a.size}`);
      throw e;
    }
    const l = await limits();
    const length = range.end - range.start + 1;
    const month = new Date().toISOString().slice(0, 7);
    if (req.method === 'HEAD') {
      if (t.job.cancelRequested || a.state !== 'available' || assetExpired(a, ownerExpired(t.job)))
        fail('JOB_EXPIRED', 410);
      if (descriptor.photo) {
        const h = await open(filePath(a.path), constants.O_RDONLY | constants.O_NOFOLLOW);
        try { const st = await h.stat(); if (!st.isFile() || st.size !== Number(a.size)) fail('JOB_EXPIRED', 410); }
        finally { await h.close(); }
      }
      res.status(range.partial ? 206 : 200);
      res.setHeader('Content-Type', descriptor.mime);
      res.setHeader('Content-Disposition', `attachment; filename="${descriptor.filename}"`);
      res.setHeader('Content-Length', length);
      res.setHeader('Accept-Ranges', 'bytes');
      if (range.partial)
        res.setHeader('Content-Range', `bytes ${range.start}-${range.end}/${a.size}`);
      res.end();
      return;
    }
    const { lease, transferDeadline } = await db.$transaction(async (tx) => {
      // Always job -> asset -> budget locks; sweeper follows the same ordering.
      await lockJob(tx, t.jobId);
      await lockAsset(tx, a.id);
      const job = await tx.downloadJob.findUniqueOrThrow({ where: { id: t.jobId }, include: { items: true } });
      const asset = await tx.temporaryAsset.findUniqueOrThrow({ where: { id: a.id } });
      const freshDescriptor = assetDescriptor(t.jobId, job.items, asset, job.formatId);
      if (freshDescriptor.mime !== descriptor.mime || asset.path !== a.path || asset.size !== a.size) fail('JOB_EXPIRED', 410);
      if (
        job.cancelRequested ||
        job.state !== 'ready' ||
        asset.state !== 'available' ||
        assetExpired(asset, ownerExpired(job))
      )
        fail('JOB_EXPIRED', 410);
      await tx.egressBudget.upsert({ where: { month }, create: { month }, update: {} });
      await tx.$queryRaw`SELECT month FROM "EgressBudget" WHERE month=${month} FOR UPDATE`;
      const budget = await tx.egressBudget.findUniqueOrThrow({ where: { month } });
      if (budget.charged + BigInt(length) > BigInt(l.monthlyBytes))
        fail('CAPACITY_UNAVAILABLE', 503);
      await tx.egressBudget.update({
        where: { month },
        data: { charged: { increment: BigInt(length) } },
      });
      const transferDeadline = asset.transferDeadline || after(l.transferMax);
      await tx.temporaryAsset.update({
        where: { id: a.id },
        data: {
          transferDeadline,
          retryUntil: null,
        },
      });
      const lease = await tx.transferLease.create({
        data: { assetId: a.id, expiresAt: after(l.leaseTtl), reserved: BigInt(length), month },
      });
      return { lease, transferDeadline };
    });
    let bytes = 0;
    let result = 'disconnected';
    let stream: any;
    let handle: any;
    let renewing = false;
    const deadline = transferDeadline;
    const timer = setTimeout(
      () => {
        result = 'timed_out';
        stream?.destroy(new Error('TRANSFER_TIMEOUT'));
        res.destroy();
      },
      Math.max(1, deadline.getTime() - Date.now()),
    );
    const renew = setInterval(async () => {
      if (renewing) return;
      renewing = true;
      try {
        const alive = await db.transferLease.updateMany({
          where: { id: lease.id, state: 'started', expiresAt: { gt: new Date() } },
          data: { expiresAt: after(l.leaseTtl), bytes: BigInt(bytes) },
        });
        if (!alive.count) throw new Error('lease expired');
      } catch {
        stream?.destroy(new Error('LEASE_LOST'));
        res.destroy();
      } finally {
        renewing = false;
      }
    }, 15000);
    try {
      handle = await open(filePath(a.path), descriptor.photo ? constants.O_RDONLY | constants.O_NOFOLLOW : 'r');
      const st = await handle.stat();
      if (st.size !== Number(a.size)) throw new Error('asset size mismatch');
      res.status(range.partial ? 206 : 200);
      res.setHeader('Content-Type', descriptor.mime);
      res.setHeader('Content-Length', length);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Cache-Control', 'private, no-store');
      res.setHeader('Content-Disposition', `attachment; filename="${descriptor.filename}"`);
      if (range.partial)
        res.setHeader('Content-Range', `bytes ${range.start}-${range.end}/${a.size}`);
      stream = handle.createReadStream({ start: range.start, end: range.end });
      const counter = new Transform({
        transform(chunk, _enc, cb) {
          bytes += chunk.length;
          cb(null, chunk);
        },
      });
      await pipeline(stream, counter, res);
      result = 'server_finished';
    } catch {
      if (!res.headersSent && !res.destroyed)
        res.status(410).json({ error: { code: 'JOB_EXPIRED' } });
    } finally {
      clearTimeout(timer);
      clearInterval(renew);
      if (handle) await handle.close().catch(() => {});
      await db
        .$transaction(async (tx) => {
          await lockAsset(tx, a.id);
          const live = await tx.transferLease.findUniqueOrThrow({ where: { id: lease.id } });
          if (live.state !== 'started') return;
          await tx.transferLease.update({
            where: { id: lease.id },
            data: {
              state: result,
              bytes: BigInt(bytes),
              endedAt: new Date(),
              expiresAt: new Date(),
            },
          });
          await tx.egressBudget.update({
            where: { month },
            data: { charged: { decrement: BigInt(Math.max(0, length - bytes)) } },
          });
          const remaining = await tx.transferLease.count({
            where: { assetId: a.id, state: 'started', expiresAt: { gt: new Date() } },
          });
          if (!remaining)
            await tx.temporaryAsset.update({
              where: { id: a.id },
              data: { retryUntil: after(l.retryGrace) },
            });
        })
        .catch(() => console.error('{"event":"lease_finalize_failed"}'));
    }
  }
}
