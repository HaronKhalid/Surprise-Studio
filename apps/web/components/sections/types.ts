import type { PublicSurprise, Section } from '@/lib/types';

/** Every section receives the whole surprise plus its own `props` from the template definition. */
export interface SectionProps {
  s: PublicSurprise;
  props: NonNullable<Section['props']>;
}
