import { z } from 'zod';
import { fail } from '../../../packages/shared/src/core';
export const uuid = z.string().uuid();
export const idSchema = z.object({ id: uuid });
export const inputSchema = z.object({ url: z.string().max(2048) }).strict();
export const prepareSchema = z
  .object({
    itemId: uuid,
    formatId: z
      .string()
      .max(80)
      .regex(/^[\w-]+(?:\+[\w-]+)?$/),
    idempotencyKey: uuid,
  })
  .strict();
export const loginSchema = z
  .object({ email: z.string().email().max(254), password: z.string().min(12).max(256) })
  .strict();
// Scalar strict query rejects duplicates/arrays and unknown keys from Express.
export const adStatisticsQuery = z.object({
  from: z.string().max(64).datetime({ offset: true }).optional(),
  to: z.string().max(64).datetime({ offset: true }).optional(),
}).strict().refine((q) => {
  if (q.from === undefined && q.to === undefined) return true;
  if (q.from === undefined || q.to === undefined) return false;
  const from = Date.parse(q.from), to = Date.parse(q.to);
  return Number.isFinite(from) && Number.isFinite(to) && from < to && to - from <= 90 * 86400000;
});
export const httpsUrl = z
  .string()
  .max(2048)
  .refine((v) => {
    try {
      const u = new URL(v);
      return (
        u.protocol === 'https:' &&
        !u.username &&
        !u.password &&
        !u.port &&
        !/^(localhost|127\.|\[|10\.|192\.168\.|169\.254\.)/.test(u.hostname)
      );
    } catch {
      return false;
    }
  }, 'HTTPS URL required');
export const campaignSchema = z
  .object({
    title: z.string().min(1).max(120),
    imageUrl: httpsUrl.nullable().optional(),
    targetUrl: httpsUrl,
    linkType: z.enum(['sponsored', 'affiliate']),
    placement: z.enum(['banner', 'sponsor']),
    enabled: z.boolean(),
    startsAt: z.string().datetime(),
    endsAt: z.string().datetime(),
    weight: z.number().int().min(1).max(100),
  })
  .strict()
  .refine((x) => new Date(x.startsAt) < new Date(x.endsAt));
export function parse<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) fail('INVALID_REQUEST');
  return result.data;
}
