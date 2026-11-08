/**
 * Template configuration: types, validation, theme resolution and publish requirements.
 *
 * Pure functions only (no I/O) so the rules are easy to test and can be reused by the seed
 * check, the surprise service and, later, the public renderer. See docs/templates.md.
 */

export const SECTION_TYPES = [
  'hero',
  'photo_gallery',
  'memory_cards',
  'message',
  'confetti',
  'final_reveal',
  'final_wish',
  'footer',
] as const;
export type SectionType = (typeof SECTION_TYPES)[number];

export const COLOR_KEYS = ['background', 'surface', 'text', 'accent'] as const;
export type ColorKey = (typeof COLOR_KEYS)[number];

export const FONT_KEYS = ['playfair', 'cormorant', 'dm-serif', 'inter', 'poppins'] as const;
export const GALLERY_LAYOUTS = ['reveal', 'grid', 'timeline', 'hero_then_grid'] as const;

/** Only 6-digit hex is accepted: theme values end up in CSS custom properties on a public page. */
export const HEX_COLOR = /^#[0-9a-fA-F]{6}$/;
/** WCAG: 4.5:1 for body text, 3:1 for large text / UI accents. */
export const MIN_TEXT_CONTRAST = 4.5;
export const MIN_ACCENT_CONTRAST = 3;

const MAX_PROP_LENGTH = 120;
const MAX_MEMORIES = 10;
const MAX_PHOTOS = 10;

export type SectionProps = Record<string, string | number | boolean>;

export interface TemplateSection {
  type: SectionType;
  required: boolean;
  props?: SectionProps;
}

export interface ResolvedTheme {
  colors: Record<ColorKey, string>;
  font: string;
}

export interface TemplateConfig {
  schemaVersion: 1;
  displayOrder: number;
  description: string;
  sections: TemplateSection[];
  theme: ResolvedTheme;
  customizable: { colors: ColorKey[]; fonts: string[] };
  limits: { minPhotos: number; maxMemories: number };
}

export interface RuleViolation {
  code: string;
  message: string;
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);

const isOneOf = <T extends readonly string[]>(list: T, v: unknown): v is T[number] =>
  typeof v === 'string' && (list as readonly string[]).includes(v);

const isIntInRange = (v: unknown, min: number, max: number) =>
  typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;

// ---------------------------------------------------------------------------------------------
// Colour maths
// ---------------------------------------------------------------------------------------------

