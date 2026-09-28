import 'dotenv/config';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';
import sharp from 'sharp';
import {
  PLACE_PROMPTS,
  placePrompt,
  type PlacePrompt,
} from './places/prompts';
import { PLACE_ASSET_DIR, PLACE_MAX_BYTES, PLACE_WIDTH, type PlaceManifest } from './seed/placeImages';

/**
 * GENERATES THE SEED'S PLACE IMAGES — ONCE, BY HAND, AND NEVER AT SEED TIME.
 *
 *     cd backend
 *     npm run generate-place-images            # every place
 *     npm run generate-place-images -- GP-TSH  # just one, to reshoot it
 *
 * Needs `GEMINI_API_KEY` in `backend/.env`. Nothing else in the repo does:
 * the images it writes are **committed**, and `scripts/seed/placeImages.ts`
 * reads them off disk. A seed that needs a network and a key is a seed that
 * fails for the next person who clones this, so the API call lives here and
 * the seed never makes one.
 *
 * ## What it produces
 *
 * `backend/assets/places/<CODE>.jpg`, one per seeded territory plus `ALL.jpg`
 * for the whole-footprint scope, and `backend/assets/places/manifest.json`
 * recording — for every file — the model that made it, the prompt it was made
 * from, the date, and `source: "generated"`. That manifest is the provenance
 * the seed copies into the database, so a generated picture is marked as
 * generated at every layer it passes through.
 *
 * ## Why raw `fetch` and not `@google/genai`
 *
 * The SDK in this repo is pinned for the assistant's text orchestration, and
 * its image surface moves on a different clock. This is a hand-run script that
 * writes files a human then looks at; one documented POST is easier to keep
 * true than a second SDK version constraint on the API server's dependency
 * tree. The endpoint, the model id and the response shape were taken from the
 * published API at https://ai.google.dev/gemini-api/docs/image-generation on
 * 28 September 2026 and are named once, here.
 *
 * `generate-place-images.test.ts` does NOT call the API — a test that hits a
 * paid image endpoint on every push is a test somebody deletes within the
 * month. It exercises the prompts and [fitToBudget], which is the part with a
 * failure mode nobody would notice.
 *
 * ## The size budget
 *
 * The plate's budget is ≤60 kB (`docs/design/torchlight-aisle.md` §9c) measured
 * on what the client downloads, which is the JPEG itself: `GET
 * /territories/:id/place-image` serves these bytes, and the base64 in
 * `place_images.url` is a storage detail of the seed. The encoder walks the
 * JPEG quality down until it fits. A plate is drawn at 12% chroma under a
 * #474747 luminance ceiling, which hides encoder artefacts that would be
 * obvious on a bright screen — so the budget is met by quality rather than by
 * cropping the picture.
 */

/** The image model, from https://ai.google.dev/gemini-api/docs/image-generation. */
const MODEL = process.env.GEMINI_IMAGE_MODEL ?? 'gemini-3.1-flash-image';

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions';

/** The plate is a wide band; 16:9 is the closest the API offers. */
const ASPECT = '16:9';

interface GeneratedImage {
  readonly bytes: Buffer;
  readonly mimeType: string;
}

/**
 * One image from the API, or a thrown error naming what came back.
 *
 * Deliberately noisy on failure: the instruction this script was written under
 * is "if the API refuses, stop and report rather than shipping something worse
 * than the current fixture", and a script that silently wrote a grey rectangle
 * would be exactly that.
 */
async function generate(place: PlacePrompt, apiKey: string): Promise<GeneratedImage> {
  const response = await fetch(ENDPOINT, {
    method: 'POST',
    headers: {
      'x-goog-api-key': apiKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      input: [{ type: 'text', text: placePrompt(place) }],
      response_format: { type: 'image', mime_type: 'image/jpeg', aspect_ratio: ASPECT },
    }),
  });

  if (!response.ok) {
    // The body, never the key: the header is the only place it appears and it
    // is not echoed back.
    const body = await response.text().catch(() => '');
    throw new Error(
      `${place.code}: the image API answered ${response.status} ${response.statusText}. ${body.slice(0, 400)}`,
    );
  }

  const payload = (await response.json()) as unknown;
  const image = firstImage(payload);
  if (!image) {
    throw new Error(
      `${place.code}: the image API answered 200 with no image in it — a refusal, ` +
        'a safety block or a shape change. Nothing was written.',
    );
  }
  return image;
}

/**
 * Digs the first image part out of an `interaction`.
 *
 * The response is `{ steps: [{ type, content: [{ type: 'image', data, mime_type }] }] }`
 * with a `thought` step ahead of the output, and both the step list and the
 * content list are ordered but not fixed-length — so this walks rather than
 * indexes. An unknown shape returns undefined and the caller stops.
 */
