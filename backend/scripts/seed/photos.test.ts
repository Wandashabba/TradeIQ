import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import { computePhotoHashes, hammingDistance } from '../../src/modules/photos/photoHash';
import { demoPhotoDataUrl, SECTION_TINTS, shelfPhotoDataUrl } from './photos';

describe('demoPhotoDataUrl', () => {
  it('produces a base64 jpeg data URL', async () => {
    const url = await demoPhotoDataUrl([200, 80, 60]);
    expect(url.startsWith('data:image/jpeg;base64,')).toBe(true);
  });

  // The guard for #209: the seed's URLs must survive the REAL thumbnail
  // decoder, which is what 422s on the current https://demo.tradeiq.local/...
  // placeholders.
  it('is decodable by the production thumbnail pipeline', async () => {
    const url = await demoPhotoDataUrl([60, 120, 200]);
    const thumb = await getThumbnailForPhoto(`seed-test-${Date.now()}`, async () => url);
    expect(thumb.length).toBeGreaterThan(0);
    // JPEG magic bytes.
    expect(thumb[0]).toBe(0xff);
    expect(thumb[1]).toBe(0xd8);
  });

  it('is deterministic for the same tint', async () => {
    const a = await demoPhotoDataUrl([10, 20, 30]);
    const b = await demoPhotoDataUrl([10, 20, 30]);
    expect(a).toBe(b);
  });

  it('differs between tints, so demo rows are visibly distinct', async () => {
    const a = await demoPhotoDataUrl([10, 20, 30]);
    const b = await demoPhotoDataUrl([200, 30, 40]);
    expect(a).not.toBe(b);
  });
});

describe('SECTION_TINTS', () => {
  it('covers every section the seed attaches photos to', () => {
    expect(Object.keys(SECTION_TINTS).sort()).toEqual(
      ['closure', 'competitive', 'pricing', 'visibility'].sort(),
    );
  });

  it('every tint decodes', async () => {
    for (const tint of Object.values(SECTION_TINTS)) {
      const url = await demoPhotoDataUrl(tint);
      expect(url.startsWith('data:image/jpeg;base64,')).toBe(true);
    }
  });
});

describe('shelfPhotoDataUrl', () => {
  it('is deterministic per seed and decodable by the thumbnail pipeline', async () => {
    const a = await shelfPhotoDataUrl(42);
    expect(await shelfPhotoDataUrl(42)).toBe(a);
    const thumb = await getThumbnailForPhoto(`seed-shelf-${Date.now()}`, async () => a);
    expect(thumb[0]).toBe(0xff);
  });

  it('stays small — a few kilobytes of base64', async () => {
    expect((await shelfPhotoDataUrl(7)).length).toBeLessThan(12_000);
  });

  // Honest visits must not look like photo reuse to the fraud engine (#244):
  // different seeds differ by content hash AND sit far apart perceptually.
  it('gives different seeds different content and distant perceptual hashes', async () => {
    const hashes = await Promise.all([1, 2, 3, 4, 5, 6].map(async (seed) => computePhotoHashes(await shelfPhotoDataUrl(seed))));
    for (let i = 0; i < hashes.length; i += 1) {
      for (let j = i + 1; j < hashes.length; j += 1) {
        expect(hashes[i]!.contentHash).not.toBe(hashes[j]!.contentHash);
        expect(hammingDistance(hashes[i]!.perceptualHash!, hashes[j]!.perceptualHash!)).toBeGreaterThan(10);
      }
    }
  });
});
