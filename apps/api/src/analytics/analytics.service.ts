import { Injectable } from '@nestjs/common';
import { Prisma, SurpriseStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TrackEventDto } from './analytics.dto';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Records one event. Deliberately stores no IP address, user agent or user id: the product
   * questions (do creators publish? do recipients open links?) do not need them.
   * An unknown or unpublished slug is simply not linked; the caller cannot tell the difference.
   */
  async track(dto: TrackEventDto): Promise<void> {
    let surpriseId: string | null = null;
    if (dto.slug) {
      const s = await this.prisma.surprise.findUnique({
        where: { slug: dto.slug },
        select: { id: true, status: true },
      });
      if (s && s.status === SurpriseStatus.PUBLISHED) surpriseId = s.id;
    }
    // Class instance -> plain JSON, dropping the undefined fields the instance carries.
    const metadata = dto.metadata ? (JSON.parse(JSON.stringify(dto.metadata)) as Prisma.InputJsonObject) : undefined;
    await this.prisma.event.create({
      data: { eventType: dto.eventType, surpriseId, ...(metadata && Object.keys(metadata).length ? { metadata } : {}) },
    });
  }
}
