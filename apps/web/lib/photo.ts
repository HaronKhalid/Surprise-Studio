import type { PhotoData } from './types';

/**
 * srcset using each variant's real width. Variants are never upscaled, so a 700px original has
 * medium and large that are both 700px wide; those duplicates are collapsed into one candidate.
 */
export function photoSrcSet(photo: PhotoData): string {
  const original = photo.width ?? 1920;
  const candidates: [string, number][] = [
    [photo.urls.thumb, Math.min(320, original)],
    [photo.urls.medium, Math.min(960, original)],
    [photo.urls.large, Math.min(1920, original)],
  ];
  const seen = new Set<number>();
  return candidates
    .filter(([, width]) => !seen.has(width) && seen.add(width))
    .map(([url, width]) => `${url} ${width}w`)
    .join(', ');
}
