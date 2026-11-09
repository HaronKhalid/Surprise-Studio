import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateSurpriseDto, UpdateSurpriseDto } from './dto/surprise.dto';
import { SurprisesService } from './surprises.service';

@Controller('surprises')
@UseGuards(JwtAuthGuard)
export class SurprisesController {
  constructor(private readonly surprises: SurprisesService) {}

  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateSurpriseDto) {
    return { success: true, data: await this.surprises.create(user.id, dto) };
  }

  @Get()
  async list(@CurrentUser() user: AuthUser) {
    return { success: true, data: await this.surprises.list(user.id) };
  }

  @Get(':id')
  async get(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return { success: true, data: await this.surprises.get(user.id, id) };
  }

  @Patch(':id')
  async update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateSurpriseDto) {
    return { success: true, data: await this.surprises.update(user.id, id, dto) };
  }

  @Delete(':id')
  @HttpCode(200)
  async remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.surprises.remove(user.id, id);
    return { success: true, data: null };
  }

  @Post(':id/publish')
  @HttpCode(200)
  async publish(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return { success: true, data: await this.surprises.publish(user.id, id) };
  }

  @Post(':id/preview')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async preview(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return { success: true, data: await this.surprises.createPreviewToken(user.id, id) };
  }

  @Post(':id/unpublish')
  @HttpCode(200)
  async unpublish(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return { success: true, data: await this.surprises.unpublish(user.id, id) };
  }
}