function luminance(hex: string): number {
  const channel = (i: number) => {
    const c = parseInt(hex.slice(1 + i * 2, 3 + i * 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * channel(0) + 0.7152 * channel(1) + 0.0722 * channel(2);
}

/** WCAG 2.x contrast ratio between two #rrggbb colours (1 to 21). */
export function contrastRatio(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

// ---------------------------------------------------------------------------------------------
// Template definition validation (used by the seed check and unit tests)
// ---------------------------------------------------------------------------------------------

/** Returns a list of human-readable problems; an empty list means the configuration is valid. */
export function validateTemplateConfig(raw: unknown): string[] {
  if (!isObject(raw)) return ['configuration must be an object'];
  const errors: string[] = [];

  if (raw.schemaVersion !== 1) errors.push('schemaVersion must be 1');
  if (!isIntInRange(raw.displayOrder, 0, 1000)) errors.push('displayOrder must be an integer between 0 and 1000');
  if (typeof raw.description !== 'string' || !raw.description.trim() || raw.description.length > 200) {
    errors.push('description must be a non-empty string of at most 200 characters');
  }

  validateSections(raw.sections, errors);

  const theme = isObject(raw.theme) ? raw.theme : null;
  const colors = theme && isObject(theme.colors) ? theme.colors : null;
  if (!colors) {
    errors.push('theme.colors must be an object');
  } else {
    for (const key of COLOR_KEYS) {
      if (typeof colors[key] !== 'string' || !HEX_COLOR.test(colors[key] as string)) {
        errors.push(`theme.colors.${key} must be a #rrggbb colour`);
      }
    }
    for (const key of Object.keys(colors)) {
      if (!isOneOf(COLOR_KEYS, key)) errors.push(`theme.colors.${key} is not a known colour token`);
    }
  }
  if (!isOneOf(FONT_KEYS, theme?.font)) errors.push(`theme.font must be one of: ${FONT_KEYS.join(', ')}`);

  const custom = isObject(raw.customizable) ? raw.customizable : null;
  if (!custom || !Array.isArray(custom.colors) || !custom.colors.every((c) => isOneOf(COLOR_KEYS, c))) {
    errors.push(`customizable.colors must be a list of: ${COLOR_KEYS.join(', ')}`);
  }
  if (
    !custom ||
    !Array.isArray(custom.fonts) ||
    custom.fonts.length === 0 ||
    !custom.fonts.every((f) => isOneOf(FONT_KEYS, f))
  ) {
    errors.push(`customizable.fonts must be a non-empty list of: ${FONT_KEYS.join(', ')}`);
  } else if (typeof theme?.font === 'string' && !(custom.fonts as string[]).includes(theme.font)) {
    errors.push('customizable.fonts must include the default theme.font');
  }

  const limits = isObject(raw.limits) ? raw.limits : null;
  if (!limits || !isIntInRange(limits.minPhotos, 0, MAX_PHOTOS)) errors.push(`limits.minPhotos must be an integer 0-${MAX_PHOTOS}`);
  if (!limits || !isIntInRange(limits.maxMemories, 0, MAX_MEMORIES)) errors.push(`limits.maxMemories must be an integer 0-${MAX_MEMORIES}`);

  // A template is only valid if its own defaults are readable.
  if (colors && COLOR_KEYS.every((k) => typeof colors[k] === 'string' && HEX_COLOR.test(colors[k] as string))) {
    const c = colors as Record<ColorKey, string>;
    if (contrastRatio(c.text, c.background) < MIN_TEXT_CONTRAST) errors.push('default text/background contrast is below 4.5:1');
    if (contrastRatio(c.accent, c.background) < MIN_ACCENT_CONTRAST) errors.push('default accent/background contrast is below 3:1');
  }

  return errors;
}

function validateSections(raw: unknown, errors: string[]) {
  if (!Array.isArray(raw) || raw.length === 0) {
    errors.push('sections must be a non-empty array');
    return;
  }
  const seen = new Set<string>();
  raw.forEach((s, i) => {
    const at = `sections[${i}]`;
    if (!isObject(s) || !isOneOf(SECTION_TYPES, s.type)) {
      errors.push(`${at}.type must be one of: ${SECTION_TYPES.join(', ')}`);
      return;
    }
    if (seen.has(s.type)) errors.push(`${at}: section "${s.type}" appears more than once`);
    seen.add(s.type);
    if (typeof s.required !== 'boolean') errors.push(`${at}.required must be a boolean`);
    if (s.props !== undefined) {
      if (!isObject(s.props)) {
        errors.push(`${at}.props must be an object`);
        return;
      }
      for (const [k, v] of Object.entries(s.props)) {
        const primitive = typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean';
        if (!primitive) errors.push(`${at}.props.${k} must be a string, number or boolean`);
        else if (typeof v === 'string' && v.length > MAX_PROP_LENGTH) errors.push(`${at}.props.${k} is longer than ${MAX_PROP_LENGTH} characters`);
      }
      if (s.type === 'photo_gallery' && !isOneOf(GALLERY_LAYOUTS, s.props.layout)) {
        errors.push(`${at}.props.layout must be one of: ${GALLERY_LAYOUTS.join(', ')}`);
      }
    } else if (s.type === 'photo_gallery') {
      errors.push(`${at}.props.layout is required for photo_gallery`);
    }
  });
  const first = (raw[0] as { type?: unknown } | undefined)?.type;
  const last = raw[raw.length - 1] as { type?: unknown; required?: unknown } | undefined;
  if (first !== 'hero') errors.push('the first section must be "hero"');
  if (last?.type !== 'footer' || last.required !== true) errors.push('the last section must be a required "footer"');
}

// ---------------------------------------------------------------------------------------------
// Theme: validate a creator's overrides and merge them over the template defaults
// ---------------------------------------------------------------------------------------------

/**
 * Validates `overrides` against what the template allows and returns the effective theme built
 * only from accepted values, so a bad override can never reach a rendered page.
 */
export function checkTheme(config: TemplateConfig, overrides: unknown): { theme: ResolvedTheme; violations: RuleViolation[] } {
  const theme: ResolvedTheme = { colors: { ...config.theme.colors }, font: config.theme.font };
  const violations: RuleViolation[] = [];
  const invalid = (message: string) => violations.push({ code: 'THEME_INVALID', message });

  if (overrides === undefined || overrides === null) return { theme, violations };
  if (!isObject(overrides)) {
    invalid('theme must be an object');
    return { theme, violations };
  }

  // A key that is present but `undefined` means "not provided". DTO class instances produce these
  // (ES2022 class fields are defined as own properties), so they must not count as overrides.
  const provided = (o: Record<string, unknown>) => Object.entries(o).filter(([, v]) => v !== undefined);

  for (const [key] of provided(overrides)) {
    if (key !== 'colors' && key !== 'font') invalid(`theme.${key} is not supported`);
  }

  if (overrides.colors !== undefined) {
    if (!isObject(overrides.colors)) {
      invalid('theme.colors must be an object');
    } else {
      for (const [key, value] of provided(overrides.colors)) {
        if (!isOneOf(COLOR_KEYS, key) || !config.customizable.colors.includes(key)) {
          invalid(`theme.colors.${key} cannot be changed on this template`);
        } else if (typeof value !== 'string' || !HEX_COLOR.test(value)) {
          invalid(`theme.colors.${key} must be a #rrggbb colour`);
        } else {
          theme.colors[key] = value.toLowerCase();
        }
      }
    }
  }

  if (overrides.font !== undefined) {
    if (typeof overrides.font !== 'string' || !config.customizable.fonts.includes(overrides.font)) {
      invalid(`theme.font must be one of: ${config.customizable.fonts.join(', ')}`);
    } else {
      theme.font = overrides.font;
    }
  }

  // Template defaults are guaranteed readable by validateTemplateConfig, so this can only fire
  // because of a creator override.
  if (!violations.length) {
    const low = (code: string, message: string) => violations.push({ code, message });
    if (contrastRatio(theme.colors.text, theme.colors.background) < MIN_TEXT_CONTRAST) {
      low('THEME_LOW_CONTRAST', 'That colour choice makes the text hard to read');
    }
    if (contrastRatio(theme.colors.accent, theme.colors.background) < MIN_ACCENT_CONTRAST) {
      low('THEME_LOW_CONTRAST', 'That accent colour is too close to the background');
    }
  }

  return { theme, violations };
}

/** Effective theme for rendering. Invalid or disallowed overrides fall back to the defaults. */
export function resolveTheme(config: TemplateConfig, overrides: unknown): ResolvedTheme {
  const { theme, violations } = checkTheme(config, overrides);
  return violations.length ? { colors: { ...config.theme.colors }, font: config.theme.font } : theme;
}

/**
 * For output paths: accepts an already-resolved theme only if every token is well formed, else
 * returns the template defaults. Guards the public page against a malformed or tampered snapshot.
 */
export function sanitizeResolvedTheme(config: TemplateConfig, theme: unknown): ResolvedTheme {
  const fallback = (): ResolvedTheme => ({ colors: { ...config.theme.colors }, font: config.theme.font });
  if (!isObject(theme) || !isObject(theme.colors) || !isOneOf(FONT_KEYS, theme.font)) return fallback();
  const colors = {} as Record<ColorKey, string>;
  for (const key of COLOR_KEYS) {
    const v = theme.colors[key];
    if (typeof v !== 'string' || !HEX_COLOR.test(v)) return fallback();
    colors[key] = v.toLowerCase();
  }
  return { colors, font: theme.font };
}

// ---------------------------------------------------------------------------------------------
// Publish requirements
// ---------------------------------------------------------------------------------------------

export interface PublishContext {
  message: string | null | undefined;
  photoCount: number;
  memoryCount: number;
}

/** What a surprise must contain before this template can render it (driven by `required` sections). */
export function checkPublishRequirements(config: TemplateConfig, ctx: PublishContext): RuleViolation[] {
  const violations: RuleViolation[] = [];
  for (const section of config.sections) {
    if (!section.required) continue;
    if (section.type === 'photo_gallery') {
      const need = Math.max(1, config.limits.minPhotos);
      if (ctx.photoCount < need) {
        violations.push({ code: 'PHOTOS_REQUIRED', message: `Add at least ${need} photo${need > 1 ? 's' : ''} before publishing` });
      }
    } else if (section.type === 'message') {
      if (!ctx.message?.trim()) violations.push({ code: 'MESSAGE_REQUIRED', message: 'Write a message before publishing' });
    } else if (section.type === 'memory_cards') {
      if (ctx.memoryCount < 1) violations.push({ code: 'MEMORIES_REQUIRED', message: 'Add at least one memory before publishing' });
    }
  }
  return violations;
}
