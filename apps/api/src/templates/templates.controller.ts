import { Controller, Get, Header, Param, Query } from '@nestjs/common';
import { TemplatesService } from './templates.service';

/** Public: templates hold no user data, and the creator app needs them before sign-in too. */
@Controller('templates')
export class TemplatesController {
  constructor(private readonly templates: TemplatesService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=300')
  async list(@Query('occasion') occasion?: string) {
    return { success: true, data: await this.templates.list(occasion?.slice(0, 40)) };
  }

  @Get(':slug')
  @Header('Cache-Control', 'public, max-age=300')
  async get(@Param('slug') slug: string) {
    return { success: true, data: await this.templates.getBySlug(slug.slice(0, 60)) };
  }
}
