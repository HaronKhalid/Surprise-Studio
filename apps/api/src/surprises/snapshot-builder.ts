import { resolveTheme, TemplateConfig } from '../templates/template-config';
import type { PublishedSnapshot } from './published-snapshot';

/** The parts of a surprise (draft or otherwise) that make up what a recipient sees. */
export interface SnapshotSource {
  occasion: string;
  recipientName: string;
  recipientNickname: string | null;
  relationship: string | null;
  message: string | null;
  content: unknown;
  theme: unknown;
  template: { slug: string; version: number; configuration: unknown };
  /** In display order. Unconfirmed uploads are ignored. */
  assets: { storageKey: string; width: number | null; height: number | null; confirmed: boolean }[];
}

/**
 * The single place that turns a surprise into what the renderer receives. Publishing freezes the
 * result; previewing renders it live from the draft. Sharing this function is what guarantees the
 * preview shows exactly what publishing would produce.
 */
export function buildSnapshot(s: SnapshotSource): PublishedSnapshot {
  const config = s.template.configuration as TemplateConfig;
  return {
    occasion: s.occasion,
    recipient: { name: s.recipientName, nickname: s.recipientNickname, relationship: s.relationship },
    message: s.message,
    content: s.content,
    // Fully resolved tokens, so the renderer never has to merge or trust raw overrides.
    theme: resolveTheme(config, s.theme),
    template: { slug: s.template.slug, version: s.template.version, configuration: config },
    assets: s.assets.filter((a) => a.confirmed).map((a) => ({ storageKey: a.storageKey, width: a.width, height: a.height })),
  };
}
