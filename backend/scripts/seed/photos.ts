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

/** One tint per section, so a manager's evidence rows look different. */
export const SECTION_TINTS: Record<string, Tint> = {
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
