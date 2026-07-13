import { isVisionEnabled } from '../../lib/featureFlags';

/**
 * #92 — the CV seam must be impossible to enter by accident.
 *
 * `visibility.service.ts` OVERWRITES the agent's measured planogram %, facings
 * and cleanliness when it takes the vision path. While the implementation is
 * `vision.stub.ts` (`Math.random()`), entering that path means a real capture is
 * replaced by noise which then feeds the scorecard, the dashboard KPIs and the
 * perfect-store trend.
 */
describe('isVisionEnabled (#92)', () => {
  const original = process.env.VISION_ENABLED;

  afterEach(() => {
    if (original === undefined) {
      delete process.env.VISION_ENABLED;
    } else {
      process.env.VISION_ENABLED = original;
    }
  });

  it('is OFF when the flag is unset — the safe default', () => {
    delete process.env.VISION_ENABLED;
    expect(isVisionEnabled()).toBe(false);
  });

  it('is OFF for anything other than the exact string "true"', () => {
    // A truthy-looking value must not switch on a path that destroys real data.
    for (const value of ['1', 'yes', 'TRUE', 'on', '']) {
      process.env.VISION_ENABLED = value;
      expect(isVisionEnabled()).toBe(false);
    }
  });

  it('is ON only when explicitly enabled', () => {
    process.env.VISION_ENABLED = 'true';
    expect(isVisionEnabled()).toBe(true);
  });
});
