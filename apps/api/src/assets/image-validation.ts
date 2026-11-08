export const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export type AllowedMime = (typeof ALLOWED_MIME_TYPES)[number];

export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
export const MAX_PHOTOS_PER_SURPRISE = 10;
export const MIN_DIMENSION = 100;
export const MAX_DIMENSION = 12000;

/** Detects the real format from file bytes; never trust the client's declared type. */
export function detectMime(buf: Buffer): AllowedMime | null {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (buf.length >= 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

interface SizeMetadata {
  width?: number;
  height?: number;
  autoOrient?: { width: number; height: number };
}

/**
 * The size the photo is actually displayed at. sharp's metadata() reports the stored pixel size and
 * ignores EXIF orientation, but our variants are generated after rotate(), so a portrait phone photo
 * (stored landscape + "rotate 90") must be recorded as portrait or the page reserves the wrong shape.
 */
export function displayedSize(meta: SizeMetadata): { width: number; height: number } | null {
  const width = meta.autoOrient?.width ?? meta.width;
  const height = meta.autoOrient?.height ?? meta.height;
  return width && height ? { width, height } : null;
}

export const VARIANTS = [
  { name: 'thumb', width: 320 },
  { name: 'medium', width: 960 },
  { name: 'large', width: 1920 },
] as const;
