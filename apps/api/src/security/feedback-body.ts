import { json, type RequestHandler } from 'express';
import { AppError } from '../../../../packages/shared/src/core';
import { feedbackBodyBytes } from '../services/feedback-contract';
// Install before Nest init/default JSON parser. Only these new routes change.
const parse = json({limit: feedbackBodyBytes, strict: true});
export const feedbackBody: RequestHandler = (req, res, next) => {
  if (['POST', 'PUT'].includes(req.method) && !req.is('application/json')) {
    next(new AppError('FEEDBACK_INVALID', 400)); return;
  }
  parse(req, res, error => {
    if (error) next(new AppError(error.status === 413 ? 'FEEDBACK_TOO_LARGE' : 'FEEDBACK_INVALID', error.status === 413 ? 413 : 400));
    else next();
  });
};
