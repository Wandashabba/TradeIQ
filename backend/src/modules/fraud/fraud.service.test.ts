import { fraudVisitInclude } from './fraud.service';

describe('fraudVisitInclude', () => {
  it('fraud scoring selects only the photo fields it reads, never the base64 url', () => {
    const photos = fraudVisitInclude.photos as { select?: Record<string, boolean> };
    // gpsTag for photo_gps_divergence; timestamp + section for
    // capture_timeline_gap (#246).
    expect(photos.select).toEqual({ gpsTag: true, timestamp: true, section: true });
    expect(photos.select).not.toHaveProperty('url');
  });
});
