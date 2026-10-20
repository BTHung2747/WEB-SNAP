import { Body, Controller, Get, Inject, Post, Req, Res } from '@nestjs/common';
import { ApiBody, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { AdsService } from '../services/ads.service';
@ApiTags('public')
@Controller('api/v1')
export class AdsController {
  constructor(@Inject(AdsService) private readonly service: AdsService) {}
  @Get('ads')
  async ads(
    @Req()
    req: Request,
    @Res()
    res: Response,
  ) {
    return this.service.ads(req, res);
  }
  @Post('ad-events')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['id', 'campaignId', 'type'],
      properties: {
        id: { type: 'string', format: 'uuid' },
        campaignId: { type: 'string', format: 'uuid' },
        type: { enum: ['impression', 'click'] },
      },
    },
  })
  async adEvent(
    @Req()
    req: Request,
    @Body()
    body: any,
  ) {
    return this.service.adEvent(req, body);
  }
}
