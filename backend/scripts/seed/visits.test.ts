import { mondayOfWeek, HISTORY_WEEKS } from './calendar';
import { buildOutlets, PROBLEM_OUTLET_CODES, SKUS, USERS } from './catalog';
import { buildVisitHistory, ratingBandFor } from './visits';

const ANCHOR = new Date('2026-07-28T00:00:00.000Z');
const OUTLETS = buildOutlets({ lat: -26.1076, lng: 28.0567, source: 'fallback' });
const AGENTS = USERS.filter((u) => u.role === 'field_agent');
const HISTORY = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });

function meanOf(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

describe('ratingBandFor', () => {
  // Must match kpiThresholds: green >= 80, amber >= 60, else red.
  it('maps totals onto the client\'s configured bands', () => {
    expect(ratingBandFor(85)).toBe('green');
    expect(ratingBandFor(80)).toBe('green');
    expect(ratingBandFor(79.9)).toBe('amber');
    expect(ratingBandFor(60)).toBe('amber');
    expect(ratingBandFor(59.9)).toBe('red');
  });
});

describe('buildVisitHistory', () => {
  it('generates a few hundred visits', () => {
    expect(HISTORY.length).toBeGreaterThanOrEqual(250);
    expect(HISTORY.length).toBeLessThanOrEqual(500);
  });

  // #204, the actual root cause: /trends buckets on each row's OWN createdAt,
  // which the old seed never set, so every row landed in the insert-time bucket.
  it('sets scorecard createdAt to the visit time, not insert time', () => {
    for (const visit of HISTORY) {
      expect(visit.scorecard.createdAt.toISOString()).toBe(visit.checkinTs.toISOString());
    }
  });

  it('sets stock-row createdAt to the visit time', () => {
    for (const visit of HISTORY) {
      for (const row of visit.stock) {
        expect(row.createdAt.toISOString()).toBe(visit.checkinTs.toISOString());
      }
    }
  });

  // #204's visible symptom: one weekly bucket means "Not enough data to plot",
  // because LineChart needs points.length >= 2.
  it('spreads scorecards across every week of history', () => {
    const buckets = new Set(
      HISTORY.map((v) => mondayOfWeek(v.scorecard.createdAt).toISOString()),
    );
    expect(buckets.size).toBe(HISTORY_WEEKS);
    expect(buckets.size).toBeGreaterThanOrEqual(3);
  });

  it('never generates a visit in the future', () => {
    for (const visit of HISTORY) {
      expect(visit.checkinTs.getTime()).toBeLessThanOrEqual(
        ANCHOR.getTime() + 24 * 60 * 60 * 1000,
      );
    }
  });

  // The demo's whole point: the line must visibly climb.
  it('improves materially from the first three weeks to the last three', () => {
    const weeks = [...new Set(HISTORY.map((v) => mondayOfWeek(v.checkinTs).getTime()))].sort();
    const firstThree = new Set(weeks.slice(0, 3));
    const lastThree = new Set(weeks.slice(-3));

    const early = meanOf(
      HISTORY.filter((v) => firstThree.has(mondayOfWeek(v.checkinTs).getTime()))
        .map((v) => v.scorecard.weightedTotal),
    );
    const late = meanOf(
      HISTORY.filter((v) => lastThree.has(mondayOfWeek(v.checkinTs).getTime()))
        .map((v) => v.scorecard.weightedTotal),
    );

    expect(late).toBeGreaterThan(early + 8);
  });

  it('keeps the problem outlets in the bottom band even at the end', () => {
    const problemIds = new Set(
      OUTLETS.filter((o) => (PROBLEM_OUTLET_CODES as readonly string[]).includes(o.code))
        .map((o) => o.id),
    );
    const problemMean = meanOf(
      HISTORY.filter((v) => problemIds.has(v.outletId)).map((v) => v.scorecard.weightedTotal),
    );
    const healthyMean = meanOf(
      HISTORY.filter((v) => !problemIds.has(v.outletId)).map((v) => v.scorecard.weightedTotal),
    );
    expect(problemMean).toBeLessThan(healthyMean - 10);
  });

  it('keeps every score inside a believable range', () => {
    for (const visit of HISTORY) {
      expect(visit.scorecard.weightedTotal).toBeGreaterThanOrEqual(25);
      expect(visit.scorecard.weightedTotal).toBeLessThanOrEqual(98);
    }
  });

  it('is deterministic — same anchor in, same scores out', () => {
    const again = buildVisitHistory({ anchor: ANCHOR, outlets: OUTLETS, agents: AGENTS, skus: SKUS });
    expect(again.map((v) => v.scorecard.weightedTotal)).toEqual(
      HISTORY.map((v) => v.scorecard.weightedTotal),
    );
  });

  it('gives every visit a full set of section rows', () => {
    for (const visit of HISTORY) {
      expect(visit.stock.length).toBeGreaterThan(0);
      expect(visit.pricing.length).toBeGreaterThan(0);
      expect(visit.competitive.length).toBeGreaterThan(0);
      expect(visit.visibility).toBeDefined();
      expect(visit.capability).toBeDefined();
    }
  });

  it('only ever assigns a visit to a real agent and a real outlet', () => {
    const agentIds = new Set(AGENTS.map((a) => a.id));
    const outletIds = new Set(OUTLETS.map((o) => o.id));
    for (const visit of HISTORY) {
      expect(agentIds.has(visit.agentId)).toBe(true);
      expect(outletIds.has(visit.outletId)).toBe(true);
    }
  });
});
