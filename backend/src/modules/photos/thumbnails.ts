import sharp from 'sharp';

/**
 * Thrown when a stored Photo.url cannot be turned into a thumbnail — either it
 * is not a base64 image data URL at all, or its bytes do not decode as an
 * image. POST /photos only validates that the payload is a bounded string, so
 * such rows can exist through perfectly normal use; 422 on the read path is
 * the deliberate answer, rather than a generic 500.
 */
export class ThumbnailSourceError extends Error {}

const THUMBNAIL_WIDTH = 256;
const THUMBNAIL_JPEG_QUALITY = 70;
const CACHE_MAX_ENTRIES = 50;

// The 8MB data-URL cap bounds the ENCODED size, not the decoded one — a
// few-KB PNG can declare huge dimensions and balloon to hundreds of MB of
// raw pixels. 32MP comfortably covers any real phone camera while keeping the
// worst-case decode allocation bounded; past it, sharp throws and the read
// path answers 422.
const MAX_INPUT_PIXELS = 32 * 1024 * 1024;

// data:image/<subtype>;base64,<payload> — anchored so a random string (or a
// non-image data URL) is rejected before we hand bytes to sharp.
const IMAGE_DATA_URL_RE = /^data:image\/[a-z0-9.+-]+;base64,([A-Za-z0-9+/=]+)$/i;

// Phase-1 in-memory LRU: a Map iterates in insertion order, so the first key
// is the least recently used entry — a hit re-inserts its key to refresh
// recency, and eviction is a delete of the first key. ~50 jpeg thumbnails at
// ≲60KB each keeps the cache under ~3MB.
const cache = new Map<string, Buffer>();
let cacheHits = 0;

/** Test probe: current entry count and lifetime hit count. */
export function thumbnailCacheProbe(): { size: number; hits: number } {
  return { size: cache.size, hits: cacheHits };
}

/**
 * Returns the cached thumbnail for `photoId`, or builds one from the photo's
 * stored data URL. `loadDataUrl` is only invoked on a cache miss so a hit
 * never drags the ~MB original out of the database.
 *
 * No single-flight de-duplication: concurrent misses for the same photo each
 * decode independently and the last one wins the cache slot — duplicated
 * sharp work, but harmless and acceptable at this scale.
 */
export async function getThumbnailForPhoto(
  photoId: string,
  loadDataUrl: () => Promise<string>,
): Promise<Buffer> {
  const hit = cache.get(photoId);
  if (hit) {
    cacheHits += 1;
    // Refresh recency: re-inserting moves the key to the back of the Map's
    // insertion order, so a hot thumbnail is never the eviction victim.
    cache.delete(photoId);
    cache.set(photoId, hit);
    return hit;
  }

  const dataUrl = await loadDataUrl();
  const match = IMAGE_DATA_URL_RE.exec(dataUrl);
  if (!match) {
    throw new ThumbnailSourceError('Stored photo is not a base64 image data URL');
  }

  let thumbnail: Buffer;
  try {
    thumbnail = await sharp(Buffer.from(match[1], 'base64'), {
      limitInputPixels: MAX_INPUT_PIXELS,
    })
      // Bake the EXIF orientation in — the thumbnail is served without
      // metadata, so an unrotated portrait shot would render sideways.
      .rotate()
      .resize({ width: THUMBNAIL_WIDTH })
      .jpeg({ quality: THUMBNAIL_JPEG_QUALITY })
      .toBuffer();
  } catch {
    throw new ThumbnailSourceError('Stored photo data could not be decoded as an image');
  }

  if (cache.size >= CACHE_MAX_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) {
      cache.delete(oldest);
    }
  }
  cache.set(photoId, thumbnail);
  return thumbnail;
}
