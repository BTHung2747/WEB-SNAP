import { Body,Controller,Delete,Get,HttpCode,Inject,Param,Post,Put,Req,Res,UploadedFile,UseGuards,UseInterceptors } from '@nestjs/common';
import { ApiBody,ApiConsumes,ApiTags } from '@nestjs/swagger';
import { Request,Response } from 'express';
import { SupportService } from '../services/support.service';
import { SupportFile } from '../services/support-image';
import { SupportUploadGuard,SupportUploadInterceptor } from '../security/support-upload';
@ApiTags('support')
@Controller('api/v1')
export class SupportController {
 constructor(@Inject(SupportService)private readonly service:SupportService){}
 @Get('support') public(){return this.service.public();}
 @Get('support/qr/:id') image(@Req()req:Request,@Res()res:Response,@Param('id')id:string){return this.service.image(req,res,id);}
 @Get('admin/support') settings(@Req()req:Request){return this.service.settings(req);}
 @Put('admin/support') save(@Req()req:Request,@Body()body:unknown){return this.service.save(req,body);}
 @Post('admin/support/qr')
 @UseGuards(SupportUploadGuard)
 @UseInterceptors(SupportUploadInterceptor)
 @ApiConsumes('multipart/form-data')
 @ApiBody({schema:{type:'object',required:['file'],properties:{file:{type:'string',format:'binary'}}}})
 upload(@Req()req:Request,@UploadedFile()file:SupportFile){return this.service.upload(req,file);}
 @Delete('admin/support/qr') @HttpCode(200) remove(@Req()req:Request){return this.service.remove(req);}
 @Get('admin/support/qr/:id') draftImage(@Req()req:Request,@Res()res:Response,@Param('id')id:string){return this.service.image(req,res,id,true);}
}
