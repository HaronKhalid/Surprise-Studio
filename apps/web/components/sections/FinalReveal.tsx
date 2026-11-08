import { displayName, fill, occasionWish } from '@/lib/text';
import type { SectionProps } from './types';

const BURST = 14;

/**
 * Tap-to-open reveal built on <details>, so it works without JavaScript and is keyboard/screen-reader
 * accessible for free. Reveals the creator's closing words, or a neutral wish if they wrote none.
 */
export function FinalReveal({ s, props }: SectionProps) {
  const name = displayName(s);
  const prompt = fill(props.prompt, name) || 'One more thing…';
  const closing = s.content.ending ?? occasionWish(s.occasion, name);
  return (
    <section className="section final-reveal">
      <div className="container">
        <details className="reveal-box">
          <summary dir="auto">{prompt}</summary>
          <div className="reveal-content">
            <p dir="auto">{closing}</p>
            <div className="burst" aria-hidden="true">
              {Array.from({ length: BURST }, (_, i) => (
                <span key={i} style={{ ['--angle' as string]: `${(360 / BURST) * i}deg`, ['--dist' as string]: `${70 + ((i * 29) % 50)}px` }} />
              ))}
            </div>
          </div>
        </details>
      </div>
    </section>
  );
}
