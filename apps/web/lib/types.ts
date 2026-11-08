/**
 * Mirrors `PublicSurprise` in apps/api/src/public/public-surprise.ts, the response of
 * GET /public/surprises/:slug. Keep the two in sync (a shared package can replace this later).
 */
export type ColorKey = 'background' | 'surface' | 'text' | 'accent';

export interface Theme {
  colors: Record<ColorKey, string>;
  font: string;
}

export type SectionType =
  | 'hero'
  | 'photo_gallery'
  | 'memory_cards'
  | 'message'
  | 'confetti'
  | 'final_reveal'
  | 'final_wish'
  | 'footer';

export interface Section {
  type: SectionType;
  required: boolean;
  props?: Record<string, string | number | boolean>;
}

export interface PhotoData {
  width: number | null;
  height: number | null;
  urls: { thumb: string; medium: string; large: string };
}

export interface PublicSurprise {
  slug: string;
  occasion: string;
  recipient: { name: string; nickname: string | null };
  message: string | null;
  content: { intro?: string; ending?: string; memories: { title?: string; text: string }[] };
  theme: Theme;
  template: { slug: string; version: number; sections: Section[] };
  photos: PhotoData[];
  publishedAt: string | null;
}
