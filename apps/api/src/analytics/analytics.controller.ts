import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AnalyticsService } from './analytics.service';
import { TrackEventDto } from './analytics.dto';

@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  /** Unauthenticated (recipients have no account). Always 202, whatever the slug resolves to. */
  @Post('events')
  @HttpCode(202)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  async track(@Body() dto: TrackEventDto) {
    await this.analytics.track(dto);
    return { success: true, data: null };
  }
}
