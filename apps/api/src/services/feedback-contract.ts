import { z } from 'zod';
export const feedbackCapacity = 1000;
export const feedbackDays = 90;
export const feedbackPageSize = 20;
export const feedbackBodyBytes = 32768;
const plain = (max: number, min = 0) => z.string().trim().min(min).max(max)
  .refine(value => !/[<>\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value));
export const feedbackInput = z.object({
  kind: z.enum(['feedback', 'bug', 'idea']),
  subject: plain(120, 1), message: plain(4000, 1),
  name: plain(80).optional(),
  email: z.union([z.literal(''), z.string().trim().max(254).email()]).optional(),
}).strict();
export const feedbackStatus = z.enum(['unread', 'read', 'resolved']);
export const feedbackQuery = z.object({
  page: z.string().regex(/^[1-9]\d?$/).transform(Number).refine(n => n <= 50).optional(),
  status: feedbackStatus.optional(),
}).strict();
export const feedbackUpdate = z.object({status: feedbackStatus}).strict();
export const feedbackId = z.string().uuid();
