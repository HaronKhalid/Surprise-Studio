import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Surprise, SurpriseStatus } from '@prisma/client';
import { nanoid } from 'nanoid';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSurpriseDto, UpdateSurpriseDto } from './dto/surprise.dto';

const SLUG_LENGTH = 10;

@Injectable()
export class SurprisesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateSurpriseDto) {
    if (dto.templateId) await this.assertTemplate(dto.templateId);
    return this.prisma.surprise.create({
      data: {
        ...this.toData(dto),
        userId,
        recipientName: dto.recipientName,
      },
    });
  }

  list(userId: string) {
    return this.prisma.surprise.findMany({
      where: { userId, status: { not: SurpriseStatus.DELETED } },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async get(userId: string, id: string) {
    return this.findOwned(userId, id, true);
  }

  async update(userId: string, id: string, dto: UpdateSurpriseDto) {
    await this.findOwned(userId, id);
    if (dto.templateId) await this.assertTemplate(dto.templateId);
    return this.prisma.surprise.update({ where: { id }, data: this.toData(dto) });
  }

  /** Soft delete: the public link stops working immediately. */
  async remove(userId: string, id: string) {
    await this.findOwned(userId, id);
    await this.prisma.surprise.update({
      where: { id },
      data: { status: SurpriseStatus.DELETED, publishedSnapshot: Prisma.DbNull },
    });
  }

  /** Freezes the current draft into publishedSnapshot. Calling again republishes (same URL). */
  async publish(userId: string, id: string) {
    const s = await this.findOwned(userId, id, true);
    if (!s.templateId || !s.template) {
      throw new BadRequestException({ code: 'TEMPLATE_REQUIRED', message: 'Choose a template before publishing' });
    }
    const assets = s.assets.filter((a) => a.confirmed);
    const snapshot = {
      occasion: s.occasion,
      recipient: { name: s.recipientName, nickname: s.recipientNickname, relationship: s.relationship },
      message: s.message,
      content: s.content,
      theme: s.theme,
      template: { slug: s.template.slug, version: s.template.version, configuration: s.template.configuration },
      assets: assets.map((a) => ({ storageKey: a.storageKey, width: a.width, height: a.height })),
    };

    const slug = s.slug ?? (await this.uniqueSlug());
    return this.prisma.surprise.update({
      where: { id },
      data: {
        slug,
        status: SurpriseStatus.PUBLISHED,
        publishedAt: new Date(),
        publishedSnapshot: snapshot as Prisma.InputJsonValue,
      },
    });
  }

  /** Back to draft; the slug is kept so republishing restores the same link. */
  async unpublish(userId: string, id: string) {
    await this.findOwned(userId, id);
    return this.prisma.surprise.update({
      where: { id },
      data: { status: SurpriseStatus.DRAFT, publishedSnapshot: Prisma.DbNull },
    });
  }

  private async findOwned(userId: string, id: string, withRelations = false) {
    const s = await this.prisma.surprise.findUnique({
      where: { id },
      include: withRelations ? { template: true, assets: { orderBy: { sortOrder: 'asc' } } } : undefined,
    });
    if (!s || s.status === SurpriseStatus.DELETED) {
      throw new NotFoundException({ code: 'SURPRISE_NOT_FOUND', message: 'Surprise not found' });
    }
    if (s.userId !== userId) {
      throw new ForbiddenException({ code: 'FORBIDDEN', message: 'You do not have access to this surprise' });
    }
    return s as Surprise & {
      template: Awaited<ReturnType<PrismaService['template']['findUnique']>>;
      assets: Awaited<ReturnType<PrismaService['asset']['findMany']>>;
    };
  }

  private async assertTemplate(templateId: string) {
    const t = await this.prisma.template.findUnique({ where: { id: templateId } });
    if (!t || !t.isActive) {
      throw new BadRequestException({ code: 'TEMPLATE_NOT_FOUND', message: 'Template not found' });
    }
  }

  private async uniqueSlug(): Promise<string> {
    for (let i = 0; i < 5; i++) {
      const slug = nanoid(SLUG_LENGTH);
      if (!(await this.prisma.surprise.findUnique({ where: { slug } }))) return slug;
    }
    throw new Error('Could not generate a unique slug');
  }

  private toData(dto: CreateSurpriseDto | UpdateSurpriseDto) {
    const { content, theme, ...rest } = dto;
    return {
      ...rest,
      ...(content !== undefined && { content: content as Prisma.InputJsonValue }),
      ...(theme !== undefined && { theme: theme as Prisma.InputJsonValue }),
    };
  }
}
