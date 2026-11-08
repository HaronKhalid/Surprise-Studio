import { detectMime } from './image-validation';

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10]);
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0, 0, 0, 0]), Buffer.from('WEBP')]);

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
