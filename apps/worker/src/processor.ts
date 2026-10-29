import { rm, open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { createHash } from 'node:crypto';
import {
  after,
  AppError,
  db,
  filePath,
  limits,
  lockJob,
  metadataDeadline,
  ownerExpired,
  secret,
} from '../../../packages/shared/src/core';
import { runAdapter } from './adapter';
import { ProcessGroupUnconfirmed } from './process-group';
import { diskAvailable } from './lifecycle';
import { photoPostId, photoLimits, requirePhotoEnabled, checkedPhotoMetadata, checkedPhotoFile, selectedPhoto } from '../../../packages/shared/src/tiktok-photo';
import { videoPostId, videoLimits, requireVideoEnabled } from '../../../packages/shared/src/tiktok-video';
export async function processJob(queued: any) {
  const id = queued.data.id;
  const phase = queued.name;
  let l = await limits();
  const token = secret();
  const started = Date.now();
  const j = await db.$transaction(async (tx) => {
    await lockJob(tx, id);
    const current = await tx.downloadJob.findUnique({ where: { id }, include: { items: true } });
    if (
      !current ||
      current.workerToken ||
      current.cancelRequested ||
      ownerExpired(current) ||
      current.state !== (phase === 'analyze' ? 'analyzing' : 'queued')
    )
      return null;
    if (!l.enabledPlatforms.includes(current.platform as any)) {
      await tx.downloadJob.update({
        where: { id },
        data: { state: 'failed', errorCode: 'UNSUPPORTED_PLATFORM', sourceUrl: null },
      });
      return null;
    }
    const photo = !!(current.sourceUrl && photoPostId(current.sourceUrl));
    try {
      if (current.sourceUrl && videoPostId(current.sourceUrl)) {
        requireVideoEnabled(l.enabledPlatforms); l = videoLimits(l);
      }
    } catch (error) {
      await tx.downloadJob.update({ where: { id }, data: { state: 'failed',
        errorCode: error instanceof AppError ? error.code : 'UNSUPPORTED_PLATFORM', sourceUrl: null } });
      return null;
    }
    if (photo) {
      try { requirePhotoEnabled(l.enabledPlatforms); }
      catch { await tx.downloadJob.update({ where: { id }, data: { state: 'failed', errorCode: 'UNSUPPORTED_PLATFORM', sourceUrl: null } }); return null; }
      l = photoLimits(l);
    }
    if (phase === 'prepare') {
      try {
        if (photo !== (current.items.length === 1 && current.items[0].kind === 'photo')) throw new AppError('FORMAT_UNAVAILABLE');
        if (photo) selectedPhoto(current.items, current.formatId || '', photoPostId(current.sourceUrl!)!);
        const prior = await tx.temporaryAsset.findUnique({ where: { jobId: id } });
        if (prior && (prior.state !== 'staging' || prior.path !== `${id}/${photo ? 'image.jpg' : 'media.mp4'}`)) throw new AppError('INVALID_ASSET_PATH');
      } catch (error) {
        await tx.downloadJob.update({ where: { id }, data: { state: 'failed', errorCode: error instanceof AppError ? error.code : 'FORMAT_UNAVAILABLE', sourceUrl: null } });
        return null;
      }
    }
    await tx.downloadJob.update({
      where: { id },
      data: {
        state: phase === 'analyze' ? 'analyzing' : 'preparing',
        workerToken: token,
        processUntil: after(15),
      },
    });
    if (phase === 'prepare')
      await tx.temporaryAsset.upsert({
        where: { jobId: id },
        create: { jobId: id, path: `${id}/${photo ? 'image.jpg' : 'media.mp4'}` },
        update: { state: 'staging' },
      });
    return current;
  });
  if (!j) return;
  try {
    if (!(await diskAvailable(l.diskStopPercent))) throw new AppError('CAPACITY_UNAVAILABLE');
    if (!j.sourceUrl) throw new AppError('JOB_EXPIRED');
    const { validateUrl } = await import('../../../packages/shared/src/core');
    validateUrl(j.sourceUrl);
    const photoId = photoPostId(j.sourceUrl);
    const selection = photoId && phase === 'prepare' ? selectedPhoto(j.items, j.formatId || '', photoId) : null;
    const data = await runAdapter(id, phase, j.sourceUrl, j.formatId, l, token);
    const photoMetadata = photoId && phase === 'analyze' ? checkedPhotoMetadata(data, photoId) : null;
    if (!photoId && data.kind && data.kind !== 'video') throw new AppError('FORMAT_UNAVAILABLE');
    if (selection) {
      const checked = checkedPhotoFile(data, selection, l);
      const handle = await open(filePath(`${id}/image.jpg`), constants.O_RDONLY | constants.O_NOFOLLOW);
      try {
        const st = await handle.stat();
        if (!st.isFile() || st.size !== checked.size) throw new AppError('INVALID_ASSET_PATH');
        const hash = createHash('sha256');
        for await (const chunk of handle.createReadStream({ autoClose: false })) hash.update(chunk);
        if (hash.digest('hex') !== checked.sha256) throw new AppError('FORMAT_UNAVAILABLE');
      } finally { await handle.close(); }
    }
    await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const current = await tx.downloadJob.findUniqueOrThrow({ where: { id }, include: { items: true } });
      if (current.workerToken !== token || current.cancelRequested || ownerExpired(current))
        throw new AppError('JOB_EXPIRED');
      if (phase === 'analyze') {
        const acceptedAt = new Date();
        const expiresAt = metadataDeadline(acceptedAt, data.sourceExpiresAt);
        if (expiresAt <= acceptedAt) throw new AppError('JOB_EXPIRED');
        await tx.mediaItem.create({ data: { jobId: id, kind: photoMetadata ? 'photo' : 'video', formats: photoMetadata ? photoMetadata.formats : data.formats } });
        await tx.downloadJob.update({
          where: { id },
          data: {
            state: 'selectable',
            title: photoMetadata ? photoMetadata.title : data.title,
            duration: photoMetadata ? null : data.duration,
            metadataAcceptedAt: acceptedAt,
            metadataExpiresAt: expiresAt,
            workerToken: null,
            processUntil: null,
          },
        });
      } else {
        if (selection) {
          requirePhotoEnabled(l.enabledPlatforms);
          const stored = selectedPhoto(current.items, current.formatId || '', photoId!);
          if (JSON.stringify(stored) !== JSON.stringify(selection)) throw new AppError('FORMAT_UNAVAILABLE');
        }
        if (
          data.file !== (selection ? 'image.jpg' : 'media.mp4') ||
          !Number.isSafeInteger(data.size) ||
          data.size <= 0 ||
          data.size > l.maxBytes
        )
          throw new AppError('LIMIT_EXCEEDED');
        await tx.temporaryAsset.update({
          where: { jobId: id },
          data: { state: 'available', size: BigInt(data.size), readyUntil: after(l.readyTtl) },
        });
        await tx.downloadJob.update({
          where: { id },
          data: { state: 'ready', sourceUrl: null, workerToken: null, processUntil: null },
        });
      }
    });
    await db.auditLog
      .create({
        data: {
          actor: 'worker',
          action: 'worker.metrics',
          detail: {
            id,
            platform: j.platform,
            phase,
            result: 'complete',
            workerMs: Date.now() - started,
            inputBytes: data.inputBytes || 0,
          },
        },
      })
      .catch(() => console.error('{"event":"metrics_failed"}'));
    console.log(
      JSON.stringify({
        event: 'worker_complete',
        id,
        phase,
        inputBytes: data.inputBytes || 0,
        workerMs: Date.now() - started,
      }),
    );
  } catch (e) {
    if (e instanceof ProcessGroupUnconfirmed) {
      await db.downloadJob.updateMany({ where: { id, workerToken: token }, data: { errorCode: e.code } });
      console.error(JSON.stringify({ event: 'worker_group_unconfirmed', id, phase, code: e.code }));
      return; // Quarantine the job; never clear guards or delete a potentially live group's files.
    }
    const code = e instanceof AppError ? e.code : 'WORKER_INTERRUPTED';
    const clean = await db.$transaction(async (tx) => {
      await lockJob(tx, id);
      const current = await tx.downloadJob.findUnique({ where: { id } });
      if (current?.workerToken !== token) return false;
      await tx.downloadJob.update({
        where: { id },
        data: {
          state: current.cancelRequested
            ? 'cancelled'
            : code === 'JOB_EXPIRED'
              ? 'expired'
              : 'failed',
          errorCode: code,
          sourceUrl: null,
          workerToken: null,
          processUntil: null,
        },
      });
      return true;
    });
    if (clean) await rm(filePath(id), { recursive: true, force: true });
    console.log(
      JSON.stringify({ event: 'worker_failed', id, phase, code, workerMs: Date.now() - started }),
    );
  }
}
