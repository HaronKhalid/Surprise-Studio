import { VARIANTS } from '../assets/image-validation';
import type { PublishedSnapshot } from '../surprises/published-snapshot';
import { sanitizeResolvedTheme, SECTION_TYPES, TemplateSection } from '../templates/template-config';
import type { ResolvedTheme } from '../templates/template-config';

/**
 * The only shape the public page ever receives. It is built field by field from the published
 * snapshot (an allowlist), so nothing else can leak: no user id or email, no database ids, no
 * storage keys, no relationship, no draft data.
 */
export interface PublicSurprise {
  slug: string;
  occasion: string;
  recipient: { name: string; nickname: string | null };
  message: string | null;
  content: { intro?: string; ending?: string; memories: { title?: string; text: string }[] };
  theme: ResolvedTheme;
  template: { slug: string; version: number; sections: TemplateSection[] };
  photos: { width: number | null; height: number | null; urls: Record<(typeof VARIANTS)[number]['name'], string> }[];
  publishedAt: string | null;
}

const MAX_MEMORIES = 10;
const MAX_PHOTOS = 10;

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const text = (v: unknown, max: number) => (typeof v === 'string' && v.trim() ? v.slice(0, max) : undefined);
const dimension = (v: unknown) => (typeof v === 'number' && Number.isInteger(v) && v > 0 ? v : null);

/** Re-applies the write-time limits on the way out, in case a snapshot is old or was tampered with. */
export function sanitizeContent(raw: unknown): PublicSurprise['content'] {
  const c = isObject(raw) ? raw : {};
  const memories: PublicSurprise['content']['memories'] = [];
  if (Array.isArray(c.memories)) {
    for (const m of c.memories.slice(0, MAX_MEMORIES)) {
      const body = isObject(m) ? text(m.text, 500) : undefined;
      if (!body) continue;
      const title = text((m as Record<string, unknown>).title, 80);
      memories.push(title ? { title, text: body } : { text: body });
    }
  }
  const intro = text(c.intro, 300);
  const ending = text(c.ending, 600);
  return { ...(intro && { intro }), ...(ending && { ending }), memories };
}

function sanitizeSections(raw: unknown): TemplateSection[] {
  if (!Array.isArray(raw)) return [];
  const sections: TemplateSection[] = [];
  for (const s of raw) {
    if (!isObject(s) || !(SECTION_TYPES as readonly string[]).includes(s.type as string)) continue;
    const props: Record<string, string | number | boolean> = {};
    if (isObject(s.props)) {
      for (const [k, v] of Object.entries(s.props)) {
        if (typeof v === 'string') props[k] = v.slice(0, 120);
        else if (typeof v === 'number' || typeof v === 'boolean') props[k] = v;
      }
    }
    sections.push({ type: s.type as TemplateSection['type'], required: s.required === true, props });
  }
  return sections;
}

/** Returns null when the snapshot is too damaged to render (the caller answers 404). */
export function toPublicSurprise(
  slug: string,
  snapshot: PublishedSnapshot | null,
  publishedAt: Date | null,
  publicUrl: (storageKey: string) => string,
): PublicSurprise | null {
  if (!snapshot || !isObject(snapshot) || !isObject(snapshot.template) || !isObject(snapshot.recipient)) return null;
  const sections = sanitizeSections(snapshot.template.configuration?.sections);
  const name = text(snapshot.recipient.name, 80);
  if (!name || sections.length === 0) return null;

  const photos = (Array.isArray(snapshot.assets) ? snapshot.assets : [])
    .filter((a) => isObject(a) && typeof a.storageKey === 'string' && a.storageKey.length > 0)
    .slice(0, MAX_PHOTOS)
    .map((a) => ({
      width: dimension(a.width),
      height: dimension(a.height),
      urls: Object.fromEntries(VARIANTS.map((v) => [v.name, publicUrl(`${a.storageKey}/${v.name}.webp`)])) as PublicSurprise['photos'][number]['urls'],
    }));

  return {
    slug,
    occasion: text(snapshot.occasion, 40) ?? 'birthday',
    recipient: { name, nickname: text(snapshot.recipient.nickname, 80) ?? null },
    message: text(snapshot.message, 5000) ?? null,
    content: sanitizeContent(snapshot.content),
    theme: sanitizeResolvedTheme(snapshot.template.configuration, snapshot.theme),
    template: {
      slug: String(snapshot.template.slug).slice(0, 60),
      version: Number.isInteger(snapshot.template.version) ? snapshot.template.version : 1,
      sections,
    },
    photos,
    publishedAt: publishedAt ? publishedAt.toISOString() : null,
  };
}
