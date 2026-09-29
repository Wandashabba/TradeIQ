import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';
import sharp from 'sharp';
import { SUPPLIED_PLACES, SUPPLIED_RIGHTS, type SuppliedPlace } from './places/supplied';
import { fitToBudget } from './generate-place-images';
import {
  PLACE_ASSET_DIR,
  PLACE_HEIGHT,
  PLACE_WIDTH,
  SUPPLIED,
  type PlaceManifest,
} from './seed/placeImages';

/**
 * BRINGS THE OWNER'S OWN PHOTOGRAPHS IN, BESIDE THE GENERATED ONES.
 *
 *     cd backend
 *     npm run import-place-images            # every supplied place
 *     npm run import-place-images -- GP-TSH  # just one
 *
 * The sibling of `generate-place-images.ts`, and deliberately the same shape:
 * one asset per territory under `assets/places/<CODE>.jpg`, one manifest entry
 * recording what it is, and the same byte budget met the same way. What
 * changes is the provenance — `source: 'supplied'`, no model, no prompt — and
 * that difference travels the whole way out: manifest → `place_images.source`
 * → `X-Image-Source` → the sentence the plate speaks. A supplied photograph is
 * never described as an illustration, and an illustration is never described
 * as a photograph.
 *
 * ## Where the input comes from
 *
 * `assets/places/supplied/`, **inside the repository**, and the originals are
 * committed. An importer that reads a path on one person's laptop is an
 * importer that runs exactly once; this one re-runs for anybody who clones
 * this, which is the same reason the generated JPEGs are committed rather than
 * fetched at seed time.
 *
 * ## The processing, which is the generated pipeline and not a second one
 *
 * Two steps, in this order:
 *
 * 1. **Geometry.** A supplied photograph arrives at whatever shape its camera
 *    or stock library had — 1600×1280, 924×617, 612×459 among these six — and
 *    the plate is one band. So each is cover-cropped from the centre to
 *    exactly [PLACE_WIDTH]×[PLACE_HEIGHT], the size every generated asset is
 *    already committed at. Centre, not `attention`: a crop that moves when
 *    sharp's saliency model moves is a crop nobody can review.
 * 2. **Budget.** [fitToBudget], imported from the generator — the same quality
 *    walk down from q82, the same ≤60 kB cap, the same reasoning about why low
 *    quality survives a plate that paints at 12% chroma under a #474747
 *    ceiling. Importing it rather than copying it is the point: two encoders
 *    that drift apart would put two different pictures in one band.
 *
 * Step 1 hands step 2 a PNG, so the only lossy encode in the chain is the one
 * the budget walk does.
 *
 * ## What this script does NOT do
 *
 * It does not check the pictures against the generator's constraints, because
 * those are constraints on a generator. See `SUPPLIED_RIGHTS`, which it writes
 * into the manifest: these are the owner's images to license, and the
 * no-signage / no-faces rules do not apply to them.
 */

/** The centre crop, at exactly the size every committed place image already is. */
async function normalise(original: Buffer): Promise<Buffer> {
  return sharp(original)
    .resize({
      width: PLACE_WIDTH,
      height: PLACE_HEIGHT,
      fit: 'cover',
      position: 'centre',
      // Enlargement is allowed on purpose: two of the six arrive smaller than
      // 1024 across, and one stored aspect is worth more than the handful of
      // real pixels a 612-wide original would keep. Under the plate's tone the
      // difference is not visible; the note on the manifest entry says so
      // rather than leaving somebody to discover it.
      withoutEnlargement: false,
    })
    .flatten({ background: '#000000' }) // a PNG with alpha must not become a white band
    .png()
    .toBuffer();
}

async function main(): Promise<void> {
  const only = process.argv.slice(2).filter((a) => !a.startsWith('-'));
  const wanted: readonly SuppliedPlace[] = only.length
    ? SUPPLIED_PLACES.filter((p) => only.includes(p.code))
    : SUPPLIED_PLACES;
  if (!wanted.length) {
    console.error(
      `No supplied place matches ${only.join(', ')}. Known: ${SUPPLIED_PLACES.map((p) => p.code).join(', ')}`,
    );
    process.exitCode = 1;
    return;
  }

  mkdirSync(PLACE_ASSET_DIR, { recursive: true });
  const manifest = readManifest();

  for (const place of wanted) {
    const source = join(PLACE_ASSET_DIR, place.originalFile);
    if (!existsSync(source)) {
      throw new Error(
        `${place.code}: ${place.originalFile} is not in the repository. ` +
          'Supplied originals are committed — copy it in first; nothing is read from outside.',
      );
    }
    process.stdout.write(`${place.code.padEnd(8)} ${place.label} … `);

    const meta = await sharp(readFileSync(source)).metadata();
    const { bytes, quality } = await fitToBudget(await normalise(readFileSync(source)));

    const file = `${place.code}.jpg`;
    writeFileSync(join(PLACE_ASSET_DIR, file), bytes);
    manifest.places = manifest.places.filter((p) => p.code !== place.code);
    manifest.places.push({
      code: place.code,
      label: place.label,
      file,
      // THE MARK, AND IT IS NOT `generated`. Everything downstream reads this
      // field; a photograph marked `generated` would have the plate call it an
      // illustration in the one sentence a manager is given about it.
      source: SUPPLIED,
      description: place.description,
      originalFile: place.originalFile,
      mimeType: 'image/jpeg',
      bytes: bytes.length,
      suppliedAt: new Date().toISOString(),
      ...(place.note ? { note: place.note } : {}),
    });
    console.log(
      `${(bytes.length / 1024).toFixed(1)} kB at q${quality} ` +
        `(from ${meta.width}×${meta.height} ${meta.format})`,
    );
  }

  // THE RIGHTS LINE, IN THE MANIFEST ITSELF. Written every run so it cannot
  // fall out of step with `SUPPLIED_RIGHTS`, and present the moment there is a
  // supplied image for it to be about.
  manifest.supplied = { rights: SUPPLIED_RIGHTS };
  manifest.places.sort((a, b) => a.code.localeCompare(b.code));
  // The rights note first, above six hundred lines of prompts: a statement
  // about who owns these has to be the first thing somebody opening the file
  // reads, not the last.
  const ordered: PlaceManifest = { supplied: manifest.supplied, places: manifest.places };
  writeFileSync(join(PLACE_ASSET_DIR, 'manifest.json'), `${JSON.stringify(ordered, null, 2)}\n`);
  console.log(
    `\n${wanted.length} image(s) written to ${PLACE_ASSET_DIR}. ` +
      'Look at them ON THE PLATE before you commit them — the tone treatment is ' +
      'severe and a picture that reads well in a viewer can read as grey noise ' +
      'behind the hero figure.',
  );
}

/** The manifest as it stands, so importing one place keeps the other thirteen. */
function readManifest(): PlaceManifest {
  const path = join(PLACE_ASSET_DIR, 'manifest.json');
  if (!existsSync(path)) return { places: [] };
  const existing = JSON.parse(readFileSync(path, 'utf8')) as PlaceManifest;
  return { ...existing, places: [...(existing.places ?? [])] };
}

if (require.main === module) {
  main().catch((err) => {
    console.error(`\n${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  });
}
