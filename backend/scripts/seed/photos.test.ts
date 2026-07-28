import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import { demoPhotoDataUrl, SECTION_TINTS } from './photos';

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
