import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import { MAX_NEAR_DUPLICATE_DISTANCE } from '../photos/photoHash';
import {
  computeFraudSignals,
  DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE,
  DUPLICATE_PHOTO_MAX_DISTANCE_KEY,
  duplicatePhotoMaxDistance,
  FraudPhotoMatch,
  FraudVisitInput,
} from './fraud.service';

/**
 * #244 — the same shelf photo submitted again. The engine receives, per visit,
 * the hash matches the loader found (loadDuplicatePhotoMatches); these tests pin
 * how computeFraudSignals weighs them: another outlet over the same outlet,
 * exact over near, and the exclusions (task closure, later visits, no hash).
 */
describe('duplicate_photo (#244)', () => {
  const checkinTs = new Date('2026-09-10T09:00:00.000Z');
  const daysBefore = (d: number) => new Date(checkinTs.getTime() - d * 24 * 60 * 60 * 1000);

  // Well inside the fence, no device submit time, no counts: only #244 speaks.
  function visit(overrides: Partial<FraudVisitInput> = {}): FraudVisitInput {
    return {
      id: 'v-now',
      status: 'submitted',
      agentId: 'a1',
      outletId: 'o1',
      checkinTs,
      checkinLat: -26.2,
      checkinLng: 28.0,
      checkinDistanceM: 5,
      ...overrides,
    };
  }

  const match = (overrides: Partial<FraudPhotoMatch> = {}): FraudPhotoMatch => ({
    photoId: 'p1',
    section: 'visibility',
    exact: true,
    distance: 0,
    matchVisitId: 'v-earlier',
    matchOutletId: 'o2',
    matchCheckinTs: daysBefore(3),
    matchSection: 'visibility',
    ...overrides,
  });

  const score = (
    photoMatches: FraudPhotoMatch[] | undefined,
    kpi?: unknown,
    v: FraudVisitInput = visit(),
    timeZone: string = DEFAULT_CLIENT_TIME_ZONE,
  ) =>
    computeFraudSignals(
      v,
      { photos: [], sectionCreatedAts: [checkinTs], failedAttempts: [], photoMatches },
      kpi,
      timeZone,
    );
  const codes = (...args: Parameters<typeof score>) => score(...args).signals.map((s) => s.code);

  describe('weights: another outlet over the same outlet, exact over near', () => {
    it('scores a byte-identical photo from a visit to another outlet at 35', () => {
      const result = score([match()]);
      expect(result.signals).toEqual([
        {
          code: 'duplicate_photo',
          detail:
            '1 photo(s) on this visit match a photo from an earlier visit by this client; the strongest ' +
            'is byte-identical to a photo from a visit to a different outlet on 2026-09-07 (device check-in)',
          weight: 35,
        },
      ]);
      expect(result.riskScore).toBe(35);
    });

    it('scores a near-duplicate from another outlet at 25, naming the distance and threshold', () => {
      const result = score([match({ exact: false, distance: 4 })]);
      expect(result.riskScore).toBe(25);
      expect(result.signals[0].detail).toContain(
        'is a near-duplicate (4 of 64 bits differ, threshold 6) of a photo from a visit to a different outlet',
      );
    });

    it('scores a byte-identical photo from an earlier visit to the same outlet at 15', () => {
      const result = score([match({ matchOutletId: 'o1' })]);
      expect(result.riskScore).toBe(15);
      expect(result.signals[0].detail).toContain('byte-identical to a photo from a visit to this outlet');
    });

    it('scores a near-duplicate at the same outlet at 5, and says an unchanged shelf also does this', () => {
      const result = score([match({ matchOutletId: 'o1', exact: false, distance: 2 })]);
      expect(result.riskScore).toBe(5);
      expect(result.signals[0].detail).toContain('; the same shelf photographed from the same spot also looks alike');
    });

    it('reports one signal at the strongest match, counting the photos that matched', () => {
      const result = score([
        match({ photoId: 'p1', matchOutletId: 'o1', exact: false, distance: 1 }),
        match({ photoId: 'p2', matchOutletId: 'o1', exact: true }),
        match({ photoId: 'p2', matchOutletId: 'o3', exact: false, distance: 5, matchCheckinTs: daysBefore(9) }),
      ]);
      expect(result.signals.map((s) => s.code)).toEqual(['duplicate_photo']);
      expect(result.riskScore).toBe(25);
      expect(result.signals[0].detail).toMatch(/^2 photo\(s\) on this visit/);
      expect(result.signals[0].detail).toContain('different outlet on 2026-09-01');
    });

    it('does not scale with how many photos or visits matched', () => {
      const many = Array.from({ length: 30 }, (_, i) =>
        match({ photoId: `p${i}`, matchVisitId: `v${i}`, matchOutletId: `o-other-${i}` }),
      );
      expect(score(many).riskScore).toBe(35);
    });

    it('is exact whatever the perceptual distance says (or when there is none)', () => {
      expect(score([match({ exact: true, distance: null })]).riskScore).toBe(35);
      expect(score([match({ exact: true, distance: 40 })]).riskScore).toBe(35);
    });
  });

  describe('the near-duplicate threshold', () => {
    it('pins the key and the default, and ignores keys the engine does not read', () => {
      // #97: a seeded key nothing reads is silently inert.
      expect(DUPLICATE_PHOTO_MAX_DISTANCE_KEY).toBe('duplicatePhotoMaxDistance');
      expect(DEFAULT_DUPLICATE_PHOTO_MAX_DISTANCE).toBe(6);
      expect(codes([match({ exact: false, distance: 6 })])).toEqual(['duplicate_photo']);
      expect(codes([match({ exact: false, distance: 7 })])).toEqual([]);
      expect(codes([match({ exact: false, distance: 7 })], { duplicatePhotoHamming: 7, photoDistance: 7 })).toEqual([]);
    });

    it('widens and tightens per client through kpiThresholds', () => {
      const near7 = [match({ exact: false, distance: 7 })];
      expect(codes(near7, { [DUPLICATE_PHOTO_MAX_DISTANCE_KEY]: 7 })).toEqual(['duplicate_photo']);
      expect(codes([match({ exact: false, distance: 3 })], { [DUPLICATE_PHOTO_MAX_DISTANCE_KEY]: 2 })).toEqual([]);
      // 0 is a real setting: identical perceptual hashes only.
      expect(codes([match({ exact: false, distance: 0 })], { [DUPLICATE_PHOTO_MAX_DISTANCE_KEY]: 0 })).toEqual([
        'duplicate_photo',
      ]);
      // Tightening never silences an exact match.
      expect(codes([match()], { [DUPLICATE_PHOTO_MAX_DISTANCE_KEY]: 0 })).toEqual(['duplicate_photo']);
    });

    it('clamps to what the band index can find, floors fractions, and falls back on nonsense', () => {
      expect(duplicatePhotoMaxDistance({ duplicatePhotoMaxDistance: 500 })).toBe(MAX_NEAR_DUPLICATE_DISTANCE);
      expect(duplicatePhotoMaxDistance({ duplicatePhotoMaxDistance: 4.9 })).toBe(4);
      expect(duplicatePhotoMaxDistance({ duplicatePhotoMaxDistance: -1 })).toBe(6);
      expect(duplicatePhotoMaxDistance({ duplicatePhotoMaxDistance: 'x' })).toBe(6);
      expect(duplicatePhotoMaxDistance(undefined)).toBe(6);
      expect(codes([match({ exact: false, distance: 8 })], { duplicatePhotoMaxDistance: 500 })).toEqual([]);
    });

    it('never treats a match without a perceptual distance as near', () => {
      expect(codes([match({ exact: false, distance: null })])).toEqual([]);
    });
  });

  describe('what does not count', () => {
    it('ignores a task-closure photo on this visit — it is attached days later, by design', () => {
      expect(codes([match({ section: 'task_closure' })])).toEqual([]);
    });

    it('ignores a match that is itself a task-closure photo', () => {
      expect(codes([match({ matchSection: 'task_closure' })])).toEqual([]);
    });

    it('ignores the same visit: two sections sharing one photo is not reuse across visits', () => {
      expect(codes([match({ matchVisitId: 'v-now', matchOutletId: 'o1', matchCheckinTs: checkinTs })])).toEqual([]);
    });

    it('only accuses the later use: a match on a LATER visit is where this photo was copied to', () => {
      const later = new Date(checkinTs.getTime() + 60_000);
      expect(codes([match({ matchCheckinTs: later })])).toEqual([]);
    });

    it('breaks a check-in tie by visit id, like the #245 ordering', () => {
      expect(codes([match({ matchCheckinTs: checkinTs, matchVisitId: 'v-a' })])).toEqual(['duplicate_photo']);
      expect(codes([match({ matchCheckinTs: checkinTs, matchVisitId: 'v-z' })])).toEqual([]);
    });

    it('is silent with no matches, or none supplied (photos without hashes produce none)', () => {
      expect(codes([])).toEqual([]);
      expect(codes(undefined)).toEqual([]);
    });
  });

  describe("the matched visit's date, in the client's timezone (#325)", () => {
    // 23:30Z on 14 Sep is 01:30 SAST on the 15th, and 19:30 EDT on the 14th.
    const lateEvening = new Date('2026-09-14T23:30:00.000Z');
    // The reuse, checked in after both matches below.
    const reuse = () => visit({ checkinTs: new Date('2026-09-16T09:00:00.000Z') });
    const dateIn = (timeZone: string, matchCheckinTs: Date = lateEvening) =>
      score([match({ matchCheckinTs })], {}, reuse(), timeZone).signals[0].detail;

    it('reads a 23:30Z check-in as the next day for a Johannesburg client', () => {
      expect(dateIn('Africa/Johannesburg')).toContain('a different outlet on 2026-09-15 (device check-in)');
      expect(dateIn('Africa/Johannesburg')).not.toContain('2026-09-14');
    });

    it('reads the same check-in as the same day for a UTC or a New York client', () => {
      expect(dateIn('UTC')).toContain('a different outlet on 2026-09-14 (device check-in)');
      expect(dateIn('America/New_York')).toContain('a different outlet on 2026-09-14 (device check-in)');
    });

    it('reads an early-morning UTC check-in as the previous day west of Greenwich', () => {
      // 02:30Z on 15 Sep is 22:30 EDT on the 14th, and 04:30 SAST on the 15th.
      const earlyMorning = new Date('2026-09-15T02:30:00.000Z');
      expect(dateIn('America/New_York', earlyMorning)).toContain('on 2026-09-14 (device check-in)');
      expect(dateIn('UTC', earlyMorning)).toContain('on 2026-09-15 (device check-in)');
      expect(dateIn('Africa/Johannesburg', earlyMorning)).toContain('on 2026-09-15 (device check-in)');
    });

    it('changes only the wording: which match is chosen and its weight are zone-free', () => {
      const zones = ['Africa/Johannesburg', 'UTC', 'America/New_York'];
      const results = zones.map((zone) => score([match({ matchCheckinTs: lateEvening })], {}, reuse(), zone));
      for (const result of results) {
        expect(result.riskScore).toBe(35);
        expect(result.signals.map((s) => s.code)).toEqual(['duplicate_photo']);
      }
    });
  });

  describe('scope and weight', () => {
    it('speaks on a draft too: an uploaded photo is already evidence, like photo_gps_divergence', () => {
      expect(codes([match()], {}, visit({ status: 'in_progress' }))).toEqual(['duplicate_photo']);
    });

    it('cannot reach the default review threshold (50) alone', () => {
      expect(score([match()]).riskScore).toBeLessThan(50);
    });

    it('corroborates other evidence', () => {
      const result = score([match()], {}, visit({ checkinDistanceM: 45 }));
      expect(result.signals.map((s) => s.code)).toEqual(['geofence_distance', 'duplicate_photo']);
      expect(result.riskScore).toBe(20 + 35);
    });
  });
});
