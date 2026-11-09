import type { CSSProperties } from 'react';
import { fontFamily, fontVariableClasses } from '@/lib/fonts';
import type { PublicSurprise, Section, SectionType, Theme } from '@/lib/types';
import { ViewBeacon } from './Beacons';
import { Confetti } from './sections/Confetti';
import { FinalReveal } from './sections/FinalReveal';
import { FinalWish } from './sections/FinalWish';
import { Footer } from './sections/Footer';
import { Hero } from './sections/Hero';
import { MemoryCards } from './sections/MemoryCards';
import { Message } from './sections/Message';
import { PhotoGallery } from './sections/PhotoGallery';
import type { SectionProps } from './sections/types';

const REGISTRY: Record<Exclude<SectionType, 'footer' | 'confetti'>, (p: SectionProps) => React.ReactNode> = {
  hero: Hero,
  photo_gallery: PhotoGallery,
  memory_cards: MemoryCards,
  message: Message,
  final_reveal: FinalReveal,
  final_wish: FinalWish,
};

// The API already guarantees these are #rrggbb; checked again because they end up in a style attribute.
const HEX = /^#[0-9a-f]{6}$/i;
const SAFE_DEFAULTS = { background: '#111111', surface: '#1b1b1b', text: '#ffffff', accent: '#d4af37' } as const;
const safe = (key: keyof Theme['colors'], v: string | undefined) => (v && HEX.test(v) ? v : SAFE_DEFAULTS[key]);

/**
 * Renders a surprise: template sections in order, styled by the surprise's theme tokens.
 * Everything here is data-driven; no recipient information is hard-coded in a component.
 */
export function Experience({ surprise, preview = false }: { surprise: PublicSurprise; preview?: boolean }) {
  const { colors, font } = surprise.theme;
  const style = {
    '--bg': safe('background', colors.background),
    '--surface': safe('surface', colors.surface),
    '--text': safe('text', colors.text),
    '--accent': safe('accent', colors.accent),
    '--font': fontFamily(font),
  } as CSSProperties;

  const sections = surprise.template.sections;
  const hasConfetti = sections.some((s) => s.type === 'confetti');

  const render = (section: Section, i: number) => {
    const Component = REGISTRY[section.type as keyof typeof REGISTRY];
    // Unknown or footer/confetti types are handled elsewhere; an unknown type is skipped, not fatal.
    return Component ? <Component key={`${section.type}-${i}`} s={surprise} props={section.props ?? {}} /> : null;
  };

  return (
    <div className={`experience ${fontVariableClasses}`} data-template={surprise.template.slug} style={style}>
      {hasConfetti && <Confetti />}
      {preview ? (
        <p className="preview-badge" role="status">
          Preview · not published yet
        </p>
      ) : (
        <ViewBeacon slug={surprise.slug} template={surprise.template.slug} />
      )}
      <main>{sections.map(render)}</main>
      {/* No slug in preview: nothing the creator does while previewing is counted as a real view. */}
      <Footer slug={preview ? undefined : surprise.slug} template={surprise.template.slug} />
    </div>
  );
}
