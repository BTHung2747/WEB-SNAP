import { Controller, Get, Inject, Req, Res } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { SessionService } from '../services/session.service';
@ApiTags('public')
@Controller('api/v1')
export class SessionController {
  constructor(@Inject(SessionService) private readonly service: SessionService) {}
  @Get('health')
  async health() {
    return this.service.health();
  }
  @Get('session')
  async createSession(
    @Req()
    req: Request,
    @Res()
    res: Response,
  ) {
    return this.service.createSession(req, res);
  }
}
