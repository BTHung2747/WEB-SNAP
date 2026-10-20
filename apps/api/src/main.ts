import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import cookieParser from 'cookie-parser';
import { Request, Response } from 'express';
import helmet from 'helmet';
import 'reflect-metadata';
import { AppModule } from './app.module';
import { SafeErrors } from './common';
import { createOpenApiDocument } from './openapi';
import { clientIdentityMiddleware } from './security/client-ip';
async function main() {
  const app = await NestFactory.create(AppModule, { logger: ['error', 'warn'] });
  // Keep Express forwarding disabled; rate identity is verified per request.
  app.getHttpAdapter().getInstance().set('trust proxy', false);
  app.use(clientIdentityMiddleware());
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use(cookieParser());
  app.useGlobalFilters(new SafeErrors());
  const doc = createOpenApiDocument(app);
  SwaggerModule.setup('api/docs', app, doc);
  app.use((req: Request, res: Response, next: any) => {
    res.setHeader('Cache-Control', 'no-store');
    next();
  });
  await app.listen(3000, '0.0.0.0');
}
main().catch(() => {
  console.error('API_START_FAILED');
  process.exit(1);
});
