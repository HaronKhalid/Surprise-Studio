import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Template } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { TemplateConfig } from './template-config';

export type TemplateRecord = Omit<Template, 'configuration'> & { configuration: TemplateConfig };

/** `configuration` is validated when templates are seeded, so it is trusted to match TemplateConfig. */
const toRecord = (row: Template) => row as unknown as TemplateRecord;

@Injectable()
export class TemplatesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Latest active version of every template, in display order. */
  async list(occasion?: string) {
    const rows = await this.prisma.template.findMany({
      where: { isActive: true, ...(occasion ? { occasion } : {}) },
      orderBy: [{ slug: 'asc' }, { version: 'desc' }],
    });
    const latest = new Map<string, TemplateRecord>();
    for (const row of rows) if (!latest.has(row.slug)) latest.set(row.slug, toRecord(row));
    return [...latest.values()]
      .sort((a, b) => a.configuration.displayOrder - b.configuration.displayOrder || a.slug.localeCompare(b.slug))
      .map((t) => this.present(t));
  }

  async getBySlug(slug: string) {
    const row = await this.prisma.template.findFirst({
      where: { slug, isActive: true },
      orderBy: { version: 'desc' },
    });
    if (!row) throw new NotFoundException({ code: 'TEMPLATE_NOT_FOUND', message: 'Template not found' });
    return this.present(toRecord(row));
  }

  /** A template a creator may newly choose: must exist and still be active. */
  async getActive(id: string): Promise<TemplateRecord> {
    const row = await this.prisma.template.findUnique({ where: { id } });
    if (!row || !row.isActive) {
      throw new BadRequestException({ code: 'TEMPLATE_NOT_FOUND', message: 'Template not found' });
    }
    return toRecord(row);
  }

  /** Any version, even a retired one: surprises keep rendering with the version they were built on. */
  async findById(id: string): Promise<TemplateRecord | null> {
    const row = await this.prisma.template.findUnique({ where: { id } });
    return row ? toRecord(row) : null;
  }

  private present(t: TemplateRecord) {
    return {
      id: t.id,
      slug: t.slug,
      name: t.name,
      occasion: t.occasion,
      version: t.version,
      configuration: t.configuration,
    };
  }
}