function firstImage(payload: unknown): GeneratedImage | undefined {
  if (typeof payload !== 'object' || payload === null) return undefined;
  const steps = (payload as { steps?: unknown }).steps;
  if (!Array.isArray(steps)) return undefined;
  for (const step of steps) {
    const content = (step as { content?: unknown })?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const typed = part as { type?: unknown; data?: unknown; mime_type?: unknown };
      if (typed?.type !== 'image' || typeof typed.data !== 'string') continue;
      return {
        bytes: Buffer.from(typed.data, 'base64'),
        mimeType: typeof typed.mime_type === 'string' ? typed.mime_type : 'image/jpeg',
      };
    }
  }
  return undefined;
}

/**
 * Down to [PLACE_WIDTH] and then down in quality until it fits the plate's
 * byte budget.
 *
 * Exported for the test, which proves the loop terminates and respects the cap
 * rather than trusting one hand-tuned quality number to hold for every scene —
 * a hazy white sky compresses very differently from a jacaranda canopy.
 */
export async function fitToBudget(
  source: Buffer,
  maxBytes: number = PLACE_MAX_BYTES,
): Promise<{ bytes: Buffer; quality: number }> {
  const resized = sharp(source).resize({ width: PLACE_WIDTH, withoutEnlargement: true });
  let quality = 0;
  for (quality = 82; quality >= 28; quality -= 6) {
    const encoded = await resized.clone().jpeg({ quality, mozjpeg: true }).toBuffer();
    // The budget is on what the plate DOWNLOADS, which is the JPEG itself:
    // `GET /place-images` serves these bytes, and the base64 in `place_images.url`
    // is a storage detail of the seed (the same one `photos.url` has always had).
    //
    // Quality goes low without the picture suffering for it, and that is a
    // property of this particular surface rather than a shrug: the plate paints
    // at 12% chroma under a #474747 luminance ceiling, so the whole image lands
    // in a 71-step near-neutral band where ringing and blocking have nowhere to
    // show. The seed loader re-checks the stored size independently.
    if (encoded.length <= maxBytes) return { bytes: encoded, quality };
  }
  throw new Error(
    `could not fit the image under ${maxBytes} bytes even at quality ${quality + 6}; ` +
      'the scene is too detailed for the plate budget.',
  );
}

async function main(): Promise<void> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error(
      'GEMINI_API_KEY is not set. Put it in backend/.env — the same key the ' +
        'assistant uses. Nothing was written.',
    );
    process.exitCode = 1;
    return;
  }

  const only = process.argv.slice(2).filter((a) => !a.startsWith('-'));
  const wanted = only.length
    ? PLACE_PROMPTS.filter((p) => only.includes(p.code))
    : PLACE_PROMPTS;
  if (!wanted.length) {
    console.error(`No place matches ${only.join(', ')}. Known: ${PLACE_PROMPTS.map((p) => p.code).join(', ')}`);
    process.exitCode = 1;
    return;
  }

  mkdirSync(PLACE_ASSET_DIR, { recursive: true });
  const manifest: PlaceManifest = readManifest();

  for (const place of wanted) {
    process.stdout.write(`${place.code.padEnd(8)} ${place.label} … `);
    const raw = await generate(place, apiKey);
    const { bytes, quality } = await fitToBudget(raw.bytes);
    const file = `${place.code}.jpg`;
    writeFileSync(join(PLACE_ASSET_DIR, file), bytes);
    manifest.places = manifest.places.filter((p) => p.code !== place.code);
    manifest.places.push({
      code: place.code,
      label: place.label,
      file,
      // THE MARK. It travels: manifest → `place_images.source` → the API's
      // `X-Image-Source` header → the plate's spoken label. A generated
      // picture is never anything else anywhere in this product.
      source: 'generated',
      generator: MODEL,
      prompt: placePrompt(place),
      mimeType: 'image/jpeg',
      bytes: bytes.length,
      generatedAt: new Date().toISOString(),
    });
    console.log(`${(bytes.length / 1024).toFixed(1)} kB at q${quality}`);
  }

  manifest.places.sort((a, b) => a.code.localeCompare(b.code));
  writeFileSync(join(PLACE_ASSET_DIR, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`\n${wanted.length} image(s) written to ${PLACE_ASSET_DIR}. Look at them before you commit them.`);
}

/**
 * The manifest as it stands, so `-- GP-TSH` reshoots one place without
 * discarding the provenance of the other thirteen.
 */
function readManifest(): PlaceManifest {
  const path = join(PLACE_ASSET_DIR, 'manifest.json');
  if (!existsSync(path)) return { places: [] };
  const existing = JSON.parse(readFileSync(path, 'utf8')) as PlaceManifest;
  return { places: [...(existing.places ?? [])] };
}

if (require.main === module) {
  main().catch((err) => {
    console.error(`\n${err instanceof Error ? err.message : String(err)}`);
    process.exitCode = 1;
  });
}
