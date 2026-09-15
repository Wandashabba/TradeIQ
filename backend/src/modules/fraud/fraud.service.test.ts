import { fraudVisitInclude } from './fraud.service';

describe('fraudVisitInclude', () => {
  it('fraud scoring selects only the photo fields it reads, never the base64 url', () => {
    const photos = fraudVisitInclude.photos as { select?: Record<string, boolean> };
    // gpsTag + section for photo_gps_divergence (#317); timestamp + section for
    // capture_timeline_gap (#246); id + the two hashes for duplicate_photo (#244).
    expect(photos.select).toEqual({
      id: true,
      gpsTag: true,
      timestamp: true,
      section: true,
      contentHash: true,
      perceptualHash: true,
    });
    expect(photos.select).not.toHaveProperty('url');
    // The band array is index-only; the lookup rebuilds it from perceptualHash.
    expect(photos.select).not.toHaveProperty('perceptualHashBands');
  });
});
