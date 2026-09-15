import { GEOFENCE_RADIUS_M, haversineDistanceMeters } from '../../lib/geofence';
import {
  computeFraudSignals,
  DEFAULT_STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS,
  FraudFailedAttempt,
  FraudOutletLocation,
  FraudPhotoInput,
  FraudRelatedInput,
  FraudVisitInput,
  STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS_KEY,
  stockOutsideOutletToleranceMeters,
} from './fraud.service';

/**
 * #248 — stock recorded against outlet A while the capture happened in another
 * of the client's outlets. Only the STRONG reading is scored: a photo from the
 * counting sitting (device window) geotagged inside a different outlet's fence
 * and clear of A's. The weak reading ("outside A's fence") has no evidence an
 * existing signal does not already score, and these tests pin that it stays
 * silent. The outlet lookup and its tenant scope are pinned in
 * fraud.outside.routes.test.ts.
 */
describe('stock_outside_outlet (#248)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');
  const minutesAfter = (m: number) => new Date(checkinTs.getTime() + m * 60_000);
  const SUBMIT_MINUTES = 20;

  const A = { lat: -26.2041, lng: 28.0473 };
  const M_PER_DEG_LAT = 111_195; // what haversine's 6371km sphere gives
  const offset = (from: { lat: number; lng: number }, northM: number, eastM = 0) => ({
    lat: from.lat + northM / M_PER_DEG_LAT,
    lng: from.lng + eastM / (M_PER_DEG_LAT * Math.cos((from.lat * Math.PI) / 180)),
  });

  const outlet = (outletId: string, at: { lat: number; lng: number }): FraudOutletLocation => ({
    outletId,
    code: outletId.toUpperCase(),
    ...at,
  });
  const OWN = outlet('o-a', A);
  // 120m north: clear of A's fence plus tolerance (75m), and under the 150m
  // photo-divergence line, so no other signal sees a photo taken there.
  const NEAR = outlet('o-near', offset(A, 120));
  // ~1.1km south: a photo here also trips photo_gps_divergence.
  const FAR = outlet('o-far', offset(A, -1100));

  function visit(overrides: Partial<FraudVisitInput> = {}): FraudVisitInput {
    return {
      id: 'v1',
      status: 'submitted',
      agentId: 'a1',
      outletId: OWN.outletId,
      checkinTs,
      checkinLat: A.lat,
      checkinLng: A.lng,
      checkinDistanceM: 5,
      submittedAtClient: minutesAfter(SUBMIT_MINUTES),
      ...overrides,
    };
  }

  const photoAt = (at: { lat: number; lng: number } | null, extra: Partial<FraudPhotoInput> = {}): FraudPhotoInput => ({
    gpsTag: at ?? {},
    timestamp: minutesAfter(10),
    section: 'visibility',
    ...extra,
  });

  const related = (
    photos: FraudPhotoInput[],
    extra: Partial<FraudRelatedInput> = {},
  ): FraudRelatedInput => ({
    photos,
    sectionCreatedAts: [minutesAfter(5)],
    failedAttempts: [],
    stockCounts: [{ skuId: 'sku-1', unitsAvailable: 7, velocityAvg: 0 }],
    nearbyOutlets: [OWN, NEAR, FAR],
    ...extra,
  });

  const score = (v: FraudVisitInput, r: FraudRelatedInput, kpi?: unknown) => computeFraudSignals(v, r, kpi);
  const codes = (v: FraudVisitInput, r: FraudRelatedInput, kpi?: unknown) => score(v, r, kpi).signals.map((s) => s.code);
  const outsideOf = (v: FraudVisitInput, r: FraudRelatedInput, kpi?: unknown) =>
    score(v, r, kpi).signals.find((s) => s.code === 'stock_outside_outlet');

  const attemptAt = (at: { lat: number; lng: number }, minutesBeforeCheckin = 30): FraudFailedAttempt => ({
    createdAt: new Date(checkinTs.getTime() - minutesBeforeCheckin * 60_000),
    ...at,
  });

  describe('the strong reading: inside another outlet of the same client', () => {
    it("fires when a photo from the counting sitting is geotagged inside another outlet's fence", () => {
      const result = score(visit(), related([photoAt(NEAR)]));

      expect(result.signals.map((s) => s.code)).toEqual(['stock_outside_outlet']);
      expect(result.riskScore).toBe(30);
      expect(result.signals[0].detail).toBe(
        "1 photo(s) taken while this visit's stock was being captured (device clock) are geotagged inside " +
          "another of this client's outlets; the nearest is 0m from outlet O-NEAR (inside its 50m fence) and " +
          "120m from this visit's outlet (beyond its fence plus the 25m tolerance)",
      );
    });

    it('never reaches the review threshold (50) on its own, whatever the variant', () => {
      const variants = [
        related([photoAt(NEAR)]),
        related([photoAt(FAR)]),
        related([photoAt(FAR), photoAt(NEAR), photoAt(offset(NEAR, 10))]),
        related([photoAt(FAR)], { failedAttempts: [attemptAt(FAR)] }),
      ];
      for (const r of variants) {
        expect(outsideOf(visit(), r)!.weight).toBeLessThan(50);
      }
    });

    it('names the nearest other outlet when two fences contain the photo', () => {
      const alsoNear = outlet('o-near-2', offset(NEAR, 30));
      const signal = outsideOf(visit(), related([photoAt(offset(NEAR, 20))], { nearbyOutlets: [OWN, alsoNear, NEAR] }));
      expect(signal!.detail).toContain('the nearest is 10m from outlet O-NEAR-2');
    });

    it('counts every placing photo, and does not scale with how many there are', () => {
      const signal = outsideOf(visit(), related([photoAt(NEAR), photoAt(offset(NEAR, 5)), photoAt(A)]));
      expect(signal!.weight).toBe(30);
      expect(signal!.detail).toMatch(/^2 photo\(s\)/);
    });
  });

  describe('silent at the outlet the stock was recorded against', () => {
    it('is silent for a photo at the visit’s own outlet', () => {
      expect(codes(visit(), related([photoAt(A)]))).toEqual([]);
    });

    it("is silent inside the own fence plus tolerance, even inside another outlet's fence (overlapping fences)", () => {
      // Two stores 70m apart in one centre: a fix between them is ambiguous.
      const neighbour = outlet('o-neighbour', offset(A, 70));
      expect(codes(visit(), related([photoAt(neighbour)], { nearbyOutlets: [OWN, neighbour] }))).toEqual([]);
    });

    it('is silent when the photo is outside every fence (the weak reading is not scored)', () => {
      // 100m east of A: outside A's fence and its tolerance, inside no other
      // outlet, under the divergence line. "Outside A" alone is not scored —
      // see the #248 notes in fraud.service.ts.
      expect(codes(visit(), related([photoAt(offset(A, 0, 100))]))).toEqual([]);
    });

    it('is silent for an outlet the bounding box returned but haversine puts outside the fence', () => {
      // A box corner: 45m north and 45m east of the photo is ~64m away.
      const corner = outlet('o-corner', offset(offset(A, 120), 45, 45));
      expect(codes(visit(), related([photoAt(offset(A, 120))], { nearbyOutlets: [OWN, corner] }))).toEqual([]);
    });
  });

  describe('silent without the evidence', () => {
    const inNear = () => related([photoAt(NEAR)]);

    it('is silent for a draft', () => {
      expect(codes(visit({ status: 'in_progress' }), inNear())).toEqual([]);
    });

    it('is silent without stock rows: the claim under test is stock recorded against this outlet', () => {
      expect(codes(visit(), related([photoAt(NEAR)], { stockCounts: [] }))).toEqual([]);
      expect(codes(visit(), related([photoAt(NEAR)], { stockCounts: undefined }))).toEqual([]);
    });

    it('is silent without coordinates on the photo', () => {
      expect(codes(visit(), related([photoAt(null)]))).toEqual([]);
      expect(codes(visit(), related([photoAt(null, { gpsTag: { lat: 'x', lng: 28 } })]))).toEqual([]);
    });

    it('is silent without a device window: no submittedAtClient, or submit before check-in', () => {
      expect(codes(visit({ submittedAtClient: null }), inNear())).toEqual([]);
      expect(codes(visit({ submittedAtClient: minutesAfter(-5) }), inNear())).toEqual([]);
    });

    it('is silent for a photo without a device timestamp, or a task-closure photo', () => {
      expect(codes(visit(), related([photoAt(NEAR, { timestamp: null })]))).toEqual([]);
      expect(codes(visit(), related([photoAt(NEAR, { section: 'task_closure' })]))).toEqual([]);
    });

    it("places only photos inside the visit's device window, widened by the capture-timeline tolerance", () => {
      // 10 minutes before check-in: inside the default 15-minute edge.
      const early = related([photoAt(NEAR, { timestamp: minutesAfter(-10) })]);
      expect(codes(visit(), early)).toEqual(['stock_outside_outlet']);
      // Tighten the window edge and the same photo is no longer from the sitting;
      // capture_timeline_gap reports the "when" instead.
      expect(codes(visit(), early, { captureTimelineToleranceMinutes: 5 })).toEqual(['capture_timeline_gap']);
    });

    it('is silent for a single-outlet tenant, or when the own outlet was not loaded', () => {
      expect(codes(visit(), related([photoAt(NEAR)], { nearbyOutlets: [OWN] }))).toEqual([]);
      expect(codes(visit(), related([photoAt(NEAR)], { nearbyOutlets: [NEAR, FAR] }))).toEqual([]);
      expect(codes(visit(), related([photoAt(NEAR)], { nearbyOutlets: undefined }))).toEqual([]);
    });
  });

  describe('interaction with the other location signals', () => {
    it('adds to geofence_distance: a fence-edge check-in and a photo in another store are two positions', () => {
      const result = score(visit({ checkinDistanceM: 45 }), related([photoAt(NEAR)]));
      expect(result.signals.map((s) => s.code)).toEqual(['geofence_distance', 'stock_outside_outlet']);
      expect(result.riskScore).toBe(20 + 30);
    });

    it('does not add a weak "outside the fence" score on top of geofence_distance', () => {
      const result = score(visit({ checkinDistanceM: 45 }), related([photoAt(offset(A, 0, 100))]));
      expect(result.signals.map((s) => s.code)).toEqual(['geofence_distance']);
      expect(result.riskScore).toBe(20);
    });

    it('only tops up photo_gps_divergence when the placing photo is the one it already scored', () => {
      const result = score(visit(), related([photoAt(FAR)]));
      expect(result.signals.map((s) => s.code)).toEqual(['photo_gps_divergence', 'stock_outside_outlet']);
      expect(result.signals[1].weight).toBe(20);
      expect(result.signals[1].detail).toMatch(/; the same photo\(s\) as the GPS divergence$/);
      expect(result.riskScore).toBe(25 + 20);
    });

    it('scores in full when a placing photo is independent of the divergence', () => {
      const result = score(visit(), related([photoAt(FAR), photoAt(NEAR)]));
      expect(outsideOf(visit(), related([photoAt(FAR), photoAt(NEAR)]))!.weight).toBe(30);
      expect(result.riskScore).toBe(25 + 30);
    });

    it('stays silent while photo_gps_divergence fires for a far photo inside no outlet', () => {
      expect(codes(visit(), related([photoAt(offset(A, -600))]))).toEqual(['photo_gps_divergence']);
    });
  });

  describe('rejected check-in attempts (the negative-signal dataset)', () => {
    it('restores the full weight when a rejected attempt was made from inside the same other outlet', () => {
      const result = score(visit(), related([photoAt(FAR)], { failedAttempts: [attemptAt(offset(FAR, 10))] }));
      expect(result.signals.map((s) => s.code)).toEqual([
        'failed_attempts',
        'photo_gps_divergence',
        'stock_outside_outlet',
      ]);
      const signal = result.signals[2];
      expect(signal.weight).toBe(30);
      expect(signal.detail).toMatch(
        /; the same photo\(s\) as the GPS divergence; a rejected check-in attempt for this outlet was also made from inside O-FAR$/,
      );
      expect(result.riskScore).toBe(10 + 25 + 30);
    });

    it('never fires from an attempt alone: the wrong-outlet tap at another store is benign', () => {
      expect(codes(visit(), related([photoAt(A)], { failedAttempts: [attemptAt(NEAR)] }))).toEqual(['failed_attempts']);
    });

    it('does not corroborate from a different outlet, from outside the 6h window, or without coordinates', () => {
      const cases: FraudFailedAttempt[] = [
        attemptAt(NEAR),
        attemptAt(FAR, 7 * 60),
        { createdAt: new Date(checkinTs.getTime() - 30 * 60_000) },
      ];
      for (const attempt of cases) {
        const signal = outsideOf(visit(), related([photoAt(FAR)], { failedAttempts: [attempt] }));
        expect(signal!.weight).toBe(20);
        expect(signal!.detail).not.toContain('rejected check-in attempt');
      }
    });
  });

  describe('configuration', () => {
    it('reads the fence from lib/geofence and the tolerance under a pinned per-client key', () => {
      // The key IS the contract: a stored override under any other name is ignored.
      expect(GEOFENCE_RADIUS_M).toBe(50);
      expect(STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS_KEY).toBe('stockOutsideOutletToleranceMeters');
      expect(DEFAULT_STOCK_OUTSIDE_OUTLET_TOLERANCE_METERS).toBe(25);
      expect(stockOutsideOutletToleranceMeters({})).toBe(25);
      expect(stockOutsideOutletToleranceMeters(null)).toBe(25);
      expect(stockOutsideOutletToleranceMeters({ stockOutsideOutletToleranceMeters: 40 })).toBe(40);
      expect(stockOutsideOutletToleranceMeters({ stockOutsideOutletToleranceMetres: 40 })).toBe(25);
    });

    it('honours 0 and falls back on a negative tolerance', () => {
      expect(stockOutsideOutletToleranceMeters({ stockOutsideOutletToleranceMeters: 0 })).toBe(0);
      expect(stockOutsideOutletToleranceMeters({ stockOutsideOutletToleranceMeters: -10 })).toBe(25);
    });

    it("applies the client's tolerance to the clearance from the own fence", () => {
      // 60m from A, inside another outlet's fence: within 50 + 25, so silent by
      // default; a client that sets 0 accepts "clear of the fence" as enough.
      const close = outlet('o-close', offset(A, 60));
      const r = related([photoAt(close)], { nearbyOutlets: [OWN, close] });
      expect(haversineDistanceMeters(A, close)).toBeGreaterThan(GEOFENCE_RADIUS_M);
      expect(codes(visit(), r)).toEqual([]);
      const zero = outsideOf(visit(), r, { stockOutsideOutletToleranceMeters: 0 });
      expect(zero!.detail).toContain('beyond its fence plus the 0m tolerance');
      // And a generous tolerance silences the 120m case.
      expect(codes(visit(), related([photoAt(NEAR)]), { stockOutsideOutletToleranceMeters: 100 })).toEqual([]);
      expect(codes(visit(), related([photoAt(NEAR)]), { stockOutsideOutletToleranceMeters: -1 })).toEqual([
        'stock_outside_outlet',
      ]);
    });
  });
});
