import { createHash } from 'crypto';
import sharp from 'sharp';
import { IMAGE_DATA_URL_RE, MAX_INPUT_PIXELS } from './thumbnails';

/**
 * Photo hashes for duplicate-photo detection (#244).
 *
 * Photos are base64 data URLs in Postgres (ADR 0007). Comparing those strings
 * directly is the trap the issue names: the column cannot be btree-indexed
 * (~2704-byte cap), so every comparison re-reads MBs per row. Instead each
 * photo gets two small hashes once, at upload:
 *
 *   - contentHash: SHA-256 of the decoded bytes. Byte-identical re-submission —
 *     the same file uploaded twice — and nothing else. Exact, cheap, btree-indexed.
 *   - perceptualHash: a 64-bit difference hash (dHash) of a 9x8 greyscale
 *     downscale. Each bit says whether a pixel is darker than its right-hand
 *     neighbour, so it describes the image's coarse structure and survives what
 *     a re-shared photo goes through: JPEG re-encoding, resizing, a light crop.
 *     Measured on synthetic shelf frames: re-encode 0-1 bits, downscale 1-8, a 3%
 *     crop 3-6, a 5% crop 5-7; unrelated frames 23+ (mean ~31).
 *
 * The perceptual hash is stored as 16 hex chars, not a BIGINT: it round-trips
 * through JSON (a BigInt does not) and Postgres reads it as bits directly
 * (`('x' || hash)::bit(64)`).
 */

export const PERCEPTUAL_HASH_BITS = 64;
// The index stores the hash as four 16-bit bands, each tagged with its position
// (band << 16 | value) so equal values in different positions do not collide.
// Why four: a near-duplicate lookup finds candidates by band, and the pigeonhole
// principle bounds what it can promise. Two hashes within 3 bits share at least
// one band exactly; within 7 bits, at least one band differs by at most one bit
// (four bands each off by 2+ would be 8+). Probing each band plus its 16
// one-bit neighbours therefore finds every match up to 7 bits, at a selectivity
// of ~1 in 1000 photos per probe set (68 keys over a 65536-value space).
// Wider bands would be more selective but guarantee less.
export const PERCEPTUAL_HASH_BAND_COUNT = 4;
export const PERCEPTUAL_HASH_BAND_BITS = 16;
// A near-uniform frame — lens covered, a blank wall, a smooth gradient — has
// almost no left-to-right edges, so its dHash is nearly all zeros (or all ones).
// Two such frames "match" while sharing nothing but emptiness, and would crowd
// the index's hottest band values. Below this many set bits (or above 64 minus
// it) a hash carries too little structure to compare: it gets no bands, so it is
// never a near-duplicate candidate. Exact (SHA-256) matching still applies.
export const MIN_PERCEPTUAL_HASH_SET_BITS = 8;

export interface PhotoHashes {
  contentHash: string | null;
  perceptualHash: string | null;
  perceptualHashBands: number[];
}

const NO_HASHES: PhotoHashes = { contentHash: null, perceptualHash: null, perceptualHashBands: [] };

const HEX_64_RE = /^[0-9a-f]{16}$/;

/** The decoded bytes of a base64 image data URL, or null if it is not one. */
export function decodeImageDataUrl(dataUrl: string): Buffer | null {
  const match = IMAGE_DATA_URL_RE.exec(dataUrl);
  return match ? Buffer.from(match[1], 'base64') : null;
}

/** SHA-256 of the bytes, as lowercase hex. */
export function contentHashOf(bytes: Buffer): string {
  return createHash('sha256').update(bytes).digest('hex');
}

/** 64-bit dHash as 16 lowercase hex chars. Throws if the bytes do not decode. */
export async function differenceHash(bytes: Buffer): Promise<string> {
  const width = 9;
  const height = 8;
  const pixels = await sharp(bytes, { limitInputPixels: MAX_INPUT_PIXELS })
    // Honour EXIF orientation first, so a portrait photo hashes the same whether
    // or not a re-encode baked the rotation in.
    .rotate()
    .greyscale()
    .resize(width, height, { fit: 'fill' })
    .raw()
    .toBuffer();
  let hash = 0n;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width - 1; x += 1) {
      const left = pixels[y * width + x];
      const right = pixels[y * width + x + 1];
      hash = (hash << 1n) | (left < right ? 1n : 0n);
    }
  }
  return hash.toString(16).padStart(PERCEPTUAL_HASH_BITS / 4, '0');
}

