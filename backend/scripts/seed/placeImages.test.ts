import { existsSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import sharp from 'sharp';
import {
  GENERATED,
  isPlaceImageSource,
  loadSeedPlaceImages,
  PLACE_ASSET_DIR,
  PLACE_HEIGHT,
  PLACE_MAX_BYTES,
  PLACE_SOURCES,
  PLACE_WIDTH,
  SUPPLIED,
  type PlaceManifest,
} from './placeImages';
import { PLACE_PROMPTS, PLACE_STYLE } from '../places/prompts';
import { SUPPLIED_PLACES } from '../places/supplied';
import { TERRITORIES } from './catalog';

/**
 * THE COMMITTED FIXTURES, AND THE LOADER THAT READS THEM.
 *
 * Two groups, and the first is the one that matters. The place images are
 * **committed assets**, which means nothing in CI regenerates them and nothing
 * in CI would notice if somebody dropped a 2 MB holiday snap into the folder
 * by hand. So the fixtures themselves are tested: every seeded territory has
 * one, every one is inside the plate's byte budget, every one is the same
 * size, and every one is **marked** — with a source this product recognises
 * and with the provenance that source implies.
 *
 * Since 29 September 2026 there are two sources. `generated` is a picture
 * `generate-place-images.ts` made from a prompt; `supplied` is a photograph
 * the owner handed over and `import-place-images.ts` brought in. The
 * assertions below are written per source rather than for one of them, because
 * the failure this file exists to catch — an image nothing downstream can
 * describe truthfully — is the same failure either way.
 */
describe('the committed place images', () => {
  const manifest = JSON.parse(
    readFileSync(join(PLACE_ASSET_DIR, 'manifest.json'), 'utf8'),
  ) as PlaceManifest;
  const generated = manifest.places.filter((p) => p.source === GENERATED);
  const supplied = manifest.places.filter((p) => p.source === SUPPLIED);

  it('covers every seeded territory, plus the whole footprint', () => {
    const have = new Set(manifest.places.map((p) => p.code));
    for (const territory of TERRITORIES) {
      expect(have.has(territory.code)).toBe(true);
    }
    // "All territories" is the scope The Floor opens in, so it is the one that
    // must never be missing.
    expect(have.has('ALL')).toBe(true);
  });

  it('marks every one of them with a source this product knows', () => {
    expect(manifest.places.length).toBeGreaterThan(0);
    for (const place of manifest.places) {
      // THE BOUNDARY, AS AN ASSERTION. An unmarked image is the one row that
      // must never exist: everything downstream — the seed, the API header, the
      // sentence the plate speaks — reads this field, and a blank or unknown
      // one would leave the plate guessing between "an illustration" and "a
      // photograph" in the one sentence a manager is given about the picture.
      expect(isPlaceImageSource(place.source)).toBe(true);
    }
    // And both kinds are actually present, so neither branch below is
    // vacuously green.
    expect(generated.length).toBeGreaterThan(0);
    expect(supplied.length).toBeGreaterThan(0);
    expect(generated.length + supplied.length).toBe(manifest.places.length);
  });

  it('records every generated one with the model and the prompt that made it', () => {
    for (const place of generated) {
      if (place.source !== GENERATED) throw new Error('filtered wrong');
      expect(place.generator).toMatch(/^gemini-/);
      expect(place.prompt.length).toBeGreaterThan(40);
      expect(typeof place.generatedAt).toBe('string');
    }
  });

  it('records every supplied one with what it is and the original it came from', () => {
    for (const place of supplied) {
      if (place.source !== SUPPLIED) throw new Error('filtered wrong');
      // No model and no prompt, because nobody generated it — and the fields
      // are absent rather than blank, which is the difference between "does
      // not apply" and "we forgot".
      expect(place).not.toHaveProperty('generator');
      expect(place).not.toHaveProperty('prompt');
      expect(place.description.length).toBeGreaterThan(20);
      expect(typeof place.suppliedAt).toBe('string');
      // THE ORIGINAL IS IN THE REPOSITORY. An importer that reads somebody's
      // Downloads folder is an importer nobody else can re-run, and a
      // processed asset whose source has gone is an asset nobody can re-crop.
      expect(place.originalFile.startsWith('supplied/')).toBe(true);
      expect(existsSync(join(PLACE_ASSET_DIR, place.originalFile))).toBe(true);
    }
  });

  it('says in the manifest whose the supplied images are, and what does not apply to them', () => {
    // Recorded, not assumed. Two claims a reader of this folder needs: the
    // owner licenses these, and the generator's no-signage / no-faces
    // constraints are constraints on a generator — a statue and a lit brand
    // sign in a supplied photograph are the owner's call, not a defect.
    expect(supplied.length).toBeGreaterThan(0);
    const rights = manifest.supplied?.rights ?? '';
    expect(rights).toMatch(/owner/i);
    expect(rights).toMatch(/licen[cs]e/i);
    expect(rights).toMatch(/do not apply/i);
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

  it('stores every one of them at the one size the plate is drawn at', async () => {
    // A supplied photograph arrives at whatever shape its camera had — these
    // six came in at five different aspects — and the importer covers-crops it
    // to the size the generated set was already committed at. One band, one
    // stored size, whichever pipeline wrote it.
    for (const place of manifest.places) {
      const meta = await sharp(join(PLACE_ASSET_DIR, place.file)).metadata();
      expect({ code: place.code, w: meta.width, h: meta.height }).toEqual({
        code: place.code,
        w: PLACE_WIDTH,
        h: PLACE_HEIGHT,
      });
    }
  });

  it('asks for no brand marks, no signage and no faces, in every prompt', () => {
    // The constraint is appended from one shared string precisely so it cannot
    // go missing from one prompt; this is the test that says so. It is checked
    // on the prompt catalogue itself, which covers all fourteen places whether
    // or not a generated image is currently committed for each — a territory
    // whose picture is a supplied photograph today still has to have a
    // constrained prompt to fall back to.
    expect(PLACE_STYLE).toContain('no brand names or logos');
    expect(PLACE_STYLE).toContain('No recognisable faces');
    for (const place of PLACE_PROMPTS) {
      expect(place.scene.length).toBeGreaterThan(40);
    }
    // And every generated entry in the manifest carries it, which is what
    // proves the committed asset was made under the constraint rather than the
    // catalogue merely declaring one.
    for (const place of generated) {
      if (place.source !== GENERATED) throw new Error('filtered wrong');
      expect(place.prompt).toContain('no brand names or logos');
      expect(place.prompt).toContain('No recognisable faces');
    }
  });

  it('does NOT apply those constraints to a supplied photograph', () => {
    // Deliberate, and the reason the rights note exists. The prompt
    // constraints are instructions to a model; nobody instructed the owner's
    // camera. A supplied photograph carries no prompt at all, so there is
    // nothing here that could quietly start being read as a promise about
    // what is in the frame.
    for (const place of supplied) {
      expect(place).not.toHaveProperty('prompt');
    }
    expect(SUPPLIED_PLACES.map((p) => p.code).sort()).toEqual(
      supplied.map((p) => p.code).sort(),
    );
  });

  it('loads them all as data URLs, carrying their provenance', () => {
    const images = loadSeedPlaceImages();
    expect(images.length).toBe(manifest.places.length);
    for (const image of images) {
      expect(image.dataUrl.startsWith('data:image/jpeg;base64,')).toBe(true);
      expect(PLACE_SOURCES).toContain(image.source);
      if (image.source === GENERATED) {
        expect(image.generator).toMatch(/^gemini-/);
        expect(image.prompt).not.toBeNull();
      } else {
        // Null, not the empty string: a supplied photograph has no model and
        // no prompt, and "does not apply" is a different fact from "blank".
        expect(image.generator).toBeNull();
        expect(image.prompt).toBeNull();
      }
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
  } as const;

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

  it('carries a supplied photograph through with no model and no prompt', () => {
    const dir = fixtureDir(
      {
        places: [
          {
            code: 'FS',
            label: 'Free State',
            file: 'FS.jpg',
            source: SUPPLIED,
            description: 'Bloemfontein at dusk',
            originalFile: 'supplied/FS-original.jpg',
            mimeType: 'image/jpeg',
            bytes: 3,
            suppliedAt: '2026-09-29T00:00:00.000Z',
          },
        ],
      },
      { 'FS.jpg': Buffer.from([1, 2, 3]) },
    );
    expect(loadSeedPlaceImages(dir)).toEqual([
      {
        code: 'FS',
        dataUrl: `data:image/jpeg;base64,${Buffer.from([1, 2, 3]).toString('base64')}`,
        mimeType: 'image/jpeg',
        source: SUPPLIED,
        generator: null,
        prompt: null,
      },
    ]);
  });

  it('throws on a source nobody recognises, rather than defaulting to one', () => {
    // THE FAILURE MODE THIS GATE EXISTS FOR. `?? 'generated'` is the tempting
    // line here and it is the one thing the field may never do: it would put a
    // photograph on screen under the sentence "an illustration of the area",
    // which is exactly the confusion `place_images.source` was added to end.
    for (const bad of ['captured', '', undefined]) {
      const dir = fixtureDir(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        { places: [{ ...entry, source: bad } as any] },
        { 'GP.jpg': Buffer.from([1, 2, 3]) },
      );
      expect(() => loadSeedPlaceImages(dir)).toThrow(/not one of generated, supplied/);
    }
  });

  it('throws on an asset far over the plate’s budget', () => {
    // The generator and the importer are run by hand and the seed is run by
    // everyone, so the seed is where a 400 kB picture somebody dropped in gets
    // caught.
    const dir = fixtureDir(
      { places: [{ ...entry, bytes: PLACE_MAX_BYTES * 2 }] },
      { 'GP.jpg': Buffer.alloc(PLACE_MAX_BYTES * 2) },
    );
    expect(() => loadSeedPlaceImages(dir)).toThrow(/budget/);
  });
});
