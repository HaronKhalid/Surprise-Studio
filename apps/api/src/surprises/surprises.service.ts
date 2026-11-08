import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Surprise, SurpriseStatus } from '@prisma/client';
import { nanoid } from 'nanoid';
import { PrismaService } from '../prisma/prisma.service';
import { checkPublishRequirements, checkTheme, resolveTheme, TemplateConfig } from '../templates/template-config';
import { TemplateRecord, TemplatesService } from '../templates/templates.service';
import { CreateSurpriseDto, UpdateSurpriseDto } from './dto/surprise.dto';
import type { PublishedSnapshot } from './published-snapshot';

const SLUG_LENGTH = 10;

/** Client-editable columns. Create-typed values are also valid for updates. */
type SurpriseFields = Partial<
  Pick<
    Prisma.SurpriseUncheckedCreateInput,
    | 'occasion'
    | 'recipientName'
    | 'recipientNickname'
    | 'relationship'
    | 'message'
    | 'templateId'
    | 'visibility'
    | 'content'
    | 'theme'
  >
>;

@Injectable()
export class SurprisesService {
  constructor(private readonly prisma: PrismaService, private readonly templates: TemplatesService) {}

  async create(userId: string, dto: CreateSurpriseDto) {
    const template = dto.templateId ? await this.templates.getActive(dto.templateId) : null;
    this.assertCustomisation(template, dto);
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
    const current = await this.findOwned(userId, id);
    // `null` clears the template; `undefined` leaves it alone.
    const nextTemplateId = dto.templateId === undefined ? current.templateId : dto.templateId;
    const templateChanged = nextTemplateId !== current.templateId;
    let template: TemplateRecord | null = null;
    if (nextTemplateId) {
      template = templateChanged
        ? await this.templates.getActive(nextTemplateId)
        : await this.templates.findById(nextTemplateId); // keep working with a since-retired version
    }
    this.assertCustomisation(template, dto);

    const data = this.toData(dto);
    // Overrides belong to one template: switching template drops them unless new ones came along.
    if (templateChanged && dto.theme === undefined) data.theme = {};
    return this.prisma.surprise.update({ where: { id }, data });
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
    const config = s.template.configuration as unknown as TemplateConfig;
    const memories = (s.content as { memories?: unknown[] } | null)?.memories;
    const violations = checkPublishRequirements(config, {
      message: s.message,
      photoCount: assets.length,
      memoryCount: Array.isArray(memories) ? memories.length : 0,
    });
    if (violations.length) {
      throw new BadRequestException({ code: violations[0].code, message: violations.map((v) => v.message).join('; ') });
    }

    const snapshot: PublishedSnapshot = {
      occasion: s.occasion,
      recipient: { name: s.recipientName, nickname: s.recipientNickname, relationship: s.relationship },
      message: s.message,
      content: s.content,
      // Fully resolved tokens, so the renderer never has to merge or trust raw overrides.
      theme: resolveTheme(config, s.theme),
      template: { slug: s.template.slug, version: s.template.version, configuration: config },
      assets: assets.map((a) => ({ storageKey: a.storageKey, width: a.width, height: a.height })),
    };

    const slug = s.slug ?? (await this.uniqueSlug());
    return this.prisma.surprise.update({
      where: { id },
      data: {
        slug,
        status: SurpriseStatus.PUBLISHED,
        publishedAt: new Date(),
        publishedSnapshot: snapshot as unknown as Prisma.InputJsonValue,
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

  /** Theme and content are checked against the template they will be rendered with. */
  private assertCustomisation(template: TemplateRecord | null, dto: CreateSurpriseDto | UpdateSurpriseDto) {
    // Plain JSON drops the `undefined` fields that DTO class instances carry.
    const theme = dto.theme ? (JSON.parse(JSON.stringify(dto.theme)) as Record<string, unknown>) : undefined;
    if (theme && Object.keys(theme).length > 0) {
      if (!template) {
        throw new BadRequestException({ code: 'TEMPLATE_REQUIRED', message: 'Choose a template before customising its theme' });
      }
      const { violations } = checkTheme(template.configuration, theme);
      if (violations.length) {
        throw new BadRequestException({ code: violations[0].code, message: violations.map((v) => v.message).join('; ') });
      }
    }
    const memories = dto.content?.memories?.length ?? 0;
    if (template && memories > template.configuration.limits.maxMemories) {
      throw new BadRequestException({
        code: 'TOO_MANY_MEMORIES',
        message: `The ${template.name} template supports at most ${template.configuration.limits.maxMemories} memories`,
      });
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
    // DTOs are class instances; store plain JSON. `null` (clearing) becomes the column default `{}`.
    const json = (v: unknown) => JSON.parse(JSON.stringify(v ?? {})) as Prisma.InputJsonValue;
    const data: SurpriseFields = {
      ...rest,
      ...(content !== undefined && { content: json(content) }),
      ...(theme !== undefined && { theme: json(theme) }),
    };
    return data;
  }
}
