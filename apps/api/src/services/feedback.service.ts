import { Injectable } from '@nestjs/common';
import { Request } from 'express';
import { Prisma } from '@prisma/client';
import { db, fail, rate } from '../../../../packages/shared/src/core';
import { admin, csrf, sign } from '../auth/session';
import { clientIp } from '../security/client-ip';
import { ratePolicy } from '../security/rate-policy';
import { feedbackCapacity, feedbackDays, feedbackId, feedbackInput, feedbackPageSize, feedbackQuery, feedbackUpdate } from './feedback-contract';

function checked<T>(schema: {safeParse(value: unknown): {success: true; data: T} | {success: false}}, value: unknown): T {
  const parsed = schema.safeParse(value);
  if (!parsed.success) fail('FEEDBACK_INVALID');
  return parsed.data;
}
const cutoff = () => new Date(Date.now() - feedbackDays * 86400000);
async function prune(tx: Prisma.TransactionClient) {
  // One fixed transaction lock serializes count+insert, including across API replicas.
  // Cast away PostgreSQL void: Prisma does not deserialize the raw void type.
  await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(711030001)`;
  await tx.feedback.deleteMany({where: {createdAt: {lt: cutoff()}}});
}
@Injectable()
export class FeedbackService {
  async submit(req: Request, body: unknown) {
    const session = await csrf(req);
    await rate('feedback:session:' + session.id, ratePolicy.feedbackSession.max, ratePolicy.feedbackSession.seconds);
    // Keyed identity exists only in an expiring Redis bucket; no IP/session FK in the letter.
    await rate('feedback:ip:' + sign('feedback-ip:' + clientIp(req)), ratePolicy.feedbackIp.max, ratePolicy.feedbackIp.seconds);
    const input = checked(feedbackInput, body);
    const record = await db.$transaction(async tx => {
      await prune(tx);
      if (await tx.feedback.count() >= feedbackCapacity) fail('FEEDBACK_FULL', 503);
      return tx.feedback.create({data: {...input, name: input.name || null, email: input.email || null}, select: {id: true}});
    });
    return {received: true, id: record.id};
  }
  async list(req: Request) {
    await admin(req);
    const query = checked(feedbackQuery, req.query);
    return db.$transaction(async tx => {
      await prune(tx);
      const where = query.status ? {status: query.status} : {};
      const total = await tx.feedback.count({where});
      const pages = Math.max(1, Math.ceil(total / feedbackPageSize));
      const page = Math.min(query.page || 1, pages);
      const items = await tx.feedback.findMany({where, skip: (page - 1) * feedbackPageSize, take: feedbackPageSize,
        orderBy: [{createdAt: 'desc'}, {id: 'desc'}],
        select: {id: true, kind: true, subject: true, name: true, status: true, createdAt: true}});
      return {items, page, pages, total, pageSize: feedbackPageSize};
    });
  }
  async detail(req: Request, value: unknown) {
    await admin(req);
    const id = checked(feedbackId, value);
    const record = await db.feedback.findFirst({where: {id, createdAt: {gte: cutoff()}}});
    if (!record) fail('FEEDBACK_NOT_FOUND', 404);
    return record;
  }
  async update(req: Request, value: unknown, body: unknown) {
    await admin(req, true);
    const id = checked(feedbackId, value), data = checked(feedbackUpdate, body);
    const result = await db.feedback.updateMany({where: {id, createdAt: {gte: cutoff()}}, data});
    if (result.count !== 1) fail('FEEDBACK_NOT_FOUND', 404);
    return {ok: true};
  }
  async remove(req: Request, value: unknown) {
    await admin(req, true);
    const id = checked(feedbackId, value);
    const result = await db.feedback.deleteMany({where: {id}});
    if (result.count !== 1) fail('FEEDBACK_NOT_FOUND', 404);
    return {ok: true};
  }
}
