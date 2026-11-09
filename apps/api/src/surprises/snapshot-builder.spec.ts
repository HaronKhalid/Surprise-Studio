import type { TemplateConfig } from '../templates/template-config';
import { previewSecret } from './preview-token';
import { buildSnapshot, SnapshotSource } from './snapshot-builder';

const config: TemplateConfig = {
  schemaVersion: 1,
  displayOrder: 1,
  description: 't',
  sections: [{ type: 'hero', required: true }, { type: 'footer', required: true }],
  theme: { colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: '#d4af37' }, font: 'playfair' },
  customizable: { colors: ['accent'], fonts: ['playfair', 'inter'] },
  limits: { minPhotos: 1, maxMemories: 6 },
};

const source = (over: Partial<SnapshotSource> = {}): SnapshotSource => ({
  occasion: 'birthday',
  recipientName: 'Sara',
  recipientNickname: null,
  relationship: 'friend',
  message: 'hi',
  content: { intro: 'x' },
  theme: { colors: { accent: '#ffaa00' } },
  template: { slug: 'cinematic', version: 1, configuration: config },
  assets: [
    { storageKey: 'assets/a', width: 10, height: 20, confirmed: true },
    { storageKey: 'assets/pending', width: null, height: null, confirmed: false },
    { storageKey: 'assets/b', width: 30, height: 40, confirmed: true },
  ],
  ...over,
});

describe('buildSnapshot', () => {
  it('keeps only confirmed photos, in the order given', () => {
    expect(buildSnapshot(source()).assets).toEqual([
      { storageKey: 'assets/a', width: 10, height: 20 },
      { storageKey: 'assets/b', width: 30, height: 40 },
    ]);
  });

  it('resolves the theme over the template defaults', () => {
    const t = buildSnapshot(source()).theme;
    expect(t.colors.accent).toBe('#ffaa00');
    expect(t.colors.background).toBe('#0b1020');
    expect(t.font).toBe('playfair');
  });

  it('falls back to defaults for an invalid stored theme instead of passing it through', () => {
    expect(buildSnapshot(source({ theme: { colors: { accent: 'url(x)' } } })).theme).toEqual(config.theme);
  });

  it('carries recipient, message, content and the embedded template', () => {
    const s = buildSnapshot(source());
    expect(s.recipient).toEqual({ name: 'Sara', nickname: null, relationship: 'friend' });
    expect(s.message).toBe('hi');
    expect(s.content).toEqual({ intro: 'x' });
    expect(s.template).toEqual({ slug: 'cinematic', version: 1, configuration: config });
  });

  it('is deterministic, so a preview and a publish of the same draft are identical', () => {
    expect(buildSnapshot(source())).toEqual(buildSnapshot(source()));
  });
});

describe('previewSecret', () => {
  it('is derived from, but never equal to, the access-token secret', () => {
    const jwt = 'a'.repeat(40);
    expect(previewSecret(jwt)).not.toBe(jwt);
    expect(previewSecret(jwt)).toBe(previewSecret(jwt));
    expect(previewSecret(jwt)).not.toBe(previewSecret('b'.repeat(40)));
  });
});
