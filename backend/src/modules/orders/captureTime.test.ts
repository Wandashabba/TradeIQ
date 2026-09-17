import {
  MAX_CAPTURE_AGE_DAYS,
  MAX_CAPTURE_SKEW_SECONDS,
  captureFallbackLog,
  resolveCapturedAt,
} from './captureTime';

/**
 * The clamp on an order's device capture time (#338).
 *
 * Every case here falls back rather than throwing: the order has already been
 * taken in a shop, and refusing it to protect a date would be the worse trade.
 * What the tests pin is that the fallback is the RECEIVED time (never a
 * half-believed device time) and that it is reported, so a fleet of phones with
 * wrong clocks is visible rather than silently absorbed.
 */
describe('resolveCapturedAt (#338)', () => {
  const receivedAt = new Date('2026-10-01T06:15:00.000Z');
  const SECOND = 1000;
  const DAY = 24 * 60 * 60 * 1000;

  it('keeps a device time from the evening before, which is the whole point', () => {
    // 23:30 local on 30 September in Johannesburg (UTC+2), synced next morning.
    const captured = '2026-09-30T21:30:00.000Z';
    expect(resolveCapturedAt(captured, receivedAt)).toEqual({
      capturedAt: new Date(captured),
      fallbackReason: null,
    });
  });

  it('accepts an instant written with a numeric offset, not only Z', () => {
    const { capturedAt, fallbackReason } = resolveCapturedAt('2026-09-30T23:30:00+02:00', receivedAt);
    expect(fallbackReason).toBeNull();
    expect(capturedAt.toISOString()).toBe('2026-09-30T21:30:00.000Z');
  });

  it('falls back to the received time when the field is absent', () => {
    // The ordinary case for an outbox payload queued by a build that predates
    // the field. Not a fault, so it is `absent` rather than a rejection.
    for (const missing of [undefined, null]) {
      expect(resolveCapturedAt(missing, receivedAt)).toEqual({
        capturedAt: receivedAt,
        fallbackReason: 'absent',
      });
    }
  });

  it('falls back for anything that is not a full ISO-8601 instant', () => {
    // A naive datetime is refused with the rest: resolving it would mean
    // guessing a zone, which is the one thing a capture time must never do.
    for (const junk of ['', 'yesterday', '2026-09-30', '2026-09-30T23:30:00', 1759270000000, {}]) {
      expect(resolveCapturedAt(junk, receivedAt)).toEqual({
        capturedAt: receivedAt,
        fallbackReason: 'unparseable',
      });
    }
  });

  it('falls back when the device clock runs further ahead than the tolerance', () => {
    const justInside = new Date(receivedAt.getTime() + MAX_CAPTURE_SKEW_SECONDS * SECOND);
    const justOutside = new Date(justInside.getTime() + SECOND);

    // A few minutes of skew is ordinary and believed.
    expect(resolveCapturedAt(justInside.toISOString(), receivedAt).fallbackReason).toBeNull();
    // Past it, a fast clock would book this order into a month nobody has set
    // a target for yet.
    expect(resolveCapturedAt(justOutside.toISOString(), receivedAt)).toEqual({
      capturedAt: receivedAt,
      fallbackReason: 'future',
    });
    expect(
      resolveCapturedAt('2031-01-01T00:00:00.000Z', receivedAt).fallbackReason,
    ).toBe('future');
  });

  it('falls back for an absurdly old capture time', () => {
    const justInside = new Date(receivedAt.getTime() - MAX_CAPTURE_AGE_DAYS * DAY + SECOND);
    const justOutside = new Date(receivedAt.getTime() - MAX_CAPTURE_AGE_DAYS * DAY - SECOND);

    expect(resolveCapturedAt(justInside.toISOString(), receivedAt).fallbackReason).toBeNull();
    // A phone reset to its epoch would otherwise drop this order into a month
    // a manager has already been measured on.
    expect(resolveCapturedAt(justOutside.toISOString(), receivedAt)).toEqual({
      capturedAt: receivedAt,
      fallbackReason: 'too_old',
    });
    expect(resolveCapturedAt('1970-01-01T00:00:00.000Z', receivedAt).fallbackReason).toBe('too_old');
  });

  it('measures both bounds against the received time it was handed', () => {
    // Not against a fresh `new Date()` — one order must not be judged against
    // two different "now"s.
    const later = new Date('2027-01-01T00:00:00.000Z');
    const at = '2026-12-31T23:00:00.000Z';
    expect(resolveCapturedAt(at, receivedAt).fallbackReason).toBe('future');
    expect(resolveCapturedAt(at, later).fallbackReason).toBeNull();
  });
});

describe('captureFallbackLog', () => {
  const receivedAt = new Date('2026-10-01T06:15:00.000Z');
  const context = { clientId: 'client-1', agentId: 'agent-1', raw: '2031-01-01T00:00:00.000Z' };

  it('reports a device time we refused, naming the reason and what we used', () => {
    const resolved = resolveCapturedAt(context.raw, receivedAt);
    const line = captureFallbackLog(resolved, context);

    expect(line).toContain('future');
    expect(line).toContain('agent-1');
    expect(line).toContain('client-1');
    expect(line).toContain(context.raw);
    expect(line).toContain(receivedAt.toISOString());
  });

  it('says nothing when the device time was used as sent', () => {
    const resolved = resolveCapturedAt('2026-10-01T06:00:00.000Z', receivedAt);
    expect(captureFallbackLog(resolved, context)).toBeNull();
  });

  it('says nothing for a payload that simply has no capture time', () => {
    // An older build in the field is expected, not a fault. A line per order
    // would bury the two cases that mean a real clock problem.
    const resolved = resolveCapturedAt(undefined, receivedAt);
    expect(resolved.fallbackReason).toBe('absent');
    expect(captureFallbackLog(resolved, { ...context, raw: undefined })).toBeNull();
  });
});
