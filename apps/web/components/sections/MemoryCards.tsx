import { Reveal } from '@/components/Reveal';
import { displayName, fill } from '@/lib/text';
import type { SectionProps } from './types';

export function MemoryCards({ s, props }: SectionProps) {
  const memories = s.content.memories;
  if (memories.length === 0) return null;
  const heading = fill(props.heading, displayName(s));
  return (
    <section className="section memories">
      <div className="container">
        {heading && (
          <Reveal>
            <h2 className="heading" dir="auto">
              {heading}
            </h2>
          </Reveal>
        )}
        <ol className="memory-list">
          {memories.map((m, i) => (
            <li key={i}>
              <Reveal delay={i * 70}>
                <article className="memory">
                  {m.title && (
                    <h3 dir="auto">{m.title}</h3>
                  )}
                  <p dir="auto">{m.text}</p>
                </article>
              </Reveal>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
