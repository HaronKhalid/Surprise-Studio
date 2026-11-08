import {
  checkPublishRequirements,
  checkTheme,
  contrastRatio,
  resolveTheme,
  TemplateConfig,
  validateTemplateConfig,
} from './template-config';

const base = (): TemplateConfig => ({
  schemaVersion: 1,
  displayOrder: 1,
  description: 'A test template',
  sections: [
    { type: 'hero', required: true },
    { type: 'photo_gallery', required: true, props: { layout: 'grid' } },
    { type: 'memory_cards', required: false },
    { type: 'message', required: true },
    { type: 'footer', required: true },
  ],
  theme: {
    colors: { background: '#0b1020', surface: '#151b2e', text: '#ffffff', accent: '#d4af37' },
    font: 'playfair',
  },
  customizable: { colors: ['accent'], fonts: ['playfair', 'inter'] },
  limits: { minPhotos: 1, maxMemories: 6 },
});

/** Applies a mutation to a fresh copy of the valid config and returns the validation errors. */
const errorsAfter = (mutate: (c: any) => void) => {
  const c: any = base();
  mutate(c);
  return validateTemplateConfig(c);
};

describe('contrastRatio', () => {
  it('is 21 for black on white and 1 for identical colours', () => {
    expect(contrastRatio('#000000', '#ffffff')).toBeCloseTo(21, 5);
    expect(contrastRatio('#336699', '#336699')).toBeCloseTo(1, 5);
  });
  it('is symmetric', () => {
    expect(contrastRatio('#d4af37', '#0b1020')).toBeCloseTo(contrastRatio('#0b1020', '#d4af37'), 10);
  });
});

describe('validateTemplateConfig', () => {
  it('accepts a valid configuration', () => {
    expect(validateTemplateConfig(base())).toEqual([]);
  });

  it.each([
    ['not an object', null],
    ['an array', []],
    ['a string', 'x'],
  ])('rejects %s', (_l, value) => {
    expect(validateTemplateConfig(value).length).toBeGreaterThan(0);
  });

  it.each<[string, (c: any) => void, RegExp]>([
    ['wrong schemaVersion', (c) => (c.schemaVersion = 2), /schemaVersion/],
    ['missing description', (c) => delete c.description, /description/],
    ['unknown section type', (c) => c.sections.splice(1, 0, { type: 'script', required: false }), /sections\[1\]\.type/],
    ['duplicate section', (c) => c.sections.splice(2, 0, { type: 'message', required: false }), /more than once/],
    ['first section is not hero', (c) => c.sections.reverse(), /first section/],
    ['footer not required', (c) => (c.sections[c.sections.length - 1].required = false), /footer/],
    ['non-boolean required', (c) => (c.sections[1].required = 'yes'), /required must be a boolean/],
    ['gallery without props', (c) => delete c.sections[1].props, /layout is required/],
    ['unknown gallery layout', (c) => (c.sections[1].props.layout = 'carousel'), /layout must be one of/],
    ['object-valued prop', (c) => (c.sections[0].props = { eyebrow: { x: 1 } }), /string, number or boolean/],
    ['over-long prop', (c) => (c.sections[0].props = { eyebrow: 'x'.repeat(121) }), /longer than/],
    ['bad default colour', (c) => (c.theme.colors.accent = 'gold'), /theme\.colors\.accent/],
    ['injected default colour', (c) => (c.theme.colors.accent = 'red;}body{display:none'), /theme\.colors\.accent/],
    ['unknown colour token', (c) => (c.theme.colors.shadow = '#000000'), /not a known colour token/],
    ['unknown default font', (c) => (c.theme.font = 'comic-sans'), /theme\.font/],
    ['default font not customizable', (c) => (c.customizable.fonts = ['inter']), /include the default/],
    ['unknown customizable colour', (c) => (c.customizable.colors = ['border']), /customizable\.colors/],
    ['empty font list', (c) => (c.customizable.fonts = []), /customizable\.fonts/],
    ['negative minPhotos', (c) => (c.limits.minPhotos = -1), /minPhotos/],
    ['too many memories allowed', (c) => (c.limits.maxMemories = 99), /maxMemories/],
    ['unreadable default text', (c) => (c.theme.colors.text = '#101525'), /text\/background contrast/],
    ['washed-out default accent', (c) => (c.theme.colors.accent = '#0d1224'), /accent\/background contrast/],
  ])('rejects %s', (_label, mutate, expected) => {
    expect(errorsAfter(mutate).join(' | ')).toMatch(expected);
  });
});

