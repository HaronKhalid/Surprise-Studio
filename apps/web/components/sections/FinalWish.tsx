import { Reveal } from '@/components/Reveal';
import { displayName, fill, occasionWish } from '@/lib/text';
import type { SectionProps } from './types';

export function FinalWish({ s, props }: SectionProps) {
  const name = displayName(s);
  const wish = fill(props.text, name) || occasionWish(s.occasion, name);
  return (
    <section className="section final-wish">
      <Reveal>
        <p className="wish" dir="auto">
          {wish}
        </p>
      </Reveal>
    </section>
  );
}
