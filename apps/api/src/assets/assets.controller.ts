import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AssetsService } from './assets.service';
import { CompleteUploadDto, OrderDto, UploadUrlDto } from './dto/asset.dto';

@Controller('assets')
@UseGuards(JwtAuthGuard)
export class AssetsController {
  constructor(private readonly assets: AssetsService) {}

  @Post('upload-url')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async uploadUrl(@CurrentUser() user: AuthUser, @Body() dto: UploadUrlDto) {
    return { success: true, data: await this.assets.createUploadUrl(user.id, dto) };
  }

  @Post('complete')
  @HttpCode(200)
  async complete(@CurrentUser() user: AuthUser, @Body() dto: CompleteUploadDto) {
    return { success: true, data: await this.assets.complete(user.id, dto.assetId) };
  }

  @Get()
  async list(@CurrentUser() user: AuthUser, @Query('surpriseId', ParseUUIDPipe) surpriseId: string) {
    return { success: true, data: await this.assets.list(user.id, surpriseId) };
  }

  @Delete(':id')
  @HttpCode(200)
  async remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.assets.remove(user.id, id);
    return { success: true, data: null };
  }

  @Patch(':id/order')
  async order(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: OrderDto) {
    return { success: true, data: await this.assets.setOrder(user.id, id, dto.sortOrder) };
  }
}
