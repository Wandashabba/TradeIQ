import { computeDaysOutOfStock, computeVelocityAvg, StockHistoryRow } from './stock-derived.service';

const now = new Date('2026-07-16T00:00:00.000Z');
const daysAgo = (n: number, unitsAvailable: number): StockHistoryRow => ({
  visitCheckinTs: new Date(now.getTime() - n * 24 * 60 * 60 * 1000),
  unitsAvailable,
});

describe('computeDaysOutOfStock', () => {
  it('returns 0 with no history', () => {
    expect(computeDaysOutOfStock([], now)).toBe(0);
  });
  it('returns 0 when no prior row ever had stock', () => {
    expect(computeDaysOutOfStock([daysAgo(3, 0), daysAgo(10, 0)], now)).toBe(0);
  });
  it('computes days since the most recent in-stock row', () => {
    expect(computeDaysOutOfStock([daysAgo(3, 0), daysAgo(10, 5)], now)).toBe(10);
  });
  it('approximates at visit-cadence granularity for weekly beats', () => {
    expect(computeDaysOutOfStock([daysAgo(7, 5)], now)).toBe(7);
  });
  it('anchors on the last in-stock count even when it is older than the history window (#360)', () => {
    const emptyWindow = [1, 2, 3, 4, 5].map((n) => daysAgo(n, 0));
    const lastInStock = daysAgo(31, 12).visitCheckinTs;
    expect(computeDaysOutOfStock(emptyWindow, now)).toBe(0);
    expect(computeDaysOutOfStock(emptyWindow, now, lastInStock)).toBe(31);
  });
  it('reads 0 when the SKU has never been in stock at the outlet', () => {
    expect(computeDaysOutOfStock([daysAgo(3, 0)], now, null)).toBe(0);
  });
});

describe('computeVelocityAvg', () => {
  it('returns 0 with fewer than 2 rows', () => {
    expect(computeVelocityAvg([])).toBe(0);
    expect(computeVelocityAvg([daysAgo(0, 20)])).toBe(0);
  });
  it('averages consumption across consecutive visits', () => {
    expect(computeVelocityAvg([daysAgo(5, 80), daysAgo(10, 100)])).toBe(4); // 20 units / 5 days
  });
  it('treats a restock as zero consumption for that interval, not negative', () => {
    // interval A (2d-5d): 10 -> 90 is a restock -> 0/3 days = 0
    // interval B (5d-10d): 100 -> 10 -> 90 consumed / 5 days = 18
    // average of [0, 18] = 9
    expect(computeVelocityAvg([daysAgo(2, 90), daysAgo(5, 10), daysAgo(10, 100)])).toBe(9);
  });
  it('skips a zero-elapsed-time interval instead of dividing by zero', () => {
    const sameTs = daysAgo(5, 100).visitCheckinTs;
    const history = [
      { visitCheckinTs: sameTs, unitsAvailable: 80 },
      { visitCheckinTs: sameTs, unitsAvailable: 100 },
      daysAgo(10, 100),
    ];
    expect(computeVelocityAvg(history)).toBe(0);
  });
});
