import { randomUUID } from 'crypto';
import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { pct, round2 } from '../../lib/kpiMath';
import { getAvailabilityTrend, getShareOfShelfTrend } from '../trends/trends.service';
import {
  getCompetitorActivity,
  getShareOfShelf,
  getSkuMovement,
  getStockLevels,
  getVisibilityCompliance,
  getVisitSummary,
  RECENT_VISITS_LIMIT,
  TOP_COMPETITORS_LIMIT,
  WORST_OUTLETS_LIMIT,
} from './pillars.service';

/**
 * #359 — the pillar aggregates at a scale past the old 5,000-row cap.
 *
 * These used to read at most 5,000 rows and sum them in memory, so a period
 * with more rows than that returned a smaller total than the true one and said
 * nothing. The fixture here has 6,000 stock lines in the window on purpose: every
 * assertion is against totals computed from the fixture itself, so a figure
 * drawn from a subset fails.
 *
 * Every rewritten query is also run as another tenant that shares a territory
 * code and has rows in the same window — the two things raw SQL could get wrong
 * that the Prisma relation filters used to get right by construction.
 */
describe('pillar aggregates over every row (#359)', () => {
  const FROM = new Date('2026-08-01T00:00:00.000Z');
  const TO = new Date('2026-09-01T00:00:00.000Z');
  const VISITS = 500;
  const SKUS = 12;
  const OUTLETS = 12;
  const CODE_NORTH = `AGG-N-${Date.now()}`;
  const CODE_SOUTH = `AGG-S-${Date.now()}`;

  let clientId: string;
  let foreignClientId: string;
  let agentId: string;
  let otherAgentId: string;
  let foreignAgentId: string;
  let northId: string;
  let foreignNorthId: string;

  // What the fixture contains, tallied as it is built.
  const expected = {
    lines: 0,
    oos: 0,
    oosByOutlet: new Map<string, number>(),
    ourFacings: 0,
    competitorFacings: 0,
    visibility: 0,
    planogramSum: 0,
    cleanlinessSum: 0,
    highTraffic: 0,
    competitorRows: 0,
    promoters: 0,
    competitorSkus: new Set<string>(),
    visits: 0,
    submitted: 0,
    inProgress: 0,
    geofenceFailures: 0,
    outlets: new Set<string>(),
    otherAgentVisits: 0,
    skuUnits: new Map<string, number>(),
    skuDaysOut: new Map<string, number>(),
  };

  beforeAll(async () => {
    const tenant = (name: string) =>
      prisma.client.create({
        data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      });
    clientId = (await tenant('AGG-Client')).id;
    foreignClientId = (await tenant('AGG-Foreign')).id;

    const user = (cid: string, tag: string) =>
      prisma.user.create({
        data: {
          email: `agg-${tag}-${Date.now()}@example.test`,
          passwordHash: 'x',
          role: 'field_agent',
          clientId: cid,
        },
      });
    agentId = (await user(clientId, 'a')).id;
    otherAgentId = (await user(clientId, 'b')).id;
    foreignAgentId = (await user(foreignClientId, 'f')).id;

    northId = (
      await prisma.territory.create({ data: { clientId, name: 'North', code: CODE_NORTH } })
    ).id;
    await prisma.territory.create({ data: { clientId, name: 'South', code: CODE_SOUTH } });
    // The same code in another tenant: a scoped query must not reach its outlets.
    foreignNorthId = (
      await prisma.territory.create({
        data: { clientId: foreignClientId, name: 'North', code: CODE_NORTH },
      })
    ).id;

    const outletIds: string[] = [];
    for (let i = 0; i < OUTLETS; i += 1) {
      const id = randomUUID();
      outletIds.push(id);
      await prisma.outlet.create({
        data: {
          id,
          clientId,
          name: `AGG Outlet ${String(i).padStart(2, '0')}`,
          code: `AGG-${i}`,
          channelType: 'spaza',
          lat: -26 - i / 100,
          lng: 28,
          territoryId: CODE_NORTH,
        },
      });
    }
    const southOutletId = (
      await prisma.outlet.create({
        data: {
          clientId,
          name: 'AGG South',
          code: 'AGG-S',
          channelType: 'spaza',
          lat: -33,
          lng: 18,
          territoryId: CODE_SOUTH,
        },
      })
    ).id;
    const foreignOutletId = (
      await prisma.outlet.create({
        data: {
          clientId: foreignClientId,
          name: 'AGG Foreign',
          code: 'AGG-F',
          channelType: 'spaza',
          lat: -26,
          lng: 28,
          territoryId: CODE_NORTH,
        },
      })
    ).id;

    const skuIds: string[] = [];
    for (let s = 0; s < SKUS; s += 1) {
      const sku = await prisma.sku.create({
        data: {
          clientId,
          name: `AGG SKU ${String(s).padStart(2, '0')}`,
          category: 'Beverages',
          minFacingsStandard: 2,
          rrp: 10,
        },
      });
      skuIds.push(sku.id);
    }
    const foreignSkuId = (
      await prisma.sku.create({
        data: { clientId: foreignClientId, name: 'AGG Foreign SKU', category: 'Beverages', minFacingsStandard: 2, rrp: 10 },
      })
    ).id;

    const visits: Prisma.VisitCreateManyInput[] = [];
    const stock: object[] = [];
    const visibility: object[] = [];
    const competitive: object[] = [];

    const spanMs = TO.getTime() - FROM.getTime();
    for (let v = 0; v < VISITS; v += 1) {
      const id = randomUUID();
      const outletId = outletIds[v % OUTLETS];
      const inProgress = v % 50 === 0;
      const geofencePass = v % 25 !== 0;
      const byOther = v % 10 === 0;
      visits.push({
        id,
        clientId,
        outletId,
        agentId: byOther ? otherAgentId : agentId,
        checkinTs: new Date(FROM.getTime() + Math.floor((spanMs * v) / VISITS)),
        checkinLat: -26,
        checkinLng: 28,
        geofencePass,
        status: inProgress ? 'in_progress' : 'submitted',
      });
      expected.visits += 1;
      expected.outlets.add(outletId);
      if (inProgress) expected.inProgress += 1;
      else expected.submitted += 1;
      if (!geofencePass) expected.geofenceFailures += 1;
      if (byOther) expected.otherAgentVisits += 1;

      for (let s = 0; s < SKUS; s += 1) {
        const units = (v + s) % 7 === 0 ? 0 : 5 + s;
        const daysOut = units === 0 ? s * 3 + (v % 4) : 0;
        stock.push({
          visitId: id,
          skuId: skuIds[s],
          unitsAvailable: units,
          lastStockinDate: FROM,
          daysOutOfStock: daysOut,
          velocityAvg: 1,
          coverageDaysPredicted: 0,
        });
        expected.lines += 1;
        expected.skuUnits.set(skuIds[s], (expected.skuUnits.get(skuIds[s]) ?? 0) + units);
        expected.skuDaysOut.set(skuIds[s], Math.max(expected.skuDaysOut.get(skuIds[s]) ?? 0, daysOut));
        if (units === 0) {
          expected.oos += 1;
          expected.oosByOutlet.set(outletId, (expected.oosByOutlet.get(outletId) ?? 0) + 1);
        }
      }

      // One visit's facings total is not a number: it counts as 0, as in kpiMath.
      const own = v === 7 ? { total: 'lots' } : { total: 3 };
      visibility.push({
        visitId: id,
        brandingElements: {},
        planogramCompliancePct: v % 100,
        facingsCount: own,
        highTrafficPass: v % 2 === 0,
        cleanlinessScore: v % 5,
      });
      expected.visibility += 1;
      expected.ourFacings += typeof own.total === 'number' ? own.total : 0;
      expected.planogramSum += v % 100;
      expected.cleanlinessSum += v % 5;
      if (v % 2 === 0) expected.highTraffic += 1;

      const competitorSku = `Rival ${v % 12}`;
      competitive.push({
        visitId: id,
        competitorSku,
        competitorPrice: 10 + (v % 12),
        competitorPosmType: 'none',
        competitorPromoterPresent: v % 4 === 0,
        facingsCount: 1 + (v % 12),
        geotag: {},
      });
      expected.competitorRows += 1;
      expected.competitorFacings += 1 + (v % 12);
      expected.competitorSkus.add(competitorSku);
      if (v % 4 === 0) expected.promoters += 1;
    }

    // Outside the half-open window on both sides, and in another territory.
    const edge = (checkinTs: Date, outletId: string) => {
      const id = randomUUID();
      visits.push({
        id,
        clientId,
        outletId,
        agentId,
        checkinTs,
        checkinLat: -26,
        checkinLng: 28,
        geofencePass: true,
        status: 'submitted',
      });
      stock.push({
        visitId: id,
        skuId: skuIds[0],
        unitsAvailable: 0,
        lastStockinDate: FROM,
        daysOutOfStock: 999,
        velocityAvg: 1,
        coverageDaysPredicted: 0,
      });
      return id;
    };
    edge(new Date(FROM.getTime() - 1), outletIds[0]);
    edge(TO, outletIds[0]);
    const southVisit = edge(new Date(FROM.getTime() + 1000), southOutletId);
    // South is in the window for the unscoped figures; count it there.
    expected.visits += 1;
    expected.submitted += 1;
    expected.outlets.add(southOutletId);
    expected.lines += 1;
    expected.oos += 1;
    expected.oosByOutlet.set(southOutletId, 1);
    expected.skuDaysOut.set(skuIds[0], 999);
    void southVisit;

    // Another tenant, same territory code, same window, and much bigger numbers.
    for (let v = 0; v < 40; v += 1) {
      const id = randomUUID();
      visits.push({
        id,
        clientId: foreignClientId,
        outletId: foreignOutletId,
        agentId: foreignAgentId,
        checkinTs: new Date(FROM.getTime() + 3_600_000 * (v + 1)),
        checkinLat: -26,
        checkinLng: 28,
        geofencePass: false,
        status: 'in_progress',
      });
      stock.push({
        visitId: id,
        skuId: foreignSkuId,
        unitsAvailable: 0,
        lastStockinDate: FROM,
        daysOutOfStock: 5000,
        velocityAvg: 99,
        coverageDaysPredicted: 0,
      });
      visibility.push({
        visitId: id,
        brandingElements: {},
        planogramCompliancePct: 100,
        facingsCount: { total: 1000 },
        highTrafficPass: true,
        cleanlinessScore: 5,
      });
      competitive.push({
        visitId: id,
        competitorSku: 'Foreign Rival',
        competitorPrice: 1,
        competitorPosmType: 'none',
        competitorPromoterPresent: true,
        facingsCount: 1000,
        geotag: {},
      });
    }

    await prisma.visit.createMany({ data: visits });
    await prisma.visitStock.createMany({ data: stock as never });
    await prisma.visitVisibility.createMany({ data: visibility as never });
    await prisma.visitCompetitive.createMany({ data: competitive as never });
  }, 60_000);

  afterAll(async () => {
    const clients = { in: [clientId, foreignClientId] };
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: clients } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: clients } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId: clients } } });
    await prisma.visit.deleteMany({ where: { clientId: clients } });
    await prisma.outlet.deleteMany({ where: { clientId: clients } });
    await prisma.sku.deleteMany({ where: { clientId: clients } });
    await prisma.territory.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
  });

  const window = () => ({ clientId, from: FROM, to: TO });

  describe('getStockLevels', () => {
    it('counts every stock line past the old cap, and lists only the worst outlets', async () => {
      expect(expected.lines).toBeGreaterThan(5_000);
      const result = await getStockLevels(window());

      expect(result.linesObserved).toBe(expected.lines);
      expect(result.outOfStockLines).toBe(expected.oos);
      expect(result.onShelfAvailabilityPct).toBe(pct(expected.lines - expected.oos, expected.lines));
      expect(result.outletsWithStockout).toBe(expected.oosByOutlet.size);

      expect(result.worstOutlets).toHaveLength(WORST_OUTLETS_LIMIT);
      expect(result.truncated).toBe(true);
      const worstCounts = [...expected.oosByOutlet.values()].sort((a, b) => b - a);
      expect(result.worstOutlets.map((o) => o.outOfStockLines)).toEqual(
        worstCounts.slice(0, WORST_OUTLETS_LIMIT),
      );
    });

    it('narrows to a territory by code, and says the list is whole when it is', async () => {
      const south = await prisma.territory.findFirstOrThrow({ where: { clientId, code: CODE_SOUTH } });
      const result = await getStockLevels({ ...window(), territoryId: south.id });
      expect(result).toMatchObject({ linesObserved: 1, outOfStockLines: 1, outletsWithStockout: 1, truncated: false });
    });

    it('never reaches another tenant', async () => {
      // The foreign tenant's own figures are only its own rows…
      const foreign = await getStockLevels({ clientId: foreignClientId, from: FROM, to: TO });
      expect(foreign.linesObserved).toBe(40);
      // …a territory id from another tenant matches nothing, not everything…
      const crossed = await getStockLevels({ ...window(), territoryId: foreignNorthId });
      expect(crossed.linesObserved).toBe(0);
      // …and a shared code does not pull the other tenant's outlets in.
      const north = await getStockLevels({ ...window(), territoryId: northId });
      expect(north.linesObserved).toBe(expected.lines - 1);
      expect(north.worstOutlets.every((o) => !o.outletName.includes('Foreign'))).toBe(true);
    });
  });

  describe('getSkuMovement', () => {
    it('aggregates every line per SKU and reports the list it cut', async () => {
      const result = await getSkuMovement({ ...window(), limit: 5 });

      expect(result.totalCount).toBe(SKUS);
      expect(result.truncated).toBe(true);
      expect(result.rows).toHaveLength(5);
      for (const row of result.rows) {
        expect(row.unitsAvailable).toBe(expected.skuUnits.get(row.skuId));
        expect(row.daysOutOfStock).toBe(expected.skuDaysOut.get(row.skuId));
      }
      const observations = (await getSkuMovement({ ...window(), limit: 50 })).rows.reduce(
        (sum, row) => sum + row.observations,
        0,
      );
      expect(observations).toBe(expected.lines);
    });

    it('never reaches another tenant', async () => {
      const result = await getSkuMovement({ ...window(), limit: 50 });
      expect(result.rows.some((row) => row.skuName === 'AGG Foreign SKU')).toBe(false);
      expect((await getSkuMovement({ ...window(), territoryId: foreignNorthId })).totalCount).toBe(0);
      const foreign = await getSkuMovement({ clientId: foreignClientId, from: FROM, to: TO });
      expect(foreign).toMatchObject({ totalCount: 1, truncated: false });
    });
  });

  describe('getShareOfShelf', () => {
    it('sums every facing, counting a non-numeric total as 0', async () => {
      const result = await getShareOfShelf(window());
      expect(result).toEqual({
        ourFacings: expected.ourFacings,
        competitorFacings: expected.competitorFacings,
        observations: expected.visibility,
        shareOfShelfPct: pct(expected.ourFacings, expected.ourFacings + expected.competitorFacings),
      });
    });

    it('never reaches another tenant', async () => {
      expect((await getShareOfShelf({ ...window(), territoryId: foreignNorthId })).observations).toBe(0);
      expect(await getShareOfShelf({ clientId: foreignClientId, from: FROM, to: TO })).toMatchObject({
        ourFacings: 40_000,
        competitorFacings: 40_000,
        observations: 40,
      });
    });
  });

  describe('getVisibilityCompliance', () => {
    it('averages every visit in the window', async () => {
      const result = await getVisibilityCompliance(window());
      expect(result).toEqual({
        planogramCompliancePct: round2(expected.planogramSum / expected.visibility),
        cleanlinessScore: round2(expected.cleanlinessSum / expected.visibility),
        highTrafficPassPct: pct(expected.highTraffic, expected.visibility),
        observations: expected.visibility,
      });
    });

    it('never reaches another tenant', async () => {
      expect((await getVisibilityCompliance({ ...window(), territoryId: foreignNorthId })).observations).toBe(0);
      expect(
        (await getVisibilityCompliance({ clientId: foreignClientId, from: FROM, to: TO })).planogramCompliancePct,
      ).toBe(100);
    });
  });

  describe('getCompetitorActivity', () => {
    it('counts every sighting and lists the top competitors by facings', async () => {
      const result = await getCompetitorActivity(window());
      expect(result.observations).toBe(expected.competitorRows);
      expect(result.distinctCompetitorSkus).toBe(expected.competitorSkus.size);
      expect(result.promoterPresencePct).toBe(pct(expected.promoters, expected.competitorRows));
      expect(result.topCompetitors).toHaveLength(TOP_COMPETITORS_LIMIT);
      expect(result.truncated).toBe(true);
      // Rival 11 holds 12 facings per sighting, the most of any.
      expect(result.topCompetitors[0]).toMatchObject({ competitorSku: 'Rival 11', averagePrice: 21 });
    });

    it('never reaches another tenant', async () => {
      const result = await getCompetitorActivity(window());
      expect(result.topCompetitors.some((c) => c.competitorSku === 'Foreign Rival')).toBe(false);
      expect((await getCompetitorActivity({ ...window(), territoryId: foreignNorthId })).observations).toBe(0);
    });
  });

  describe('getVisitSummary', () => {
    it('counts every visit and lists the newest', async () => {
      const result = await getVisitSummary(window());
      expect(result).toMatchObject({
        visits: expected.visits,
        submitted: expected.submitted,
        inProgress: expected.inProgress,
        outletsVisited: expected.outlets.size,
        geofenceFailures: expected.geofenceFailures,
        truncated: true,
      });
      expect(result.recent).toHaveLength(RECENT_VISITS_LIMIT);
      // Newest first, and never the visit sitting exactly on the exclusive end.
      expect(new Date(result.recent[0].checkinTs).getTime()).toBeLessThan(TO.getTime());
    });

    it('narrows to one agent', async () => {
      const result = await getVisitSummary({ ...window(), agentId: otherAgentId });
      expect(result.visits).toBe(expected.otherAgentVisits);
    });

    it('never reaches another tenant, even when asked for its agent', async () => {
      expect((await getVisitSummary({ ...window(), agentId: foreignAgentId })).visits).toBe(0);
      expect((await getVisitSummary({ ...window(), territoryId: foreignNorthId })).visits).toBe(0);
      expect(await getVisitSummary({ clientId: foreignClientId, from: FROM, to: TO })).toMatchObject({
        visits: 40,
        inProgress: 40,
        truncated: true,
      });
    });
  });

  describe('trend series aggregated in the database', () => {
    it('buckets every row and never another tenant sharing a territory code', async () => {
      const series = await getAvailabilityTrend({
        clientId,
        interval: 'week',
        territoryId: northId,
      });
      const counted = series.points.reduce((sum, point) => sum + point.count, 0);
      // Stock rows are dated by their own createdAt (now), so all North lines
      // including the two edge visits land in the series.
      expect(counted).toBe(expected.lines - 1 + 2);

      const foreign = await getShareOfShelfTrend({ clientId: foreignClientId, interval: 'week' });
      expect(foreign.points.reduce((sum, point) => sum + point.count, 0)).toBe(40);
      expect(foreign.points.every((point) => point.value === 50)).toBe(true);

      const crossed = await getAvailabilityTrend({ clientId, interval: 'day', territoryId: foreignNorthId });
      expect(crossed.points).toEqual([]);
    });
  });
});
