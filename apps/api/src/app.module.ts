import { Module } from '@nestjs/common';
import { AdminController } from './controllers/admin.controller';
import { AdsController } from './controllers/ads.controller';
import { DownloadsController } from './controllers/downloads.controller';
import { JobsController } from './controllers/jobs.controller';
import { SessionController } from './controllers/session.controller';
import { AdminService } from './services/admin.service';
import { AdsService } from './services/ads.service';
import { DownloadsService } from './services/downloads.service';
import { JobsService } from './services/jobs.service';
import { SessionService } from './services/session.service';
@Module({
  controllers: [
    SessionController,
    JobsController,
    DownloadsController,
    AdsController,
    AdminController,
  ],
  providers: [SessionService, JobsService, DownloadsService, AdsService, AdminService],
})
export class AppModule {}
