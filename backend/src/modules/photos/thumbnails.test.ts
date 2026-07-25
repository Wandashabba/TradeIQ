import sharp from 'sharp';
import { getThumbnailForPhoto, thumbnailCacheProbe } from './thumbnails';

// Pure unit tests for the in-memory cache — no HTTP, no database. The cache
// cap is 50 (CACHE_MAX_ENTRIES in thumbnails.ts); jest gives every test file
// a fresh module registry, so the module-level cache starts empty here.
const CACHE_CAP = 50;

describe('thumbnail cache', () => {
  let dataUrl: string;
  /** Loader invocations per photo id — a re-invocation proves a cache miss. */
  const loads = new Map<string, number>();

  const loaderFor = (photoId: string) => async () => {
    loads.set(photoId, (loads.get(photoId) ?? 0) + 1);
    return dataUrl;
  };

  const fetchThumb = (photoId: string) => getThumbnailForPhoto(photoId, loaderFor(photoId));

  beforeAll(async () => {
    const jpeg = await sharp({
      create: { width: 8, height: 8, channels: 3, background: { r: 10, g: 20, b: 30 } },
    })
      .jpeg()
      .toBuffer();
    dataUrl = `data:image/jpeg;base64,${jpeg.toString('base64')}`;
  });

  it('evicts by recency, not insertion order (true LRU)', async () => {
    // Fill the cache exactly to capacity: lru-0 (oldest) … lru-49 (newest).
    for (let i = 0; i < CACHE_CAP; i += 1) {
      await fetchThumb(`lru-${i}`);
    }
    expect(thumbnailCacheProbe().size).toBe(CACHE_CAP);

    // Hit the oldest entry — this must refresh its recency.
    const hitsBefore = thumbnailCacheProbe().hits;
    await fetchThumb('lru-0');
    expect(thumbnailCacheProbe().hits).toBe(hitsBefore + 1);
    expect(loads.get('lru-0')).toBe(1); // served from cache, not re-decoded

    // Insert one more at capacity — forces exactly one eviction. Under LRU
    // the victim is lru-1 (least recently used), NOT the just-hit lru-0.
    await fetchThumb('lru-50');
    expect(thumbnailCacheProbe().size).toBe(CACHE_CAP);

    // lru-0 survived: another fetch is a hit and the loader is not re-run.
    const hitsMid = thumbnailCacheProbe().hits;
    await fetchThumb('lru-0');
    expect(thumbnailCacheProbe().hits).toBe(hitsMid + 1);
    expect(loads.get('lru-0')).toBe(1);

    // lru-1 was evicted: fetching it re-invokes the loader (a miss).
    await fetchThumb('lru-1');
    expect(loads.get('lru-1')).toBe(2);
  });
});