describe('checkTheme / resolveTheme', () => {
  const cfg = base();

  it('returns the defaults when there are no overrides', () => {
    for (const none of [undefined, null, {}]) {
      const r = checkTheme(cfg, none);
      expect(r.violations).toEqual([]);
      expect(r.theme).toEqual(cfg.theme);
    }
  });

  it('applies allowed overrides and normalises hex to lower case', () => {
    const r = checkTheme(cfg, { colors: { accent: '#FFAA00' }, font: 'inter' });
    expect(r.violations).toEqual([]);
    expect(r.theme.colors.accent).toBe('#ffaa00');
    expect(r.theme.font).toBe('inter');
    expect(r.theme.colors.background).toBe(cfg.theme.colors.background);
  });

  // Regression: DTO class instances carry every declared field as an own property set to
  // `undefined` (ES2022 class fields). Those mean "not provided" and must not be flagged.
  it('treats undefined-valued keys as not provided', () => {
    const fromDto = { colors: { background: undefined, surface: undefined, text: undefined, accent: '#ffaa00' }, font: undefined };
    const r = checkTheme(cfg, fromDto);
    expect(r.violations).toEqual([]);
    expect(r.theme.colors.accent).toBe('#ffaa00');
    expect(r.theme.font).toBe(cfg.theme.font);
    expect(checkTheme(cfg, { colors: undefined, font: undefined }).violations).toEqual([]);
  });

  it('still rejects a non-customizable colour that has a real value next to undefined ones', () => {
    const r = checkTheme(cfg, { colors: { background: '#ffffff', accent: undefined } });
    expect(r.violations[0].message).toMatch(/theme\.colors\.background cannot be changed/);
  });

  it('does not mutate the template defaults', () => {
    checkTheme(cfg, { colors: { accent: '#ffaa00' } });
    expect(cfg.theme.colors.accent).toBe('#d4af37');
  });

  it.each<[string, unknown, RegExp]>([
    ['a colour this template does not allow changing', { colors: { background: '#ffffff' } }, /cannot be changed/],
    ['an unknown colour token', { colors: { border: '#ffffff' } }, /cannot be changed/],
    ['named colours', { colors: { accent: 'red' } }, /#rrggbb/],
    ['3-digit hex', { colors: { accent: '#fa0' } }, /#rrggbb/],
    ['CSS injection', { colors: { accent: 'red;} body{display:none' } }, /#rrggbb/],
    ['url() injection', { colors: { accent: 'url(https://evil.example/x.png)' } }, /#rrggbb/],
    ['non-string colour', { colors: { accent: 123 } }, /#rrggbb/],
    ['a font the template does not allow', { font: 'poppins' }, /font must be one of/],
    ['an unknown font', { font: '"; alert(1)' }, /font must be one of/],
    ['unsupported keys', { spacing: '99px' }, /not supported/],
    ['non-object theme', 'dark', /must be an object/],
    ['non-object colours', { colors: 'red' }, /colors must be an object/],
  ])('rejects %s', (_l, overrides, expected) => {
    const r = checkTheme(cfg, overrides);
    expect(r.violations.map((v) => v.message).join(' | ')).toMatch(expected);
    expect(r.violations[0].code).toBe('THEME_INVALID');
  });

  it('rejects an accent that disappears into the background', () => {
    const r = checkTheme(cfg, { colors: { accent: '#0b1021' } });
    expect(r.violations[0]).toMatchObject({ code: 'THEME_LOW_CONTRAST' });
  });

  it('resolveTheme falls back to the defaults instead of using a bad override', () => {
    expect(resolveTheme(cfg, { colors: { accent: 'url(x)' }, font: 'inter' })).toEqual(cfg.theme);
    expect(resolveTheme(cfg, 'garbage')).toEqual(cfg.theme);
    expect(resolveTheme(cfg, { colors: { accent: '#ffaa00' } }).colors.accent).toBe('#ffaa00');
  });
});

describe('checkPublishRequirements', () => {
  const cfg = base();
  const ok = { message: 'Happy birthday', photoCount: 3, memoryCount: 0 };
  const codes = (c: TemplateConfig, ctx: Parameters<typeof checkPublishRequirements>[1]) =>
    checkPublishRequirements(c, ctx).map((v) => v.code);

  it('passes when every required section has its content', () => {
    expect(codes(cfg, ok)).toEqual([]);
  });

  it('requires a photo when the gallery is required', () => {
    expect(codes(cfg, { ...ok, photoCount: 0 })).toEqual(['PHOTOS_REQUIRED']);
  });

  it('honours limits.minPhotos and pluralises the message', () => {
    const c = { ...base(), limits: { minPhotos: 2, maxMemories: 6 } };
    const v = checkPublishRequirements(c, { ...ok, photoCount: 1 });
    expect(v[0]).toMatchObject({ code: 'PHOTOS_REQUIRED' });
    expect(v[0].message).toMatch(/at least 2 photos/);
    expect(codes(c, { ...ok, photoCount: 2 })).toEqual([]);
  });

  it.each([null, undefined, '', '   \n '])('requires a non-blank message (%p)', (message) => {
    expect(codes(cfg, { ...ok, message })).toEqual(['MESSAGE_REQUIRED']);
  });

  it('reports every missing requirement at once', () => {
    expect(codes(cfg, { message: '', photoCount: 0, memoryCount: 0 }).sort()).toEqual(['MESSAGE_REQUIRED', 'PHOTOS_REQUIRED']);
  });

  it('only requires memories when memory_cards is a required section', () => {
    expect(codes(cfg, ok)).toEqual([]); // optional in the base config
    const c = base();
    c.sections.find((s) => s.type === 'memory_cards')!.required = true;
    expect(codes(c, ok)).toEqual(['MEMORIES_REQUIRED']);
    expect(codes(c, { ...ok, memoryCount: 1 })).toEqual([]);
  });

  it('ignores sections that are not required', () => {
    const c = base();
    c.sections.find((s) => s.type === 'photo_gallery')!.required = false;
    expect(codes(c, { ...ok, photoCount: 0 })).toEqual([]);
  });
});
