import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import { Response } from 'express';
import { AppError } from '../../../../packages/shared/src/core';
@Catch()
export class SafeErrors implements ExceptionFilter {
  catch(e: any, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) {
      res.destroy();
      return;
    }
    const status =
      e instanceof AppError ? e.status : e instanceof HttpException ? e.getStatus() : 500;
    res.status(status).json({
      error: {
        code: e instanceof AppError ? e.code : status === 404 ? 'NOT_FOUND' : 'INTERNAL_ERROR',
      },
    });
    if (status === 500)
      console.error(
        JSON.stringify({ event: 'api_error', type: e?.constructor?.name, code: e?.code }),
      );
  }
}
