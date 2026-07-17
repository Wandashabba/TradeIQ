import { fraudVisitInclude } from './fraud.service';

describe('fraudVisitInclude', () => {
  it('fraud scoring selects only gpsTag from photos, never the base64 url', () => {
    const photos = fraudVisitInclude.photos as { select?: Record<string, boolean> };
    expect(photos.select).toEqual({ gpsTag: true });
  });
});
