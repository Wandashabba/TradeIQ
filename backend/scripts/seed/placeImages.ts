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
 * 1. **Each one says what it is, and the data carries it.** Every row this
 *    module feeds into `place_images` carries a [PlaceImageSource]:
 *    `generated` for the ones `scripts/generate-place-images.ts` made, and
 *    `supplied` for a real photograph the owner handed over. Nothing
 *    downstream may present a generated picture as a capture, and nothing may
 *    describe a supplied photograph as an illustration — the marker is what
 *    lets the plate say something true either way. An unrecognised value is a
 *    throw, not a default: see [placeImageSource].
 * 2. **They are not evidence and cannot become evidence.** They live in a
 *    table of their own, keyed by territory, with no `visitId`, no GPS tag and
 *    no capture time — the three things that make a `Photo` row a reading. The
 *    visit-evidence, review-strip and pin-dispute paths never touch this
 *    module. That holds for a supplied photograph exactly as it holds for a
 *    generated one: a photograph of Bloemfontein is still not a reading of a
 *    shelf in it.
 * 3. **No network at seed time.** `scripts/generate-place-images.ts` calls the
 *    Gemini API once, by hand, `scripts/import-place-images.ts` reads files
 *    already committed under `assets/places/supplied/`, and the JPEGs both of
 *    them write are committed. A seed that needs a key and a signal is a seed
 *    that fails for the next person.
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

/**
 * The stored height, and therefore the stored aspect.
 *
 * It is 572 rather than 576 because that is what the image API returned for
 * `16:9` and the generated set was committed at it. A supplied photograph
 * arrives at whatever shape the owner's camera or stock library had, so the
 * importer covers-crops it to exactly this — the plate is one band and a
 * second aspect in the same table would be a second layout nobody designed.
 */
export const PLACE_HEIGHT = 572;

/** The `source` value every generated place image carries. */
export const GENERATED = 'generated';

/**
 * The `source` value a photograph the owner supplied carries.
 *
 * It is a different word from [GENERATED] because it is a different claim.
 * A generated picture is an illustration and the plate says so; a supplied one
 * is a real photograph of the place, and calling it an illustration would be
 * just as false as calling an illustration a photograph. What it is NOT, in
 * both cases, is evidence from a visit — that part of the sentence does not
 * move.
 */
export const SUPPLIED = 'supplied';

/**
 * Every value `place_images.source` may hold. The column is a string in
 * Postgres (an enum there would need a migration to grow), so this list is
 * the enum, and [placeImageSource] is the gate.
 */
export const PLACE_SOURCES = [GENERATED, SUPPLIED] as const;

export type PlaceImageSource = (typeof PLACE_SOURCES)[number];

export function isPlaceImageSource(value: unknown): value is PlaceImageSource {
  return typeof value === 'string' && (PLACE_SOURCES as readonly string[]).includes(value);
}

/**
 * [value] as a [PlaceImageSource], or a throw naming what it was.
 *
 * LOUD ON PURPOSE. The tempting shape here is `?? GENERATED`, and that is the
 * one thing this field may never do: a default would silently describe a
 * photograph as an illustration, or worse, an unattributed picture as either.
 * The marker travels manifest → `place_images.source` → `X-Image-Source` → a
 * sentence a manager reads, and a guess anywhere on that path is a lie at the
 * end of it.
 */
export function placeImageSource(value: unknown, what: string): PlaceImageSource {
  if (isPlaceImageSource(value)) return value;
  throw new Error(
    `${what}: source ${JSON.stringify(value)} is not one of ${PLACE_SOURCES.join(', ')}. ` +
      'A place image whose origin nobody stated must not reach the database — add the ' +
      'value to PLACE_SOURCES and give the plate a sentence for it, or fix the manifest.',
  );
}

/** What both kinds of manifest entry carry. */
interface PlaceManifestEntryCommon {
  /** `Territory.code` in the seed catalogue, or `ALL` for the footprint. */
  code: string;
  label: string;
  /** The processed asset, relative to `assets/places`. */
  file: string;
  mimeType: string;
  bytes: number;
}

/** One made by `scripts/generate-place-images.ts`. */
export interface GeneratedPlaceManifestEntry extends PlaceManifestEntryCommon {
  source: typeof GENERATED;
  /** The model that made it, e.g. `gemini-3.1-flash-image`. */
  generator: string;
  /** The prompt it was made from, so it can be reproduced or argued with. */
  prompt: string;
  generatedAt: string;
}

/** One the owner supplied, processed by `scripts/import-place-images.ts`. */
export interface SuppliedPlaceManifestEntry extends PlaceManifestEntryCommon {
  source: typeof SUPPLIED;
  /** What the photograph is of, in a sentence. There is no prompt to record. */
  description: string;
  /** The owner's original, relative to `assets/places` — kept, and committed. */
  originalFile: string;
  /** When it was brought in. Not when it was taken: nobody here knows that. */
  suppliedAt: string;
  /** Anything a reviewer has to know before looking at it on the plate. */
  note?: string;
}

export type PlaceManifestEntry = GeneratedPlaceManifestEntry | SuppliedPlaceManifestEntry;

export interface PlaceManifest {
  /**
   * The standing note about supplied images, written down rather than assumed.
   * See `scripts/import-place-images.ts`, which is what keeps it current.
   */
  supplied?: { rights: string };
  places: PlaceManifestEntry[];
}

export interface SeedPlaceImage {
  /** `Territory.code`, or `ALL` for the whole-footprint scope. */
  code: string;
  /** `data:image/jpeg;base64,…` */
  dataUrl: string;
  mimeType: string;
  source: PlaceImageSource;
  /** The model, for a generated one. Null for a supplied photograph. */
  generator: string | null;
  /** The prompt, for a generated one. Null for a supplied photograph. */
  prompt: string | null;
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
    // Before the bytes, the mark. A manifest entry with a source nobody
    // recognises stops the seed here rather than becoming a row the API will
    // later describe to a manager.
    const source = placeImageSource(entry.source, `place image ${entry.code}`);
    const bytes = readFileSync(file);
    // The cap is checked here and not only in the generator: the generator and
    // the importer are run by hand and the seed is run by everyone, so the seed
    // is the place a 400 kB picture someone dropped in by hand gets caught.
    const dataUrl = `data:${entry.mimeType};base64,${bytes.toString('base64')}`;
    if (dataUrl.length > PLACE_MAX_BYTES * 1.5) {
      throw new Error(
        `${entry.file} is ${(dataUrl.length / 1024).toFixed(0)} kB as a data URL; the plate's ` +
          `budget is ${PLACE_MAX_BYTES / 1024} kB. Re-run scripts/generate-place-images.ts ` +
          'or scripts/import-place-images.ts.',
      );
    }
    images.push({
      code: entry.code,
      dataUrl,
      mimeType: entry.mimeType,
      source,
      // A supplied photograph has neither, and null is the honest value for a
      // thing that does not exist — `''` would read as "recorded, and blank".
      generator: entry.source === GENERATED ? entry.generator : null,
      prompt: entry.source === GENERATED ? entry.prompt : null,
    });
  }
  return images;
}
