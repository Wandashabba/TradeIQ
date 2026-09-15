import { DEFAULT_CLIENT_TIME_ZONE } from '../../lib/clientTime';
import {
  computeFraudSignals,
  DEFAULT_REPEATING_STOCK_RUN_LENGTH,
  FraudRelatedInput,
  FraudStockCount,
  FraudStockVisit,
  FraudVisitInput,
  MAX_REPEATING_STOCK_RUN_LENGTH,
  MIN_EXPECTED_MOVEMENT_UNITS,
  REPEATING_STOCK_RUN_LENGTH_KEY,
  REPEATING_STOCK_START_LOOKBACK_VISITS,
  repeatingStockLookbackVisits,
  repeatingStockRunLength,
} from './fraud.service';

/**
 * #245 — "2-1, 2-1": the same counts submitted visit after visit. Real shelf
 * stock moves, so a run of identical counts suggests the agent copied the last
 * visit. The issue's calibration warning is what most of these tests pin: a slow
 * SKU legitimately reads the same, so the signal needs a 3+ run, a SKU whose own
 * velocity says it should have moved, and a weight that never flags alone.
 */
describe('repeating_stock_counts (#245)', () => {
  const checkinTs = new Date('2026-07-13T09:00:00.000Z');
  const daysBefore = (d: number) => new Date(checkinTs.getTime() - d * 24 * 60 * 60 * 1000);

  // Well inside the fence, no device submit time (so neither dwell signal nor
  // the capture timeline can fire), counts captured: only #245 can speak.
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

  // A mover: 1.5 units/day, so a weekly run of 3 (14 days) expects 21 sold.
  const MOVER_VELOCITY = 1.5;
  // A long-tail SKU: 0.1 units/day expects 1.4 over the same run — under the
  // MIN_EXPECTED_MOVEMENT_UNITS floor, and exactly the case the issue protects.
  const SLOW_VELOCITY = 0.1;

  const count = (skuId: string, unitsAvailable: number, velocityAvg = MOVER_VELOCITY): FraudStockCount => ({
    skuId,
    unitsAvailable,
    velocityAvg,
  });
  const earlier = (days: number, stock: FraudStockCount[], visitId = `v-${days}`): FraudStockVisit => ({
    visitId,
    checkinTs: daysBefore(days),
    stock,
  });

  const related = (stockCounts: FraudStockCount[], priorStockVisits: FraudStockVisit[]): FraudRelatedInput => ({
    photos: [],
    sectionCreatedAts: [checkinTs],
    failedAttempts: [],
    stockCounts,
    priorStockVisits,
  });

  const score = (
    stock: FraudStockCount[],
    prior: FraudStockVisit[],
    kpi?: unknown,
    v: FraudVisitInput = visit(),
  ) => computeFraudSignals(v, related(stock, prior), kpi, DEFAULT_CLIENT_TIME_ZONE);
  const codes = (...args: Parameters<typeof score>) => score(...args).signals.map((s) => s.code);

  // The basket counted today, identical on the two previous weekly visits.
  const basket = [count('A', 2), count('B', 1)];
  const weeklyRun = (stock = basket) => [earlier(7, stock), earlier(14, stock)];

  describe('fires on a run of identical counts', () => {
    it('scores a whole basket unchanged across 3 consecutive visits at 15', () => {
      const result = score(basket, weeklyRun());

      expect(result.signals).toEqual([
        {
          code: 'repeating_stock_counts',
          detail:
            'Whole basket unchanged: all 2 SKU counts identical across the last 3 submitted ' +
            'visits to this outlet, 2 of them selling fast enough by their own velocity that the ' +
            'count should have moved (longest run 3 visits, by device check-in)',
          weight: 15,
        },
      ]);
      expect(result.riskScore).toBe(15);
    });

    it('fires on a longer run too, at the same flat weight, reporting its length', () => {
      const result = score(basket, [earlier(7, basket), earlier(14, basket), earlier(21, basket)]);
      expect(result.riskScore).toBe(15);
      expect(result.signals[0].detail).toContain('longest run 4 visits');
    });

    it('ignores visits with no stock between the run, which record nothing to compare', () => {
      const noStock = earlier(10, []);
      expect(codes(basket, [earlier(7, basket), noStock, earlier(14, basket)])).toEqual([
        'repeating_stock_counts',
      ]);
    });
  });

  describe('silent below the run length', () => {
    it('is silent for two identical visits — a slow SKU does that honestly', () => {
      expect(codes(basket, [earlier(7, basket), earlier(14, [count('A', 5), count('B', 3)])])).toEqual([]);
    });

    it('is silent when one count in the middle of the run moved', () => {
      expect(codes(basket, [earlier(7, [count('A', 3), count('B', 2)]), earlier(14, basket)])).toEqual([]);
    });

    it('treats a visit that did not record the SKU as ending its run, not continuing it', () => {
      expect(codes([count('A', 2)], [earlier(7, [count('B', 9)]), earlier(14, [count('A', 2)])])).toEqual([]);
    });
  });

  describe('silent for slow movers and empty shelves', () => {
    it('is silent when the SKU sells too slowly to be expected to move over the run', () => {
      const slow = [count('A', 2, SLOW_VELOCITY), count('B', 1, SLOW_VELOCITY)];
      // Sanity: the fixture really does sit under the floor.
      expect(SLOW_VELOCITY * 14).toBeLessThan(MIN_EXPECTED_MOVEMENT_UNITS);
      expect(codes(slow, weeklyRun(slow))).toEqual([]);
    });

    it('is silent when the SKU has no velocity at all (no history before the run)', () => {
      const still = [count('A', 2, 0), count('B', 1, 0)];
      expect(codes(still, weeklyRun(still))).toEqual([]);
    });

    it('is silent for an out-of-stock SKU reading 0, however fast it used to sell', () => {
      const empty = [count('A', 0), count('B', 0)];
      expect(codes(empty, weeklyRun(empty))).toEqual([]);
    });

    it('is silent when the whole run happened in one day — nothing had time to sell', () => {
      const sameDay = [earlier(0.1, basket), earlier(0.2, basket)];
      expect(codes(basket, sameDay)).toEqual([]);
    });

    it("reads velocity from the run's FIRST row, so copies cannot dilute it to zero", () => {
      // The newer rows' stored velocity has been dragged to 0 by the copied
      // (zero-consumption) intervals themselves. The run's first row was derived
      // before the run began, and says this SKU sells.
      const diluted = [count('A', 2, 0), count('B', 1, 0)];
      const result = score(diluted, [earlier(7, diluted), earlier(14, basket)]);
      expect(result.signals.map((s) => s.code)).toEqual(['repeating_stock_counts']);

      // And the other way: a SKU that never sold before the run stays silent,
      // even if a later row's velocity reads high.
      const firstSlow = [count('A', 2, 0), count('B', 1, 0)];
      expect(codes([count('A', 2, 9), count('B', 1, 9)], [earlier(7, basket), earlier(14, firstSlow)])).toEqual(
        [],
      );
    });
  });

  describe('the basket outweighs a single SKU', () => {
    it('scores a one-SKU basket repeating at 5, not the basket weight', () => {
      const result = score([count('A', 2)], weeklyRun([count('A', 2)]));
      expect(result.signals.map((s) => s.code)).toEqual(['repeating_stock_counts']);
      expect(result.riskScore).toBe(5);
      expect(result.signals[0].detail).toContain('1 of 1 SKU counts identical');
    });

    it('scores a partial repeat at 5 when at least half of the basket is unchanged', () => {
      const today = [count('A', 2), count('B', 1), count('C', 8)];
      const prior = [
        earlier(7, [count('A', 2), count('B', 1), count('C', 11)]),
        earlier(14, [count('A', 2), count('B', 1), count('C', 15)]),
      ];
      const result = score(today, prior);
      expect(result.riskScore).toBe(5);
      expect(result.signals[0].detail).toContain('2 of 3 SKU counts identical');
    });

    it('is silent when only a small share of the basket repeats', () => {
      const today = [count('A', 2), count('B', 4), count('C', 8)];
      const prior = [
        earlier(7, [count('A', 2), count('B', 6), count('C', 11)]),
        earlier(14, [count('A', 2), count('B', 9), count('C', 15)]),
      ];
      expect(codes(today, prior)).toEqual([]);
    });

    it('counts slow SKUs toward "whole basket unchanged", but needs at least one mover', () => {
      const mixed = [count('A', 2), count('B', 1, SLOW_VELOCITY)];
      expect(score(mixed, weeklyRun(mixed)).riskScore).toBe(15);
      expect(score(mixed, weeklyRun(mixed)).signals[0].detail).toContain('1 of them selling fast');
    });

    it('compares only SKUs with enough history: a newly ranged SKU does not break the basket', () => {
      // C appears for the first time today; it cannot have repeated or not.
      const today = [...basket, count('C', 40)];
      expect(score(today, weeklyRun()).riskScore).toBe(15);
    });

    it('leaves out a SKU recorded twice on one visit with two different counts', () => {
      // A re-submitted section with a corrected count: ambiguous, so not guessed.
      const today = [count('A', 2), count('A', 3), count('B', 1)];
      const result = score(today, weeklyRun());
      expect(result.riskScore).toBe(5);
      expect(result.signals[0].detail).toContain('1 of 1 SKU counts identical');
    });
  });

  describe('per-client run length', () => {
    const fourRun = [earlier(7, basket), earlier(14, basket), earlier(21, basket)];

    it('pins the key name, and ignores keys the engine does not read', () => {
      // #97: a seeded key nothing reads is silently inert.
      expect(REPEATING_STOCK_RUN_LENGTH_KEY).toBe('repeatingStockRunLength');
      expect(DEFAULT_REPEATING_STOCK_RUN_LENGTH).toBe(3);
      expect(codes(basket, weeklyRun(), { stockRunLength: 5, repeatingStockRun: 5 })).toEqual([
        'repeating_stock_counts',
      ]);
    });

    it('lengthens the run through kpiThresholds', () => {
      const kpi = { [REPEATING_STOCK_RUN_LENGTH_KEY]: 4 };
      expect(codes(basket, weeklyRun(), kpi)).toEqual([]);
      const result = score(basket, fourRun, kpi);
      expect(result.signals.map((s) => s.code)).toEqual(['repeating_stock_counts']);
      // The detail names the run length actually applied.
      expect(result.signals[0].detail).toContain('across the last 4 submitted visits');
    });

    it('never goes below 3: a shorter setting is the false positive the issue warns about', () => {
      expect(repeatingStockRunLength({ repeatingStockRunLength: 2 })).toBe(3);
      expect(repeatingStockRunLength({ repeatingStockRunLength: 0 })).toBe(3);
      expect(repeatingStockRunLength({ repeatingStockRunLength: -4 })).toBe(3);
      expect(repeatingStockRunLength({ repeatingStockRunLength: 'x' })).toBe(3);
      expect(codes(basket, [earlier(7, basket)], { repeatingStockRunLength: 2 })).toEqual([]);
    });

    it('floors fractions and clamps to the ceiling that bounds the history read', () => {
      expect(repeatingStockRunLength({ repeatingStockRunLength: 4.9 })).toBe(4);
      expect(repeatingStockRunLength({ repeatingStockRunLength: 500 })).toBe(MAX_REPEATING_STOCK_RUN_LENGTH);
      expect(repeatingStockLookbackVisits({})).toBe(2 + REPEATING_STOCK_START_LOOKBACK_VISITS);
      expect(repeatingStockLookbackVisits({ repeatingStockRunLength: 500 })).toBe(
        MAX_REPEATING_STOCK_RUN_LENGTH - 1 + REPEATING_STOCK_START_LOOKBACK_VISITS,
      );
    });
  });

  describe('silent without a finished visit, counts, or history', () => {
    it('is silent on a draft', () => {
      expect(codes(basket, weeklyRun(), {}, visit({ status: 'in_progress' }))).toEqual([]);
    });

    it('is silent for a visit with no stock counts', () => {
      expect(codes([], weeklyRun())).toEqual([]);
      const none = computeFraudSignals(visit(), {
        photos: [],
        sectionCreatedAts: [checkinTs],
        failedAttempts: [],
        priorStockVisits: weeklyRun(),
      }, {}, DEFAULT_CLIENT_TIME_ZONE);
      expect(none.signals).toEqual([]);
    });

    it('is silent with too little history, or none supplied', () => {
      expect(codes(basket, [earlier(7, basket)])).toEqual([]);
      expect(codes(basket, [])).toEqual([]);
      const unsupplied = computeFraudSignals(visit(), {
        photos: [],
        sectionCreatedAts: [checkinTs],
        failedAttempts: [],
        stockCounts: basket,
      }, {}, DEFAULT_CLIENT_TIME_ZONE);
      expect(unsupplied.signals).toEqual([]);
    });
  });

  describe('ordering on the device clock', () => {
    it('orders history by check-in time, whatever order it was supplied in', () => {
      const moved = [count('A', 7), count('B', 5)];
      // Supplied oldest-first: the visit 21 days ago is the one that differs.
      const shuffled = [earlier(21, moved), earlier(14, basket), earlier(7, basket)];
      expect(codes(basket, shuffled)).toEqual(['repeating_stock_counts']);
      // Swap which visit differs, and the run is broken whatever the order.
      const broken = [earlier(21, basket), earlier(14, moved), earlier(7, basket)];
      expect(codes(basket, broken)).toEqual([]);
    });

    it('ignores anything that is not strictly earlier: a later visit, or this visit itself', () => {
      const later = { visitId: 'v-later', checkinTs: new Date(checkinTs.getTime() + 86_400_000), stock: basket };
      const self = { visitId: 'v-now', checkinTs, stock: basket };
      expect(codes(basket, [later, self, earlier(7, basket)])).toEqual([]);
    });

    it('reads no further back than the lookback', () => {
      // A run whose start is out of view is scored from the oldest visible row.
      // Here that row's velocity is diluted to 0, so it errs silent.
      const diluted = [count('A', 2, 0), count('B', 1, 0)];
      const lookback = repeatingStockLookbackVisits({});
      const history = Array.from({ length: lookback }, (_, i) => earlier(7 * (i + 1), diluted));
      const beyond = earlier(7 * (lookback + 1), basket);
      expect(codes(diluted, [...history, beyond])).toEqual([]);
      // Bring the honest first row into view and it fires.
      expect(codes(diluted, [...history.slice(0, lookback - 1), beyond])).toEqual(['repeating_stock_counts']);
    });
  });

  describe('weight', () => {
    it('cannot reach the default review threshold (50) alone, however long the run or big the basket', () => {
      const big = Array.from({ length: 40 }, (_, i) => count(`S${i}`, i + 1));
      const history = Array.from({ length: 12 }, (_, i) => earlier(7 * (i + 1), big));
      const result = score(big, history);
      expect(result.riskScore).toBe(15);
      expect(result.riskScore).toBeLessThan(50);
    });

    it('corroborates other evidence', () => {
      const result = score(basket, weeklyRun(), {}, visit({ checkinDistanceM: 45 }));
      expect(result.signals.map((s) => s.code)).toEqual(['geofence_distance', 'repeating_stock_counts']);
      expect(result.riskScore).toBe(20 + 15);
    });
  });
});
