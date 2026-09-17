import sharp from 'sharp';

/**
 * Real, decodable evidence photos for the demo seed (#209).
 *
 * The old seed stored `https://demo.tradeiq.local/...`, which
 * `getThumbnailForPhoto` correctly 422s — so every evidence row rendered as a
 * grey box. These are genuine JPEGs.
 *
 * Built from a raw pixel buffer rather than an SVG, deliberately: SVG text
 * rendering needs librsvg with a working fontconfig, which is not guaranteed in
 * CI. Raw pixels depend on nothing.
 */

export type Tint = readonly [number, number, number];

const WIDTH = 320;
const HEIGHT = 240;
const JPEG_QUALITY = 82;

/** The sections the seed attaches evidence photos to. */
export type PhotoSection = 'visibility' | 'pricing' | 'competitive' | 'closure';

/**
 * One tint per section, so a manager's evidence rows look different.
 *
 * Keyed by a closed union rather than `string`: `noUncheckedIndexedAccess` is
 * off in this tsconfig, so a `Record<string, Tint>` would type a misspelled
 * `SECTION_TINTS.visiblity` as `Tint` and only fail at runtime, deep inside
 * `demoPhotoDataUrl`. A closed key set turns that typo into a compile error and
 * removes the need for `!` at every call site.
 */
export const SECTION_TINTS: Record<PhotoSection, Tint> = {
  visibility: [86, 122, 178],
  pricing: [196, 138, 62],
  competitive: [110, 148, 104],
  closure: [138, 116, 170],
};

function clamp255(value: number): number {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return Math.round(value);
}

/**
 * A vertical gradient with a darker horizontal band across the lower third, so
 * a 256px thumbnail reads as a shelf photo rather than a flat colour swatch.
 */
export async function demoPhotoDataUrl(tint: Tint): Promise<string> {
  const [r, g, b] = tint;
  const pixels = Buffer.alloc(WIDTH * HEIGHT * 3);

  for (let y = 0; y < HEIGHT; y += 1) {
    const gradient = 0.55 + 0.45 * (y / HEIGHT);
    const inBand = y > HEIGHT * 0.62 && y < HEIGHT * 0.78;
    const bandShift = inBand ? -38 : 0;
    for (let x = 0; x < WIDTH; x += 1) {
      const i = (y * WIDTH + x) * 3;
      pixels[i] = clamp255(r * gradient + bandShift);
      pixels[i + 1] = clamp255(g * gradient + bandShift);
      pixels[i + 2] = clamp255(b * gradient + bandShift);
    }
  }

  const jpeg = await sharp(pixels, {
    raw: { width: WIDTH, height: HEIGHT, channels: 3 },
  })
    .jpeg({ quality: JPEG_QUALITY })
    .toBuffer();

  return `data:image/jpeg;base64,${jpeg.toString('base64')}`;
}

const SHELF_WIDTH = 160;
const SHELF_HEIGHT = 120;
const SHELF_JPEG_QUALITY = 70;
const SHELF_ROWS = 4;

/**
 * A small, unique "shelf" photo for one seeded visit.
 *
 * Unique on purpose: the fraud engine flags a photo that already appeared on
 * another visit (#244), by SHA-256 and by perceptual hash. A shared placeholder
 * on every honest visit would make the whole field team look like it reuses
 * photos. Each image is four shelves of randomly sized, randomly coloured
 * product blocks from a PRNG seeded by `seed` — deterministic per seed, and far
 * apart in dHash terms from any other seed (unrelated frames sit at 25+ bits).
 *
 * 160x120 at quality 70 keeps each one to a few kilobytes of base64: the seed
 * only attaches photos to the last few weeks of visits, never to all of them.
 */
export async function shelfPhotoDataUrl(seed: number): Promise<string> {
  // mulberry32, inlined so this module keeps no dependency on the rng module.
  let a = (seed * 2654435761) >>> 0;
  const rnd = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  const pixels = Buffer.alloc(SHELF_WIDTH * SHELF_HEIGHT * 3);
  const rowHeight = SHELF_HEIGHT / SHELF_ROWS;
  for (let row = 0; row < SHELF_ROWS; row += 1) {
    let x = 0;
    while (x < SHELF_WIDTH) {
      const width = 6 + Math.floor(rnd() * 22);
      const colour = [Math.floor(rnd() * 256), Math.floor(rnd() * 256), Math.floor(rnd() * 256)];
      const top = Math.floor(row * rowHeight + rnd() * rowHeight * 0.35);
      const bottom = Math.floor((row + 1) * rowHeight) - 4;
      for (let y = Math.floor(row * rowHeight); y < Math.floor((row + 1) * rowHeight); y += 1) {
        for (let px = x; px < Math.min(SHELF_WIDTH, x + width); px += 1) {
          const i = (y * SHELF_WIDTH + px) * 3;
          const isShelfEdge = y >= bottom;
          const isProduct = y >= top && !isShelfEdge && px < x + width - 1;
          const [r, g, b] = isShelfEdge ? [70, 60, 50] : isProduct ? colour : [235, 235, 228];
          pixels[i] = r!;
          pixels[i + 1] = g!;
          pixels[i + 2] = b!;
        }
      }
      x += width;
    }
  }

  const jpeg = await sharp(pixels, { raw: { width: SHELF_WIDTH, height: SHELF_HEIGHT, channels: 3 } })
    .jpeg({ quality: SHELF_JPEG_QUALITY })
    .toBuffer();
  return `data:image/jpeg;base64,${jpeg.toString('base64')}`;
}
