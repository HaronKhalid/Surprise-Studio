import { Controller, Get, Header, Param } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PublicService } from './public.service';

/** No authentication: recipients just open a link. */
@Controller('public')
export class PublicController {
  constructor(private readonly publicSurprises: PublicService) {}

  @Get('surprises/:slug')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  // Unpublishing or deleting must take effect immediately, so no shared caching of this response.
  @Header('Cache-Control', 'no-store')
  @Header('X-Robots-Tag', 'noindex, nofollow')
  async get(@Param('slug') slug: string) {
    return { success: true, data: await this.publicSurprises.getBySlug(slug.slice(0, 64)) };
  }

  /** The creator's draft preview, authorised by a short-lived signed token instead of a login. */
  @Get('previews/:token')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Header('Cache-Control', 'no-store')
  @Header('X-Robots-Tag', 'noindex, nofollow')
  async preview(@Param('token') token: string) {
    return { success: true, data: await this.publicSurprises.getPreview(token.slice(0, 1000)) };
  }
}
