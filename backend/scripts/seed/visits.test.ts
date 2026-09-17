import { haversineDistanceMeters } from '../../src/lib/geofence';
import { addMonths, isWorkday, mondayOfWeek, monthsAgo } from './calendar';
import { PRICE_BREACH_CHAIN } from './catalog';
import { FlatHistory, FIXTURE_ANCHOR, generateFlatHistory } from './historyFixture';
import { monthKeyOf } from './history';
import {
  CHRONIC_OOS_SKU_ID,
  CHRONIC_OOS_TERRITORY_CODE,
  DECLINING_TERRITORY_CODE,
  FRAUD_AGENT_ID,
  STANDOUT_AGENT_ID,
  STRUGGLING_AGENT_ID,
  YOY_DECLINE_TERRITORY_CODE,
  YOY_GROWTH_TERRITORY_CODE,
} from './scenario';
import { SCORECARD_WEIGHTS, ratingBandFor } from './visits';

// Generating two years for half the outlets takes a few seconds; do it once.
jest.setTimeout(120_000);

let H: FlatHistory;

beforeAll(() => {
  H = generateFlatHistory({ outletFraction: 0.5 });
});

function mean(values: number[]): number {
  return values.reduce((sum, v) => sum + v, 0) / Math.max(1, values.length);
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

describe('the generated history', () => {
  it('is two years of a busy field team, every month of it', () => {
    // Half the outlets here; the full seed writes about 140k visits.
    expect(H.visits.length).toBeGreaterThan(80_000);
    const months = new Set(H.visits.map((v) => monthKeyOf(v.checkinTs)));
    expect(months.size).toBe(25);
  });

  it('never dates a visit today or in the future, and only on working days', () => {
    const today = FIXTURE_ANCHOR.getTime() - 2 * 60 * 60 * 1000; // local midnight in Johannesburg
    for (const visit of H.visits) {
      expect(visit.checkinTs.getTime()).toBeLessThan(today);
    }
    const days = new Set(H.visits.map((v) => new Date(v.checkinTs.getTime() + 2 * 60 * 60 * 1000).toISOString().slice(0, 10)));
    for (const day of days) expect(isWorkday(new Date(`${day}T00:00:00Z`))).toBe(true);
  });

  // #204, the actual root cause: /trends buckets on each row's OWN createdAt.
  it('sets every section row\'s createdAt to its visit time, not insert time', () => {
    const checkin = new Map(H.visits.map((v) => [v.id, v.checkinTs.getTime()]));
    for (const row of H.scorecards.slice(0, 5000)) expect(row.createdAt.getTime()).toBe(checkin.get(row.visitId));
    for (const row of H.stock.slice(0, 5000)) expect(row.createdAt.getTime()).toBe(checkin.get(row.visitId));
  });

  it('spreads scorecards across every week of history', () => {
    const weeks = new Set(H.scorecards.map((s) => mondayOfWeek(s.createdAt).toISOString()));
    expect(weeks.size).toBeGreaterThan(100);
  });

  it('checks every visit in inside the 50 m geofence', () => {
    const outlet = H.world.outletById;
    for (const visit of H.visits.slice(0, 5000)) {
      const o = outlet.get(visit.outletId)!;
      expect(haversineDistanceMeters(o, { lat: visit.checkinLat, lng: visit.checkinLng })).toBeLessThanOrEqual(50);
    }
  });

  it('weights the scorecard exactly as the client does', () => {
    for (const sc of H.scorecards.slice(0, 2000)) {
      const expected = Object.entries(SCORECARD_WEIGHTS).reduce(
        (sum, [dimension, weight]) => sum + weight * sc.dimensionScores[dimension]!,
        0,
      );
      expect(sc.weightedTotal).toBeCloseTo(expected, 0);
      expect(sc.ratingBand).toBe(ratingBandFor(sc.weightedTotal));
    }
  });

  it('records failed check-ins as well as passing ones', () => {
    expect(H.checkIns.some((c) => !c.passed)).toBe(true);
    expect(H.checkIns.filter((c) => c.passed)).toHaveLength(H.visits.length);
  });

  it('dates every order by capture, and keeps capture within its visit', () => {
    const visitById = new Map(H.visits.map((v) => [v.id, v]));
    for (const order of H.orders.slice(0, 5000)) {
      const visit = visitById.get(order.visitId)!;
      expect(order.capturedAt.getTime()).toBeLessThanOrEqual(visit.submittedAtClient.getTime());
      expect(order.createdAt.getTime()).toBeGreaterThanOrEqual(order.capturedAt.getTime());
    }
  });

  it('is deterministic — the same world gives the same history', () => {
    const again = generateFlatHistory({ outletFraction: 0.1, historyMonths: 1 });
    const once = generateFlatHistory({ outletFraction: 0.1, historyMonths: 1 });
    expect(again.visits.map((v) => [v.id, v.checkinTs.toISOString()])).toEqual(
      once.visits.map((v) => [v.id, v.checkinTs.toISOString()]),
    );
    expect(again.scorecards.map((s) => s.weightedTotal)).toEqual(once.scorecards.map((s) => s.weightedTotal));
    expect(again.orderLines.map((l) => l.quantity)).toEqual(once.orderLines.map((l) => l.quantity));
  });

  it('shows seasonality: a festive December peak and a January dip in sell-in', () => {
    const unitsByMonth = new Map<string, number>();
    const orderMonth = new Map(H.orders.map((o) => [o.id, monthKeyOf(o.capturedAt)]));
    for (const line of H.orderLines) {
      const key = orderMonth.get(line.orderId)!;
      unitsByMonth.set(key, (unitsByMonth.get(key) ?? 0) + line.quantity);
    }
    const perVisit = (month: string) =>
      unitsByMonth.get(month)! / H.visits.filter((v) => monthKeyOf(v.checkinTs) === month).length;
    expect(perVisit('2025-12')).toBeGreaterThan(perVisit('2025-11') * 1.2);
    expect(perVisit('2026-01')).toBeLessThan(perVisit('2025-11') * 0.8);
  });
});

describe('planted anomalies', () => {
  const territoryOf = () => new Map(H.world.outlets.map((o) => [o.id, o.territoryId]));

  function sellIn(filter: (territory: string, month: string) => boolean): number {
    const territory = territoryOf();
    const orders = new Map(
      H.orders.filter((o) => o.status !== 'cancelled').map((o) => [o.id, o]),
    );
    let units = 0;
    for (const line of H.orderLines) {
      const order = orders.get(line.orderId);
      if (order && filter(territory.get(order.outletId)!, monthKeyOf(order.capturedAt))) units += line.quantity;
    }
    return units;
  }

  it('1. a territory declines steadily over the last six months', () => {
    const month = (offset: number) => monthKeyOf(addMonths(H.world.anchorMonth, offset));
    const before = sellIn((t, m) => t === DECLINING_TERRITORY_CODE && m === month(-7));
    const after = sellIn((t, m) => t === DECLINING_TERRITORY_CODE && m === month(-1));
    expect(after).toBeLessThan(before * 0.75);
  });

  it('2. the best seller is chronically out of stock in one territory only', () => {
    const territory = territoryOf();
    const recent = new Map(
      H.visits.filter((v) => monthsAgo(v.checkinTs, FIXTURE_ANCHOR) < 3).map((v) => [v.id, territory.get(v.outletId)!]),
    );
    const rows = H.stock.filter((s) => s.skuId === CHRONIC_OOS_SKU_ID && recent.has(s.visitId));
    const rate = (inside: boolean) => {
      const subset = rows.filter((s) => (recent.get(s.visitId) === CHRONIC_OOS_TERRITORY_CODE) === inside);
      return subset.filter((s) => s.unitsAvailable === 0).length / subset.length;
    };
    expect(rate(true)).toBeGreaterThan(0.5);
    expect(rate(false)).toBeLessThan(0.1);
  });

  it('3. one chain prices above RRP, and only lately', () => {
    const chainOutlets = new Set(H.world.outlets.filter((o) => o.name.startsWith(`${PRICE_BREACH_CHAIN} `)).map((o) => o.id));
    const visit = new Map(H.visits.map((v) => [v.id, v]));
    const deviation = (inChain: boolean, recent: boolean) =>
      mean(
        H.pricing
          .filter((p) => {
            const v = visit.get(p.visitId)!;
            return chainOutlets.has(v.outletId) === inChain && (monthsAgo(v.checkinTs, FIXTURE_ANCHOR) < 3) === recent;
          })
          .map((p) => p.deviationPct),
      );
    expect(deviation(true, true)).toBeGreaterThan(10);
    expect(deviation(true, false)).toBeLessThan(4);
    expect(deviation(false, true)).toBeLessThan(3);
  });

  it('4. one agent\'s recent visits are seconds long, with reused photos', () => {
    const recent = H.visits.filter((v) => v.agentId === FRAUD_AGENT_ID && monthsAgo(v.checkinTs, FIXTURE_ANCHOR) < 2);
    const dwell = recent.map((v) => (v.submittedAtClient.getTime() - v.checkinTs.getTime()) / 1000);
    expect(Math.max(...dwell)).toBeLessThan(60);
    const photos = H.photos.filter((p) => p.uploadedById === FRAUD_AGENT_ID);
    expect(photos.length).toBeGreaterThan(recent.length);
    expect(new Set(photos.map((p) => p.seed)).size).toBeLessThanOrEqual(3);
    const older = H.visits.filter((v) => v.agentId === FRAUD_AGENT_ID && monthsAgo(v.checkinTs, FIXTURE_ANCHOR) > 4);
    expect(mean(older.map((v) => (v.submittedAtClient.getTime() - v.checkinTs.getTime()) / 60000))).toBeGreaterThan(8);
  });

  it('6. a standout agent and a struggling one sit far either side of the team', () => {
    const recentVisits = new Map(
      H.visits.filter((v) => monthsAgo(v.checkinTs, FIXTURE_ANCHOR) < 6).map((v) => [v.id, v.agentId]),
    );
    const scores = (predicate: (agentId: string) => boolean) =>
      mean(H.scorecards.filter((s) => recentVisits.has(s.visitId) && predicate(recentVisits.get(s.visitId)!)).map((s) => s.weightedTotal));
    const team = scores((a) => a !== STANDOUT_AGENT_ID && a !== STRUGGLING_AGENT_ID);
    expect(scores((a) => a === STANDOUT_AGENT_ID)).toBeGreaterThan(team + 8);
    expect(scores((a) => a === STRUGGLING_AGENT_ID)).toBeLessThan(team - 10);
  });

  it('7. one territory grows year on year and another shrinks', () => {
    const lastYear = (m: string) => `${Number(m.slice(0, 4)) - 1}${m.slice(4)}`;
    const recentMonths = Array.from({ length: 6 }, (_, i) => monthKeyOf(addMonths(H.world.anchorMonth, -1 - i)));
    const yoy = (code: string) =>
      sellIn((t, m) => t === code && recentMonths.includes(m)) /
      sellIn((t, m) => t === code && recentMonths.map(lastYear).includes(m));
    expect(yoy(YOY_GROWTH_TERRITORY_CODE)).toBeGreaterThan(1.25);
    expect(yoy(YOY_DECLINE_TERRITORY_CODE)).toBeLessThan(0.8);
    expect(yoy('GP-TSH')).toBeGreaterThan(0.9);
    expect(yoy('GP-TSH')).toBeLessThan(1.25);
  });

  it('keeps one outlet on one agent\'s route, so a visit always belongs to its owner', () => {
    for (const visit of H.visits.slice(0, 5000)) {
      expect(H.world.ownerByOutlet.get(visit.outletId)).toBe(visit.agentId);
    }
  });
});
