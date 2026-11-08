// Run with `npm test` (Node's built-in runner; needs Node >= 22.18 for TypeScript type stripping).
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { photoSrcSet } from './photo.ts';
import { displayName, fill, occasionTitle, occasionWish } from './text.ts';
import type { PhotoData, PublicSurprise } from './types.ts';

const photo = (width: number | null): PhotoData => ({
  width,
  height: 100,
  urls: { thumb: 'https://cdn/t.webp', medium: 'https://cdn/m.webp', large: 'https://cdn/l.webp' },
});

describe('photoSrcSet', () => {
  it('uses each variant at its real width for a large photo', () => {
    assert.equal(photoSrcSet(photo(4000)), 'https://cdn/t.webp 320w, https://cdn/m.webp 960w, https://cdn/l.webp 1920w');
  });

  it('collapses variants that are the same size because they are never upscaled', () => {
    // 700px original: medium and large are both 700px wide, so only one 700w candidate is listed.
    assert.equal(photoSrcSet(photo(700)), 'https://cdn/t.webp 320w, https://cdn/m.webp 700w');
  });

  it('collapses everything for a tiny photo', () => {
    assert.equal(photoSrcSet(photo(200)), 'https://cdn/t.webp 200w');
  });

  it('assumes a full-size original when the width is unknown', () => {
    assert.match(photoSrcSet(photo(null)), /1920w$/);
  });
});

const surprise = (nickname: string | null): PublicSurprise =>
  ({ occasion: 'birthday', recipient: { name: 'Ayesha Khan', nickname } }) as PublicSurprise;

describe('text helpers', () => {
  it('prefers the nickname, ignoring blank ones', () => {
    assert.equal(displayName(surprise('Ayesha')), 'Ayesha');
    assert.equal(displayName(surprise(null)), 'Ayesha Khan');
    assert.equal(displayName(surprise('   ')), 'Ayesha Khan');
  });

  it('fills every {name} placeholder and nothing else', () => {
    assert.equal(fill('Happy Birthday, {name}! Love, {name}', 'Sara'), 'Happy Birthday, Sara! Love, Sara');
    assert.equal(fill('No placeholder', 'Sara'), 'No placeholder');
  });

  it('does not interpret the name as markup or as a replacement pattern', () => {
    assert.equal(fill('Hi {name}', '<b>$&</b>'), 'Hi <b>$&</b>');
  });

  it('returns an empty string for missing or non-string copy', () => {
    assert.equal(fill(undefined, 'Sara'), '');
    assert.equal(fill(42, 'Sara'), '');
    assert.equal(fill(true, 'Sara'), '');
  });

  it('has neutral wording for occasions it does not know', () => {
    assert.equal(occasionWish('birthday', 'Sara'), 'Happy Birthday, Sara 🎂');
    assert.equal(occasionWish('graduation', 'Sara'), 'Thinking of you, Sara 💛');
  });

  it('titles birthday surprises specially', () => {
    assert.equal(occasionTitle('birthday', 'Sara'), "Sara's Birthday Surprise 🎂");
    assert.equal(occasionTitle('anniversary', 'Sara'), 'A surprise for Sara 🎁');
  });
});
