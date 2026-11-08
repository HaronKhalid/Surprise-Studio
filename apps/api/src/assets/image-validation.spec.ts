import sharp from 'sharp';
import { detectMime, displayedSize } from './image-validation';

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10]);
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0, 0, 0, 0]), Buffer.from('WEBP')]);

describe('displayedSize', () => {
  it('prefers the orientation-corrected size', () => {
    expect(displayedSize({ width: 800, height: 600, autoOrient: { width: 600, height: 800 } })).toEqual({ width: 600, height: 800 });
  });

  it('falls back to the stored size when there is no orientation info', () => {
    expect(displayedSize({ width: 800, height: 600 })).toEqual({ width: 800, height: 600 });
  });

  it.each([{}, { width: 800 }, { height: 600 }, { width: 0, height: 0 }])('returns null for %j', (meta) => {
    expect(displayedSize(meta)).toBeNull();
  });

  // Real images: the recorded size must match what the generated variants really look like.
  it.each([1, 2, 3, 4, 5, 6, 7, 8])('matches the rotated output for EXIF orientation %i', async (orientation) => {
    const src = await sharp({ create: { width: 800, height: 600, channels: 3, background: '#468' } })
      .jpeg()
      .withMetadata({ orientation })
      .toBuffer();
    const recorded = displayedSize(await sharp(src).metadata());
    const variant = await sharp(await sharp(src).rotate().resize({ width: 1920, withoutEnlargement: true }).webp().toBuffer()).metadata();
    expect(recorded).toEqual({ width: variant.width, height: variant.height });
  });
});

describe('detectMime', () => {
  it('recognises JPEG, PNG and WebP by their signatures', () => {
    expect(detectMime(JPEG)).toBe('image/jpeg');
    expect(detectMime(PNG)).toBe('image/png');
    expect(detectMime(WEBP)).toBe('image/webp');
  });

  it.each([
    ['script text', Buffer.from('<?php echo 1; ?>')],
    ['SVG', Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>')],
    ['GIF', Buffer.from('GIF89a......')],
    ['RIFF that is not WebP (e.g. WAV)', Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVE')])],
    ['truncated PNG header', PNG.subarray(0, 5)],
    ['empty', Buffer.alloc(0)],
  ])('rejects %s', (_label, buf) => {
    expect(detectMime(buf)).toBeNull();
  });
});
