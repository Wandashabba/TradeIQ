import { detectBranding } from './vision.stub';

describe('detectBranding (stub)', () => {
  it('returns a result with the expected shape', async () => {
    const result = await detectBranding('https://example.com/photo.jpg');
    expect(typeof result.pass).toBe('boolean');
    expect(result.elementsDetected).toBeGreaterThanOrEqual(0);
    expect(result.elementsDetected).toBeLessThanOrEqual(8);
  });
});
