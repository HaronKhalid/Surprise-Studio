import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { SurpriseStatus, Visibility } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageProvider } from '../storage/storage.provider';
import { previewSecret } from '../surprises/preview-token';
import type { PublishedSnapshot } from '../surprises/published-snapshot';
import { buildSnapshot } from '../surprises/snapshot-builder';
import { toPublicSurprise } from './public-surprise';

/** nanoid's alphabet. Rejecting anything else up front avoids pointless database lookups. */
const SLUG_PATTERN = /^[A-Za-z0-9_-]{6,32}$/;

const notAvailable = () =>
  new NotFoundException({ code: 'SURPRISE_NOT_FOUND', message: 'This surprise is not available' });

@Injectable()
export class PublicService {
  private readonly logger = new Logger(PublicService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageProvider,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

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
      dto = this.render(slug, () =>
        toPublicSurprise(slug, row.publishedSnapshot as unknown as PublishedSnapshot | null, row.publishedAt, (k) =>
          this.storage.publicUrl(k),
        ),
      );
    }
    if (!dto) throw notAvailable();
    return dto;
  }

  /**
   * Renders the *current draft* for the creator's preview. Built with the same function that
   * publishing uses, so what is previewed is what would be published. The token is minted by
   * POST /surprises/:id/preview (owner only), is scoped to one surprise and expires in 10 minutes.
   * Every failure is the same 404, whether the token is forged, expired or the surprise is gone.
   */
  async getPreview(token: string) {
    let surpriseId = '';
    try {
      const payload = await this.jwt.verifyAsync<{ sid?: unknown }>(token, {
        secret: previewSecret(this.config.getOrThrow('JWT_SECRET')),
      });
      if (typeof payload.sid === 'string') surpriseId = payload.sid;
    } catch {
      throw notAvailable();
    }

    const s = await this.prisma.surprise.findUnique({
      where: { id: surpriseId },
      include: { template: true, assets: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!s || s.status === SurpriseStatus.DELETED || !s.template) throw notAvailable();

    const dto = this.render('preview', () =>
      toPublicSurprise('preview', buildSnapshot({ ...s, template: s.template! }), null, (k) => this.storage.publicUrl(k)),
    );
    if (!dto) throw notAvailable();
    return dto;
  }

  /** A damaged snapshot should read as "not available" to the viewer, but be visible to us. */
  private render(label: string, build: () => ReturnType<typeof toPublicSurprise>) {
    try {
      return build();
    } catch (err) {
      this.logger.error(`Unrenderable surprise (${label}): ${err instanceof Error ? err.message : String(err)}`);
      return null;
    }
  }
}
