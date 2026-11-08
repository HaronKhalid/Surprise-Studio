import { Photo } from '@/components/Photo';
import { Reveal } from '@/components/Reveal';
import type { SectionProps } from './types';

const SIZES = {
  wide: '(min-width: 900px) 860px, 100vw',
  half: '(min-width: 900px) 420px, 50vw',
  timeline: '(min-width: 900px) 420px, calc(100vw - 88px)',
  full: '100vw',
} as const;

/** One section, four layouts (chosen by the template): reveal, grid, timeline, hero_then_grid. */
export function PhotoGallery({ s, props }: SectionProps) {
  const { photos } = s;
  if (photos.length === 0) return null;
  const layout = String(props.layout ?? 'grid');
  const total = photos.length;

  if (layout === 'hero_then_grid') {
    const [first, ...rest] = photos;
    return (
      <section className="gallery gallery--hero-then-grid" aria-label="Photos">
        <Photo photo={first} index={0} total={total} sizes={SIZES.full} priority className="photo--hero" />
        {rest.length > 0 && (
          <div className="section">
            <div className="grid">
              {rest.map((p, i) => (
                <Reveal key={i} className="photo-wrap">
                  <Photo photo={p} index={i + 1} total={total} sizes={SIZES.half} />
                </Reveal>
              ))}
            </div>
          </div>
        )}
      </section>
    );
  }

  const sizes = layout === 'reveal' ? SIZES.wide : layout === 'timeline' ? SIZES.timeline : SIZES.half;
  return (
    <section className={`section gallery gallery--${layout}`} aria-label="Photos">
      <div className={layout === 'grid' ? 'grid' : 'stack'}>
        {photos.map((p, i) => (
          <Reveal key={i} className="photo-wrap">
            <Photo photo={p} index={i} total={total} sizes={sizes} />
          </Reveal>
        ))}
      </div>
    </section>
  );
}
