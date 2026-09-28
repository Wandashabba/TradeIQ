import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

/**
 * THE SEED'S PLACE IMAGES, READ OFF DISK.
 *
 * A picture of the territory in scope — a street in Tshwane, a forecourt on
 * the East Rand, the Winelands — for The Floor's plate, so a manager's home
 * screen shows somewhere recognisable instead of the four rows of random
 * colour blocks `photos.ts` draws.
 *
 * Three facts about these files, and all three are load-bearing:
 *
 * 1. **They are generated, and the data says so.** Every row this module feeds
 *    into `place_images` carries `source: 'generated'` and the model that made
 *    it. Nothing downstream may present one as a capture.
 * 2. **They are not evidence and cannot become evidence.** They live in a
 *    table of their own, keyed by territory, with no `visitId`, no GPS tag and
 *    no capture time — the three things that make a `Photo` row a reading. The
 *    visit-evidence, review-strip and pin-dispute paths never touch this
 *    module.
 * 3. **No network at seed time.** `scripts/generate-place-images.ts` calls the
 *    Gemini API once, by hand, and the JPEGs are committed. A seed that needs
 *    a key and a signal is a seed that fails for the next person.
 *
 * A missing asset directory is not an error: the seed simply writes no place
 * images and The Floor draws its designed no-picture state, which is the same
 * thing it does for a tenant whose territories have never been photographed.
 */

/** `backend/assets/places`. */
export const PLACE_ASSET_DIR = join(__dirname, '..', '..', 'assets', 'places');

/**
 * The plate's byte budget (`docs/design/torchlight-aisle.md` §9c), measured on
 * the base64 the client actually downloads.
 */
export const PLACE_MAX_BYTES = 60 * 1024;

/**
 * The stored width. A 412dp plate at DPR 3 is ~1236px, but the plate decodes
 * at `cacheWidth` and paints at 12% chroma under a #474747 ceiling — detail
 * above this is spent on a band nobody can read detail in.
 */
export const PLACE_WIDTH = 1024;

/** The `source` value every generated place image carries. */
export const GENERATED = 'generated';

export interface PlaceManifestEntry {
  code: string;
  label: string;
  file: string;
  /** Always `generated` today. A column, not a constant, so a real commissioned
   * photograph could be dropped in beside these without the marker lying. */
  source: string;
  generator: string;
  prompt: string;
  mimeType: string;
  bytes: number;
  generatedAt: string;
}

export interface PlaceManifest {
  places: PlaceManifestEntry[];
}

export interface SeedPlaceImage {
  /** `Territory.code`, or `ALL` for the whole-footprint scope. */
  code: string;
  /** `data:image/jpeg;base64,…` */
  dataUrl: string;
  mimeType: string;
  source: string;
  generator: string;
  prompt: string;
}

/**
 * Every committed place image, or an empty list when the assets are not there.
 *
 * Reads the manifest rather than globbing the directory: the manifest is where
 * the provenance lives, and an image with no manifest entry is an image whose
 * origin nobody recorded — which is exactly the thing that must not reach the
 * database.
 */
export function loadSeedPlaceImages(dir: string = PLACE_ASSET_DIR): SeedPlaceImage[] {
  const manifestPath = join(dir, 'manifest.json');
  if (!existsSync(manifestPath)) return [];

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as PlaceManifest;
  const images: SeedPlaceImage[] = [];
  for (const entry of manifest.places ?? []) {
    const file = join(dir, entry.file);
    if (!existsSync(file)) continue;
    const bytes = readFileSync(file);
    // The cap is checked here and not only in the generator: the generator is
    // run by hand and the seed is run by everyone, so the seed is the place a
    // 400 kB picture someone dropped in by hand gets caught.
    const dataUrl = `data:${entry.mimeType};base64,${bytes.toString('base64')}`;
    if (dataUrl.length > PLACE_MAX_BYTES * 1.5) {
      throw new Error(
        `${entry.file} is ${(dataUrl.length / 1024).toFixed(0)} kB as a data URL; the plate's ` +
          `budget is ${PLACE_MAX_BYTES / 1024} kB. Re-run scripts/generate-place-images.ts.`,
      );
    }
    images.push({
      code: entry.code,
      dataUrl,
      mimeType: entry.mimeType,
      source: entry.source,
      generator: entry.generator,
      prompt: entry.prompt,
    });
  }
  return images;
}
