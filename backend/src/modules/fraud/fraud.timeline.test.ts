import {
  CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY,
  captureTimelineToleranceMs,
  computeFraudSignals,
  DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES,
  FraudPhotoInput,
  FraudRelatedInput,
  FraudVisitInput,
} from './fraud.service';

/**
 * #246 — were the stock counts and the shelf photos captured in the same
 * sitting? A stock row has only its SERVER createdAt, so the literal
 * stock-vs-photo comparison would mix clocks (the #101 mistake). Instead every
 * photo's DEVICE timestamp is placed against the visit's own DEVICE window —
 * check-in to submit — which brackets every count keyed in on the device.
 */
describe('capture_timeline_gap (#246)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');
  const minutesAfter = (m: number) => new Date(checkinTs.getTime() + m * 60_000);
  // A 20-minute visit on the device clock: inside both dwell edges, so no other
  // signal fires unless a test asks for one.
  const SUBMIT_MINUTES = 20;

  const ON_SITE = { lat: -26.2, lng: 28.0 };
  // ~1.1km from the check-in — past the 150m photo-divergence line.
  const FAR_AWAY = { lat: -26.21, lng: 28.0 };

  function visit(overrides: Partial<FraudVisitInput> = {}): FraudVisitInput {
    return {
      id: 'v1',
      status: 'submitted',
      agentId: 'a1',
      outletId: 'o1',
      checkinTs,
      checkinLat: ON_SITE.lat,
      checkinLng: ON_SITE.lng,
      checkinDistanceM: 5,
      submittedAtClient: minutesAfter(SUBMIT_MINUTES),
      ...overrides,
    };
  }

  const photo = (
    takenAtMinutes: number,
    extra: Partial<FraudPhotoInput> = {},
  ): FraudPhotoInput => ({
    gpsTag: ON_SITE,
    timestamp: minutesAfter(takenAtMinutes),
    section: 'stock',
    ...extra,
  });

  // The server received the stock rows hours later — an offline sync burst. The
  // signal must never read that as a gap.
  const related = (photos: FraudPhotoInput[]): FraudRelatedInput => ({
    photos,
    sectionCreatedAts: [new Date('2026-07-13T17:30:00.000Z')],
    failedAttempts: [],
  });

  const codes = (v: FraudVisitInput, photos: FraudPhotoInput[], kpi?: unknown) =>
    computeFraudSignals(v, related(photos), kpi).signals.map((s) => s.code);

  describe('fires outside the tolerance', () => {
    it('flags a shelf photo taken hours after the visit was submitted (device clock)', () => {
      // The issue's own example: counts at ~09:10, photo at 13:50.
      const result = computeFraudSignals(visit(), related([photo(5), photo(SUBMIT_MINUTES + 270)]));

      expect(result.signals.map((s) => s.code)).toEqual(['capture_timeline_gap']);
      expect(result.riskScore).toBe(15);
      expect(result.signals[0].detail).toBe(
        '1 photo(s) taken outside the visit; the furthest was 270 min after submit ' +
          '(device clock), beyond the 15 min tolerance',
      );
    });

    it('flags a shelf photo taken before the agent checked in', () => {
      const result = computeFraudSignals(visit(), related([photo(-20)]));

      expect(result.signals.map((s) => s.code)).toEqual(['capture_timeline_gap']);
      expect(result.signals[0].detail).toContain('20 min before check-in');
    });

    it('counts every photo outside, and reports the furthest', () => {
      const result = computeFraudSignals(
        visit(),
        related([photo(-40), photo(SUBMIT_MINUTES + 90), photo(10)]),
      );

      expect(result.signals[0].detail).toContain('2 photo(s) taken outside the visit');
      expect(result.signals[0].detail).toContain('90 min after submit');
      // Flat: more photos outside is the same finding, not a bigger one.
      expect(result.riskScore).toBe(15);
    });
  });

  describe('silent inside the tolerance', () => {
    it('is silent for photos taken during the visit, minutes apart from the counts', () => {
      expect(codes(visit(), [photo(0), photo(7), photo(SUBMIT_MINUTES)])).toEqual([]);
    });

    it('is silent at the edges: walking up to the door, or clock jitter, up to the tolerance', () => {
      const tol = DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES;
      expect(codes(visit(), [photo(-10)])).toEqual([]);
      // The edge itself is inside.
      expect(codes(visit(), [photo(-tol)])).toEqual([]);
      expect(codes(visit(), [photo(SUBMIT_MINUTES + tol)])).toEqual([]);
      // One minute past it is not.
      expect(codes(visit(), [photo(SUBMIT_MINUTES + tol + 1)])).toEqual(['capture_timeline_gap']);
    });
  });

  describe('silent when the timeline cannot be measured honestly', () => {
    const late = photo(SUBMIT_MINUTES + 270);

    it('emits nothing without a device submit time — there is no window to place a photo in', () => {
      expect(codes(visit({ submittedAtClient: null }), [late])).toEqual([]);
      expect(codes(visit({ submittedAtClient: undefined }), [late])).toEqual([]);
    });

    it('emits nothing for a photo with no device timestamp', () => {
      expect(codes(visit(), [{ gpsTag: ON_SITE }])).toEqual([]);
      expect(codes(visit(), [{ gpsTag: ON_SITE, timestamp: null, section: 'stock' }])).toEqual([]);
      expect(codes(visit(), [{ gpsTag: ON_SITE, timestamp: new Date('nope') }])).toEqual([]);
    });

    it('emits nothing with no photos', () => {
      expect(codes(visit(), [])).toEqual([]);
    });

    it('emits nothing on a draft, whose window has no end yet', () => {
      expect(codes(visit({ status: 'in_progress' }), [late])).toEqual([]);
    });

    it('leaves a visit with no counts to no_capture, which already says the stronger thing', () => {
      const result = computeFraudSignals(visit(), { ...related([late]), sectionCreatedAts: [] });
      expect(result.signals.map((s) => s.code)).toEqual(['no_capture']);
    });

    it('emits nothing when the device clock moved backwards between check-in and submit', () => {
      // Submit stamped before check-in: the window itself is not trustworthy.
      expect(codes(visit({ submittedAtClient: minutesAfter(-30) }), [late])).toEqual([]);
    });

    it('ignores a task-closure photo attached to the visit days later, by design', () => {
      const closure = photo(3 * 24 * 60, { section: 'task_closure', gpsTag: {} });
      expect(codes(visit(), [photo(5), closure])).toEqual([]);
    });

    it('ignores the server clock entirely: a late sync alone is not a gap', () => {
      // Every photo in the device window; the stock rows landed 8.5h later.
      expect(computeFraudSignals(visit(), related([photo(5)])).signals).toEqual([]);
    });
  });

  describe('per-client tolerance', () => {
    it('loosens and tightens through kpiThresholds', () => {
      const late = [photo(SUBMIT_MINUTES + 270)];
      expect(codes(visit(), late, { [CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY]: 300 })).toEqual([]);

      const tenAfter = [photo(SUBMIT_MINUTES + 10)];
      expect(codes(visit(), tenAfter)).toEqual([]);
      expect(codes(visit(), tenAfter, { [CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY]: 5 })).toEqual([
        'capture_timeline_gap',
      ]);
      // The detail names the tolerance actually applied.
      const [signal] = computeFraudSignals(visit(), related(tenAfter), {
        captureTimelineToleranceMinutes: 5,
      }).signals;
      expect(signal.detail).toContain('beyond the 5 min tolerance');
    });

    it('falls back to the default when the tolerance is not a positive number', () => {
      const fallback = DEFAULT_CAPTURE_TIMELINE_TOLERANCE_MINUTES * 60_000;
      expect(captureTimelineToleranceMs({})).toBe(fallback);
      expect(captureTimelineToleranceMs({ captureTimelineToleranceMinutes: 0 })).toBe(fallback);
      expect(captureTimelineToleranceMs({ captureTimelineToleranceMinutes: -5 })).toBe(fallback);
      // Zero would flag clock jitter on every visit with a photo.
      expect(
        codes(visit(), [photo(SUBMIT_MINUTES + 1)], { captureTimelineToleranceMinutes: 0 }),
      ).toEqual([]);
    });

    it('pins the key name, and ignores keys the engine does not read', () => {
      // #97: a seeded key nothing reads is silently inert.
      expect(CAPTURE_TIMELINE_TOLERANCE_MINUTES_KEY).toBe('captureTimelineToleranceMinutes');
      const late = [photo(SUBMIT_MINUTES + 270)];
      expect(
        codes(visit(), late, { photoTimestampToleranceMinutes: 300, captureToleranceMins: 300 }),
      ).toEqual(['capture_timeline_gap']);
    });
  });

  describe('interaction with the other signals', () => {
    it('tops up, rather than doubles, when the late photo is the same one whose GPS diverged', () => {
      // One stale photo, taken somewhere else at another time. That is one piece
      // of evidence seen twice: 25 + 5, not 25 + 15.
      const result = computeFraudSignals(
        visit(),
        related([photo(5), photo(SUBMIT_MINUTES + 270, { gpsTag: FAR_AWAY })]),
      );

      expect(result.signals.map((s) => s.code)).toEqual([
        'photo_gps_divergence',
        'capture_timeline_gap',
      ]);
      expect(result.signals[1].weight).toBe(5);
      expect(result.signals[1].detail).toContain('the same photo(s) as the GPS divergence');
      expect(result.riskScore).toBe(30);
    });

    it('scores in full when a different photo is out of the window', () => {
      // The far photo was taken during the visit; a separate on-site photo was
      // taken hours later. Two independent findings.
      const result = computeFraudSignals(
        visit(),
        related([photo(5, { gpsTag: FAR_AWAY }), photo(SUBMIT_MINUTES + 270)]),
      );

      expect(result.signals.map((s) => s.code)).toEqual([
        'photo_gps_divergence',
        'capture_timeline_gap',
      ]);
      expect(result.signals[1].weight).toBe(15);
      expect(result.riskScore).toBe(40);
    });

    it('scores in full when only some of the out-of-window photos diverged', () => {
      const result = computeFraudSignals(
        visit(),
        related([photo(-60, { gpsTag: FAR_AWAY }), photo(SUBMIT_MINUTES + 60)]),
      );
      expect(result.riskScore).toBe(25 + 15);
    });

    it('corroborates the dwell signals, on the same device clock', () => {
      // Slow: 90 minutes of dwell, and a photo long after submit.
      const slow = computeFraudSignals(
        visit({ submittedAtClient: minutesAfter(90) }),
        related([photo(90 + 120)]),
      );
      expect(slow.signals.map((s) => s.code)).toEqual(['slow_completion', 'capture_timeline_gap']);
      expect(slow.riskScore).toBe(10 + 15);

      // Fast: a 20-second visit whose shelf photo predates check-in by two hours
      // — the photo was not taken in that 20 seconds.
      const fast = computeFraudSignals(
        visit({ submittedAtClient: new Date(checkinTs.getTime() + 20_000) }),
        related([photo(-120)]),
      );
      expect(fast.signals.map((s) => s.code)).toEqual(['fast_completion', 'capture_timeline_gap']);
      expect(fast.riskScore).toBe(20 + 15);
    });

    it('cannot put a visit on the default review list (50) by itself, however many photos', () => {
      const many = Array.from({ length: 12 }, (_, i) => photo(SUBMIT_MINUTES + 60 * (i + 1)));
      const result = computeFraudSignals(visit(), related(many));
      expect(result.riskScore).toBe(15);
      expect(result.riskScore).toBeLessThan(50);
    });

    it('does not disturb the geofence and failed-attempt signals', () => {
      const result = computeFraudSignals(
        visit({ checkinDistanceM: 45 }),
        {
          ...related([photo(SUBMIT_MINUTES + 270)]),
          failedAttempts: [{ createdAt: minutesAfter(-30) }],
        },
      );
      expect(result.signals.map((s) => s.code)).toEqual([
        'geofence_distance',
        'failed_attempts',
        'capture_timeline_gap',
      ]);
      expect(result.riskScore).toBe(20 + 10 + 15);
    });
  });
});
