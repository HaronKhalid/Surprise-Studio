import { Reveal } from '@/components/Reveal';
import { displayName, fill } from '@/lib/text';
import type { SectionProps } from './types';

export function Message({ s, props }: SectionProps) {
  if (!s.message) return null;
  const heading = fill(props.heading, displayName(s));
  return (
    <section className="section message">
      <div className="container">
        <Reveal>
          {heading && (
            <h2 className="heading" dir="auto">
              {heading}
            </h2>
          )}
          {/* Plain text: line breaks are kept by CSS (white-space: pre-line), never rendered as HTML. */}
          <p className="message-body" dir="auto">
            {s.message}
          </p>
        </Reveal>
      </div>
    </section>
  );
}
