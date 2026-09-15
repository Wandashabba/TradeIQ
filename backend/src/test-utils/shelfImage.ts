import sharp from 'sharp';

/**
 * A deterministic, shelf-like test photo: four shelves of product facings in
 * pseudo-random widths, heights and colours, rendered to JPEG. Different seeds
 * are unrelated frames; the same seed is the same frame. Real structure matters
 * for perceptual-hash tests — a flat or noise frame has no edges to hash (#244).
 */
export async function shelfJpeg(seed: number, quality = 92): Promise<Buffer> {
  const width = 800;
  const height = 600;
  let state = seed;
  const next = (): number => {
    state = (state * 1103515245 + 12345) % 2147483648;
    return state / 2147483648;
  };
  const rects: string[] = [];
  for (let shelf = 0; shelf < 4; shelf += 1) {
    const top = 20 + shelf * 145;
    let x = 10;
    while (x < width - 30) {
      const w = 30 + Math.floor(next() * 70);
      const h = 60 + Math.floor(next() * 70);
      const c = Math.floor(next() * 255);
      rects.push(
        `<rect x="${x}" y="${top + (130 - h)}" width="${w}" height="${h}" ` +
          `fill="rgb(${c},${255 - c},${(c * 7) % 255})"/>`,
      );
      x += w + 6;
    }
    rects.push(`<rect x="0" y="${top + 130}" width="${width}" height="10" fill="#333"/>`);
  }
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">` +
    `<rect width="100%" height="100%" fill="#eee"/>${rects.join('')}</svg>`;
  return sharp(Buffer.from(svg)).jpeg({ quality }).toBuffer();
}

/** The same frame as a re-shared copy: re-encoded at low quality and halved. */
export async function reencodedCopy(jpeg: Buffer): Promise<Buffer> {
  return sharp(jpeg).resize(400).jpeg({ quality: 60 }).toBuffer();
}

export function toDataUrl(bytes: Buffer, mime = 'image/jpeg'): string {
  return `data:${mime};base64,${bytes.toString('base64')}`;
}