function popcount(value: number): number {
  let n = value;
  let count = 0;
  while (n) {
    count += n & 1;
    n >>>= 1;
  }
  return count;
}

/** Set bits in a 16-hex-char hash. */
function setBits(hex: string): number {
  let count = 0;
  for (let i = 0; i < hex.length; i += 4) {
    count += popcount(parseInt(hex.slice(i, i + 4), 16));
  }
  return count;
}

/** Bits that differ between two 16-hex-char hashes. */
export function hammingDistance(a: string, b: string): number {
  let distance = 0;
  for (let i = 0; i < PERCEPTUAL_HASH_BITS / 4; i += 4) {
    distance += popcount(parseInt(a.slice(i, i + 4), 16) ^ parseInt(b.slice(i, i + 4), 16));
  }
  return distance;
}

/** True for a hash too uniform to compare. See MIN_PERCEPTUAL_HASH_SET_BITS. */
export function isDegeneratePerceptualHash(hex: string): boolean {
  const bits = setBits(hex);
  return bits < MIN_PERCEPTUAL_HASH_SET_BITS || bits > PERCEPTUAL_HASH_BITS - MIN_PERCEPTUAL_HASH_SET_BITS;
}

/**
 * The largest Hamming distance a near-duplicate lookup can promise to find with
 * PERCEPTUAL_HASH_BAND_COUNT bands (see the band notes above): 2 x 4 - 1 = 7.
 * A threshold above it would silently miss matches the index never returned, so
 * callers clamp to it.
 */
export const MAX_NEAR_DUPLICATE_DISTANCE = 2 * PERCEPTUAL_HASH_BAND_COUNT - 1;

/**
 * The position-tagged band keys stored in `Photo.perceptualHashBands`. Empty for
 * a malformed or degenerate hash, which keeps it out of near-duplicate lookups.
 */
export function perceptualHashBands(hex: string | null): number[] {
  if (!hex || !HEX_64_RE.test(hex) || isDegeneratePerceptualHash(hex)) {
    return [];
  }
  const hexPerBand = PERCEPTUAL_HASH_BAND_BITS / 4;
  return Array.from({ length: PERCEPTUAL_HASH_BAND_COUNT }, (_, band) => {
    const value = parseInt(hex.slice(band * hexPerBand, (band + 1) * hexPerBand), 16);
    return (band << PERCEPTUAL_HASH_BAND_BITS) | value;
  });
}

/**
 * The band keys to probe `Photo.perceptualHashBands` with (`&&`, GIN) so every
 * stored hash within `maxDistance` bits of `hex` comes back as a candidate.
 * Candidates are a superset: the caller still measures the real distance.
 *
 * Within 3 bits, some band matches exactly, so the four stored keys suffice.
 * Within 7, some band is off by at most one bit, so each band is probed with its
 * 16 one-bit neighbours too (68 keys). Built from perceptualHashBands(), so the
 * probe and what upload stored cannot disagree about the key layout. Empty for a
 * malformed or degenerate hash, or a negative distance.
 */
export function perceptualHashProbeKeys(hex: string | null, maxDistance: number): number[] {
  const bands = perceptualHashBands(hex);
  if (bands.length === 0 || maxDistance < 0) {
    return [];
  }
  if (maxDistance < PERCEPTUAL_HASH_BAND_COUNT) {
    return bands;
  }
  const keys: number[] = [];
  for (const key of bands) {
    keys.push(key);
    for (let bit = 0; bit < PERCEPTUAL_HASH_BAND_BITS; bit += 1) {
      keys.push(key ^ (1 << bit));
    }
  }
  return keys;
}

/**
 * Both hashes for an uploaded data URL. Never throws: a payload that is not a
 * base64 image data URL gets no hashes, and bytes that do not decode as an image
 * keep their content hash but get no perceptual hash. Upload must not fail
 * because a fraud heuristic could not read the photo — POST /photos has only
 * ever validated that the payload is a bounded string (see thumbnails.ts).
 */
export async function computePhotoHashes(dataUrl: string): Promise<PhotoHashes> {
  const bytes = decodeImageDataUrl(dataUrl);
  if (!bytes || bytes.length === 0) {
    return NO_HASHES;
  }
  const contentHash = contentHashOf(bytes);
  let perceptualHash: string | null = null;
  try {
    perceptualHash = await differenceHash(bytes);
  } catch {
    perceptualHash = null;
  }
  return { contentHash, perceptualHash, perceptualHashBands: perceptualHashBands(perceptualHash) };
}
