import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import {
  GENERATED,
  loadSeedPlaceImages,
  PLACE_ASSET_DIR,
  PLACE_MAX_BYTES,
  type PlaceManifest,
} from './placeImages';
import { PLACE_PROMPTS } from '../places/prompts';
import { TERRITORIES } from './catalog';

/**
 * THE COMMITTED FIXTURES, AND THE LOADER THAT READS THEM.
 *
 * Two groups, and the first is the one that matters. The place images are
 * **committed assets**, which means nothing in CI regenerates them and nothing
 * in CI would notice if somebody dropped a 2 MB holiday snap into the folder
 * by hand. So the fixtures themselves are tested: every seeded territory has
 * one, every one is inside the plate's byte budget, and every one is marked as
 * generated.
 */
describe('the committed place images', () => {
  const manifest = JSON.parse(
    readFileSync(join(PLACE_ASSET_DIR, 'manifest.json'), 'utf8'),
  ) as PlaceManifest;

  it('covers every seeded territory, plus the whole footprint', () => {
    const have = new Set(manifest.places.map((p) => p.code));
    for (const territory of TERRITORIES) {
      expect(have.has(territory.code)).toBe(true);
    }
    // "All territories" is the scope The Floor opens in, so it is the one that
    // must never be missing.
    expect(have.has('ALL')).toBe(true);
  });

  it('records every one of them as generated, with the model that made it', () => {
    expect(manifest.places.length).toBeGreaterThan(0);
    for (const place of manifest.places) {
      // THE BOUNDARY, AS AN ASSERTION. An unmarked image is the one row that
      // must never exist: everything downstream — the seed, the API header, the
      // sentence the plate speaks — reads this field, and a blank one would
      // quietly promote an illustration to a photograph.
      expect(place.source).toBe(GENERATED);
      expect(place.generator).toMatch(/^gemini-/);
      expect(place.prompt.length).toBeGreaterThan(40);
    }
  });

  it('holds every one of them inside the plate’s byte budget', () => {
    for (const place of manifest.places) {
      const bytes = readFileSync(join(PLACE_ASSET_DIR, place.file));
      expect(bytes.length).toBeLessThanOrEqual(PLACE_MAX_BYTES);
      // And the manifest's own figure is the file's, so a hand-edited asset
      // with a stale entry is caught here rather than on a prepaid bundle.
      expect(place.bytes).toBe(bytes.length);
    }
  });

  it('asks for no brand marks, no signage and no faces, in every prompt', () => {
    // The constraint is appended from one shared string precisely so it cannot
    // go missing from one prompt; this is the test that says so.
    for (const place of PLACE_PROMPTS) {
      const entry = manifest.places.find((p) => p.code === place.code);
      expect(entry).toBeDefined();
      expect(entry!.prompt).toContain('no brand names or logos');
      expect(entry!.prompt).toContain('No recognisable faces');
    }
  });

  it('loads them all as data URLs, carrying their provenance', () => {
    const images = loadSeedPlaceImages();
    expect(images.length).toBe(manifest.places.length);
    for (const image of images) {
      expect(image.dataUrl.startsWith('data:image/jpeg;base64,')).toBe(true);
      expect(image.source).toBe(GENERATED);
    }
  });
});

describe('loadSeedPlaceImages', () => {
  function fixtureDir(manifest: PlaceManifest, files: Record<string, Buffer>): string {
    const dir = mkdtempSync(join(tmpdir(), 'places-'));
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'manifest.json'), JSON.stringify(manifest));
    for (const [name, bytes] of Object.entries(files)) {
      writeFileSync(join(dir, name), bytes);
    }
    return dir;
  }

  const entry = {
    code: 'GP',
    label: 'Gauteng',
    file: 'GP.jpg',
    source: GENERATED,
    generator: 'gemini-3.1-flash-image',
    prompt: 'a street',
    mimeType: 'image/jpeg',
    bytes: 3,
    generatedAt: '2026-09-28T00:00:00.000Z',
  };

  it('is empty, not an error, when the assets are not there', () => {
    // A checkout with no assets seeds no place images and The Floor draws its
    // designed no-picture state — the same thing it does for a real tenant
    // whose territories have never been pictured. A throw here would make the
    // whole seed fail over a missing decoration.
    expect(loadSeedPlaceImages(join(tmpdir(), 'places-that-do-not-exist'))).toEqual([]);
  });

  it('skips a manifest entry whose file is gone', () => {
    const dir = fixtureDir({ places: [entry] }, {});
    expect(loadSeedPlaceImages(dir)).toEqual([]);
  });

  it('reads the manifest, not the directory', () => {
    // An image with no manifest entry is an image whose origin nobody
    // recorded, and that is exactly what must not reach the database.
    const dir = fixtureDir({ places: [entry] }, {
      'GP.jpg': Buffer.from([1, 2, 3]),
      'MYSTERY.jpg': Buffer.from([4, 5, 6]),
    });
    const images = loadSeedPlaceImages(dir);
    expect(images.map((i) => i.code)).toEqual(['GP']);
  });

  it('throws on an asset far over the plate’s budget', () => {
    // The generator is run by hand and the seed is run by everyone, so the
    // seed is where a 400 kB picture somebody dropped in gets caught.
    const dir = fixtureDir(
      { places: [{ ...entry, bytes: PLACE_MAX_BYTES * 2 }] },
      { 'GP.jpg': Buffer.alloc(PLACE_MAX_BYTES * 2) },
    );
    expect(() => loadSeedPlaceImages(dir)).toThrow(/budget/);
  });
});
