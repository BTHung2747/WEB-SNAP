import { Body, Controller, Get, Inject, Param, Post, Req, Res } from '@nestjs/common';
import { ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { JobsService } from '../services/jobs.service';
@ApiTags('public')
@Controller('api/v1')
export class JobsController {
  constructor(@Inject(JobsService) private readonly service: JobsService) {}
  @Post('jobs/analyze')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['url'],
      properties: { url: { type: 'string', format: 'uri' } },
    },
  })
  @ApiOperation({ summary: 'Tạo tác vụ phân tích; 202, thuộc phiên, không tải sẵn media' })
  async analyze(
    @Req()
    req: Request,
    @Body()
    body: any,
    @Res()
    res: Response,
  ) {
    return this.service.analyze(req, body, res);
  }
  @Get('jobs/:id')
  async status(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.status(req, id);
  }
  @Get('jobs/:id/preview')
  async preview(
    @Req()
    req: Request,
    @Param('id')
    id: string,
    @Res()
    res: Response,
  ) {
    return this.service.preview(req, id, res);
  }
  @Get('jobs/:id/preview/:formatId')
  async photoPreview(@Req() req: Request, @Param('id') id: string, @Param('formatId') formatId: string, @Res() res: Response) {
    return this.service.preview(req,id,res,formatId);
  }
  @Post('jobs/:id/prepare')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['itemId', 'formatId', 'idempotencyKey'],
      properties: {
        itemId: { type: 'string', format: 'uuid' },
        formatId: { type: 'string' },
        idempotencyKey: { type: 'string', format: 'uuid' },
      },
    },
  })
  async prepare(
    @Req()
    req: Request,
    @Param('id')
    id: string,
    @Body()
    body: any,
    @Res()
    res: Response,
  ) {
    return this.service.prepare(req, id, body, res);
  }
  @Post('jobs/:id/heartbeat')
  async heartbeat(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.heartbeat(req, id);
  }
  @Post('jobs/:id/release')
  async release(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.release(req, id);
  }
  @Post('jobs/:id/cancel')
  async cancel(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.cancel(req, id);
  }
  @Post('jobs/:id/download-ticket')
  async ticket(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.ticket(req, id);
  }
}
