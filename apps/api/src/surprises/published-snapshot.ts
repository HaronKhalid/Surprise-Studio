import type { ResolvedTheme, TemplateConfig } from '../templates/template-config';

/**
 * What `publish` freezes into `Surprise.publishedSnapshot`. The public endpoint serves only this,
 * never the live draft, so editing a draft cannot change a page that has already been shared.
 */
export interface PublishedSnapshot {
  occasion: string;
  recipient: { name: string; nickname: string | null; relationship: string | null };
  message: string | null;
  content: unknown;
  theme: ResolvedTheme;
  template: { slug: string; version: number; configuration: TemplateConfig };
  assets: { storageKey: string; width: number | null; height: number | null }[];
}
