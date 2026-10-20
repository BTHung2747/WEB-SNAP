import { Body, Controller, Delete, Get, Inject, Param, Post, Put, Req, Res } from '@nestjs/common';
import { ApiBody, ApiTags } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { AdminService } from '../services/admin.service';
@ApiTags('admin')
@Controller('api/v1/admin')
export class AdminController {
  constructor(@Inject(AdminService) private readonly service: AdminService) {}
  @Post('login')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['email', 'password'],
      properties: {
        email: { type: 'string', format: 'email' },
        password: { type: 'string', minLength: 12 },
      },
    },
  })
  async login(
    @Req()
    req: Request,
    @Body()
    body: any,
    @Res()
    res: Response,
  ) {
    return this.service.login(req, body, res);
  }
  @Post('logout')
  async logout(
    @Req()
    req: Request,
    @Res()
    res: Response,
  ) {
    return this.service.logout(req, res);
  }
  @Get('dashboard')
  async dashboard(
    @Req()
    req: Request,
  ) {
    return this.service.dashboard(req);
  }
  @Get('settings')
  // Existing settings route is unchanged; statistics has its own payload.
  async settings(
    @Req()
    req: Request,
  ) {
    return this.service.settings(req);
  }
  @Get('ad-statistics')
  async adStatistics(@Req() req: Request) {
    return this.service.adStatistics(req);
  }
  @Put('settings')
  @ApiBody({
    schema: {
      type: 'object',
      description: 'Limits object; see docs/API.md for exact bounded fields',
    },
  })
  async saveSettings(
    @Req()
    req: Request,
    @Body()
    body: any,
  ) {
    return this.service.saveSettings(req, body);
  }
  @Get('campaigns')
  async campaigns(
    @Req()
    req: Request,
  ) {
    return this.service.campaigns(req);
  }
  @Post('campaigns')
  @ApiBody({
    schema: {
      type: 'object',
      required: [
        'title',
        'targetUrl',
        'startsAt',
        'endsAt',
        'weight',
        'enabled',
        'placement',
        'linkType',
      ],
      properties: {
        title: { type: 'string' },
        imageUrl: { type: 'string', nullable: true },
        targetUrl: { type: 'string', format: 'uri' },
        startsAt: { type: 'string', format: 'date-time' },
        endsAt: { type: 'string', format: 'date-time' },
        weight: { type: 'integer' },
        enabled: { type: 'boolean' },
        placement: { enum: ['banner', 'sponsor'] },
        linkType: { enum: ['sponsored', 'affiliate'] },
      },
    },
  })
  async createCampaign(
    @Req()
    req: Request,
    @Body()
    body: any,
  ) {
    return this.service.createCampaign(req, body);
  }
  @Put('campaigns/:id')
  async updateCampaign(
    @Req()
    req: Request,
    @Param('id')
    id: string,
    @Body()
    body: any,
  ) {
    return this.service.updateCampaign(req, id, body);
  }
  @Delete('campaigns/:id')
  async deleteCampaign(
    @Req()
    req: Request,
    @Param('id')
    id: string,
  ) {
    return this.service.deleteCampaign(req, id);
  }
}
