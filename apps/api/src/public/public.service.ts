import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { SurpriseStatus, Visibility } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageProvider } from '../storage/storage.provider';
import type { PublishedSnapshot } from '../surprises/published-snapshot';
import { toPublicSurprise } from './public-surprise';

/** nanoid's alphabet. Rejecting anything else up front avoids pointless database lookups. */
const SLUG_PATTERN = /^[A-Za-z0-9_-]{6,32}$/;

@Injectable()
export class PublicService {
  private readonly logger = new Logger(PublicService.name);

  constructor(private readonly prisma: PrismaService, private readonly storage: StorageProvider) {}

  async getBySlug(slug: string) {
    const row = SLUG_PATTERN.test(slug)
      ? await this.prisma.surprise.findUnique({
          where: { slug },
          select: { status: true, visibility: true, publishedAt: true, publishedSnapshot: true },
        })
      : null;

    // Unpublished, deleted, private, malformed and nonexistent all look identical on purpose, so
    // the endpoint cannot be used to find out which slugs exist.
    const visible = row && row.status === SurpriseStatus.PUBLISHED && row.visibility === Visibility.UNLISTED;
    let dto: ReturnType<typeof toPublicSurprise> = null;
    if (visible) {
      try {
        dto = toPublicSurprise(slug, row.publishedSnapshot as unknown as PublishedSnapshot | null, row.publishedAt, (k) =>
          this.storage.publicUrl(k),
        );
      } catch (err) {
        // A damaged snapshot should read as "not available" to the recipient, but be visible to us.
        this.logger.error(`Unrenderable snapshot for slug ${slug}: ${err instanceof Error ? err.message : String(err)}`);
      }
    }
    if (!dto) throw new NotFoundException({ code: 'SURPRISE_NOT_FOUND', message: 'This surprise is not available' });
    return dto;
  }
}
