import { Body, Controller, Delete, Get, HttpCode, Inject, Param, Post, Put, Req } from '@nestjs/common';
import { ApiBody, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { FeedbackService } from '../services/feedback.service';
@ApiTags('feedback')
@Controller('api/v1')
export class FeedbackController {
  constructor(@Inject(FeedbackService) private readonly service: FeedbackService) {}
  @Post('feedback') @HttpCode(201)
  @ApiBody({schema: {type:'object', additionalProperties:false, required:['kind','subject','message'], properties:{kind:{type:'string',enum:['feedback','bug','idea']},subject:{type:'string',minLength:1,maxLength:120},message:{type:'string',minLength:1,maxLength:4000},name:{type:'string',maxLength:80},email:{type:'string',maxLength:254}}}})
  submit(@Req() req: Request, @Body() body: unknown) {return this.service.submit(req, body);}
  @Get('admin/feedback') list(@Req() req: Request) {return this.service.list(req);}
  @Get('admin/feedback/:id') detail(@Req() req: Request, @Param('id') id: string) {return this.service.detail(req, id);}
  @Put('admin/feedback/:id')
  @ApiBody({schema:{type:'object',additionalProperties:false,required:['status'],properties:{status:{type:'string',enum:['unread','read','resolved']}}}})
  update(@Req() req: Request, @Param('id') id: string, @Body() body: unknown) {return this.service.update(req, id, body);}
  @Delete('admin/feedback/:id') @HttpCode(200) remove(@Req() req: Request, @Param('id') id: string) {return this.service.remove(req, id);}
}
