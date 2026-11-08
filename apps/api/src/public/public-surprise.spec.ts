import type { PublishedSnapshot } from '../surprises/published-snapshot';
import type { TemplateConfig } from '../templates/template-config';
import { sanitizeContent, toPublicSurprise } from './public-surprise';

const config: TemplateConfig = {
  schemaVersion: 1,
  displayOrder: 1,
  description: 'test',
  sections: [
    { type: 'hero', required: true, props: { eyebrow: 'Hi' } },
    { type: 'photo_gallery', required: true, props: { layout: 'grid' } },
    { type: 'message', required: true },
    { type: 'footer', required: true },
  ],
  theme: { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: '#d4af37' }, font: 'playfair' },
  customizable: { colors: ['accent'], fonts: ['playfair', 'inter'] },
  limits: { minPhotos: 1, maxMemories: 6 },
};

const snapshot = (over: Record<string, unknown> = {}): PublishedSnapshot =>
  ({
    occasion: 'birthday',
    recipient: { name: 'Sara', nickname: 'Saru', relationship: 'best_friend' },
    message: 'Happy birthday!',
    content: { intro: 'Hello', ending: 'Bye', memories: [{ title: 'Beach', text: 'That day' }] },
    theme: { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: '#ffaa00' }, font: 'inter' },
    template: { slug: 'cinematic', version: 1, configuration: config },
    assets: [{ storageKey: 'assets/s1/a1', width: 800, height: 600 }],
    ...over,
  }) as PublishedSnapshot;

const url = (k: string) => `https://cdn.example.com/${k}`;
const build = (s: PublishedSnapshot | null = snapshot()) => toPublicSurprise('abc123XYZ_', s, new Date('2026-01-02T03:04:05Z'), url);

describe('toPublicSurprise', () => {
  it('builds the public view from the snapshot', () => {
    const dto = build()!;
    expect(dto.slug).toBe('abc123XYZ_');
    expect(dto.recipient).toEqual({ name: 'Sara', nickname: 'Saru' });
    expect(dto.message).toBe('Happy birthday!');
    expect(dto.theme.colors.accent).toBe('#ffaa00');
    expect(dto.template).toMatchObject({ slug: 'cinematic', version: 1 });
    expect(dto.template.sections.map((s) => s.type)).toEqual(['hero', 'photo_gallery', 'message', 'footer']);
    expect(dto.publishedAt).toBe('2026-01-02T03:04:05.000Z');
  });

  it('turns storage keys into public URLs for each variant, with dimensions', () => {
    expect(build()!.photos).toEqual([
      {
        width: 800,
        height: 600,
        urls: {
          thumb: 'https://cdn.example.com/assets/s1/a1/thumb.webp',
          medium: 'https://cdn.example.com/assets/s1/a1/medium.webp',
          large: 'https://cdn.example.com/assets/s1/a1/large.webp',
        },
      },
    ]);
  });

  it('never exposes internals: storage keys, relationship, config, ids', () => {
    const json = JSON.stringify(build());
    for (const secret of ['storageKey', 'assets/s1/a1"', 'relationship', 'best_friend', 'configuration', 'userId', 'email', 'customizable', 'limits']) {
      expect(json).not.toContain(secret);
    }
  });

  it('falls back to template defaults when the stored theme is malformed or tampered with', () => {
    const tampered = [
      { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: 'red;}body{display:none' }, font: 'inter' },
      { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: 'url(https://evil.example)' }, font: 'inter' },
      { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: '#ffaa00' }, font: '"; alert(1)' },
      { colors: { background: '#0b1020' }, font: 'inter' },
      'dark',
      null,
    ];
    for (const theme of tampered) {
      expect(build(snapshot({ theme }))!.theme).toEqual(config.theme);
    }
  });

  it.each([
    ['no snapshot', null],
    ['no template', snapshot({ template: undefined })],
    ['template without sections', snapshot({ template: { slug: 'x', version: 1, configuration: { ...config, sections: [] } } })],
    ['blank recipient name', snapshot({ recipient: { name: '   ', nickname: null, relationship: null } })],
    ['no recipient', snapshot({ recipient: undefined })],
  ])('returns null (not renderable) for %s', (_label, s) => {
    expect(build(s as PublishedSnapshot | null)).toBeNull();
  });

  it('drops unknown section types and non-primitive props', () => {
    const dirty = { ...config, sections: [{ type: 'script', required: true }, { type: 'hero', required: true, props: { eyebrow: 'ok', evil: { a: 1 }, n: 3 } }, ...config.sections.slice(1)] };
    const dto = build(snapshot({ template: { slug: 'x', version: 1, configuration: dirty } }))!;
    expect(dto.template.sections.map((s) => s.type)).toEqual(['hero', 'photo_gallery', 'message', 'footer']);
    expect(dto.template.sections[0].props).toEqual({ eyebrow: 'ok', n: 3 });
  });

  it('skips photos without a storage key and tolerates bad dimensions', () => {
    const dto = build(snapshot({ assets: [{ storageKey: '', width: 1, height: 1 }, { storageKey: 'assets/s1/a2', width: -5, height: 'x' }, null] }))!;
    expect(dto.photos).toHaveLength(1);
    expect(dto.photos[0]).toMatchObject({ width: null, height: null });
  });

  it('caps photos at 10', () => {
    const assets = Array.from({ length: 15 }, (_, i) => ({ storageKey: `assets/s/${i}`, width: 100, height: 100 }));
    expect(build(snapshot({ assets }))!.photos).toHaveLength(10);
  });

  it('uses null for a missing nickname/message and "birthday" for a missing occasion', () => {
    const dto = build(snapshot({ occasion: '', message: null, recipient: { name: 'Sara', nickname: '', relationship: null } }))!;
    expect(dto).toMatchObject({ occasion: 'birthday', message: null, recipient: { name: 'Sara', nickname: null } });
  });
});

describe('sanitizeContent', () => {
  it('keeps well-formed content', () => {
    expect(sanitizeContent({ intro: 'a', ending: 'b', memories: [{ title: 't', text: 'x' }, { text: 'y' }] })).toEqual({
      intro: 'a',
      ending: 'b',
      memories: [{ title: 't', text: 'x' }, { text: 'y' }],
    });
  });

  it.each([null, undefined, 'str', 5, [], {}])('returns empty content for %p', (raw) => {
    expect(sanitizeContent(raw)).toEqual({ memories: [] });
  });

  it('drops unknown keys, blank and non-string values, and memories without text', () => {
    const out = sanitizeContent({
      intro: '   ',
      ending: 42,
      script: '<script>',
      memories: [{ title: 'only a title' }, { text: '' }, { text: 7 }, 'str', null, { text: 'ok', extra: 1 }],
    });
    expect(out).toEqual({ memories: [{ text: 'ok' }] });
  });

  it('enforces the write-time length and count limits', () => {
    const out = sanitizeContent({
      intro: 'i'.repeat(400),
      ending: 'e'.repeat(700),
      memories: Array.from({ length: 15 }, () => ({ title: 't'.repeat(100), text: 'm'.repeat(600) })),
    });
    expect(out.intro).toHaveLength(300);
    expect(out.ending).toHaveLength(600);
    expect(out.memories).toHaveLength(10);
    expect(out.memories[0].title).toHaveLength(80);
    expect(out.memories[0].text).toHaveLength(500);
  });
});
