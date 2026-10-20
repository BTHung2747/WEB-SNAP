import { Controller, Get, Inject, Param, Req, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { DownloadsService } from '../services/downloads.service';
@ApiTags('public')
@Controller('api/v1')
export class DownloadsController {
  constructor(@Inject(DownloadsService) private readonly service: DownloadsService) {}
  @Get('downloads/:ticket')
  @ApiOperation({ summary: 'MP4 qua máy chủ; Range 206/416; tạo transfer lease trước mở tệp' })
  async download(
    @Req()
    req: Request,
    @Param('ticket')
    token: string,
    @Res()
    res: Response,
  ) {
    return this.service.download(req, token, res);
  }
}
