import { displayName, fill } from '@/lib/text';
import type { SectionProps } from './types';

export function Hero({ s, props }: SectionProps) {
  const name = displayName(s);
  const eyebrow = fill(props.eyebrow, name);
  return (
    <header className="section hero">
      {eyebrow && (
        <p className="eyebrow" dir="auto">
          {eyebrow}
        </p>
      )}
      <h1 className="hero-name" dir="auto">
        {name}
      </h1>
      {s.content.intro && (
        <p className="hero-intro" dir="auto">
          {s.content.intro}
        </p>
      )}
      <span className="scroll-hint" aria-hidden="true">
        ↓
      </span>
    </header>
  );
}
