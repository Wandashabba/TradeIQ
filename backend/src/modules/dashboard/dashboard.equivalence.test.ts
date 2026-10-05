import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { facingsTotal, mean, onShelfAvailabilityPct, pct } from '../../lib/kpiMath';
import {
  DashboardFilters,
  DashboardSummary,
  ScoreBand,
  getDashboardByTerritory,
  getDashboardSummary,
} from './dashboard.service';

/**
 * The dashboard's KPIs moved out of Node and into SQL. This suite is the proof
 * that not one figure moved with them.
 *
 * Below is the ORIGINAL implementation, verbatim: load the scope's outlets and
 * its visits with five eager relation includes, then fold them in JavaScript.
 * It is kept here, and only here, as an oracle. Every case asserts that the
 * live service and this reference produce a deep-equal `DashboardSummary` over
 * the same filters — unfiltered, territory-scoped, outlet-scoped and
 * date-scoped.
 *
 * It is not kept as production code because it cannot run in production: on the
 * demo tenant (137,451 visits, 1.7M observation rows) the visit query
 * serialises to roughly 580MB of JSON, which is past V8's 512MiB maximum string
 * length, so Prisma's query engine fails to hand the result to Node at all and
 * `GET /dashboard` answered 500 after ~28s, every time. At fixture scale it is
 * perfectly correct, which is exactly what makes it a usable oracle.
 *
 * If a KPI formula is ever changed on purpose, this suite will fail — and the
 * right fix is to change the formula in BOTH places in the same commit, or to
 * delete the oracle deliberately. It must never be "updated to match" the
 * service without someone reading why.
 */

const PRICE_COMPLIANCE_TOLERANCE_PCT = 5;

const SCORE_BANDS: ReadonlyArray<{ label: string; minScore: number }> = [
  { label: '90–100', minScore: 90 },
  { label: '80–89', minScore: 80 },
  { label: '70–79', minScore: 70 },
  { label: '60–69', minScore: 60 },
  { label: '<60', minScore: 0 },
];

type ScopedVisit = Prisma.VisitGetPayload<{
  include: {
    stock: true;
    visibility: true;
    pricing: true;
    competitive: true;
    scorecard: true;
  };
}>;

interface ScopedOutlet {
  id: string;
  acvWeight: number;
}

/** The pre-aggregate fold, unchanged. */
function referenceKpis(outlets: ScopedOutlet[], visits: ScopedVisit[]): DashboardSummary {
  const outletsTotal = outlets.length;
  const visitedOutletIds = new Set(visits.map((visit) => visit.outletId));
  const outletsVisited = visitedOutletIds.size;

  const stockRows = visits.flatMap((visit) => visit.stock);
  const pricingRows = visits.flatMap((visit) => visit.pricing);
  const visibilityRows = visits.flatMap((visit) => (visit.visibility ? [visit.visibility] : []));
  const scorecards = visits.flatMap((visit) => (visit.scorecard ? [visit.scorecard] : []));

  const numericDistribution = pct(outletsVisited, outletsTotal);

  const totalAcv = outlets.reduce((sum, outlet) => sum + outlet.acvWeight, 0);
  const visitedAcv = outlets
    .filter((outlet) => visitedOutletIds.has(outlet.id))
    .reduce((sum, outlet) => sum + outlet.acvWeight, 0);
  const weightedDistribution = pct(visitedAcv, totalAcv);

  const osaPct = onShelfAvailabilityPct(stockRows);
  const executionScore = mean(scorecards.map((scorecard) => scorecard.weightedTotal));
  const priceCompliancePct = pct(
    pricingRows.filter((row) => Math.abs(row.deviationPct) <= PRICE_COMPLIANCE_TOLERANCE_PCT).length,
    pricingRows.length,
  );
  const visibilityCompliancePct = mean(visibilityRows.map((row) => row.planogramCompliancePct));

  const ownFacings = visibilityRows.reduce((sum, row) => sum + facingsTotal(row.facingsCount), 0);
  const competitorFacings = visits.reduce(
    (sum, visit) => sum + visit.competitive.reduce((n, row) => n + row.facingsCount, 0),
    0,
  );
  const shareOfShelf = pct(ownFacings, ownFacings + competitorFacings);

  const perfectStoreRate = pct(
    scorecards.filter((scorecard) => scorecard.ratingBand === 'green').length,
    scorecards.length,
  );

  const latestScoreByOutlet = new Map<string, { at: number; score: number }>();
  for (const visit of visits) {
    if (!visit.scorecard) continue;
    const at = visit.checkinTs.getTime();
    const seen = latestScoreByOutlet.get(visit.outletId);
    if (!seen || at > seen.at) {
      latestScoreByOutlet.set(visit.outletId, { at, score: visit.scorecard.weightedTotal });
    }
  }
  const scoreBands: ScoreBand[] = SCORE_BANDS.map((band) => ({ ...band, outlets: 0 }));
  for (const { score } of latestScoreByOutlet.values()) {
    const band = scoreBands.find((b) => score >= b.minScore) ?? scoreBands[scoreBands.length - 1]!;
    band.outlets += 1;
  }

  return {
    kpis: {
      numericDistribution,
      weightedDistribution,
      osaPct,
      executionScore,
      priceCompliancePct,
      visibilityCompliancePct,
      shareOfShelf,
      perfectStoreRate,
    },
    sampleSizes: {
      numericDistribution: outletsTotal,
      weightedDistribution: outletsTotal,
      osaPct: stockRows.filter((row) => row.unitsAvailable !== null).length,
      executionScore: scorecards.length,
      priceCompliancePct: pricingRows.length,
      visibilityCompliancePct: visibilityRows.length,
      shareOfShelf: ownFacings + competitorFacings,
      perfectStoreRate: scorecards.length,
    },
    totals: { visits: visits.length, outletsVisited, outletsTotal },
    scoreBands,
  };
}

/** The pre-aggregate `getDashboardSummary`, unchanged. */
async function referenceDashboardSummary(filters: DashboardFilters): Promise<DashboardSummary> {
  let territoryCode: string | undefined;
  if (filters.territoryId) {
    const territory = await prisma.territory.findFirst({
      where: { id: filters.territoryId, clientId: filters.clientId },
    });
    territoryCode = territory?.code ?? '__no-such-territory__';
  }

  const outletWhere: Prisma.OutletWhereInput = { clientId: filters.clientId };
  if (territoryCode) {
    outletWhere.territoryId = territoryCode;
  }
  if (filters.outletId) {
    outletWhere.id = filters.outletId;
  }

  const visitWhere: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (territoryCode || filters.outletId) {
    visitWhere.outlet = {
      ...(territoryCode ? { territoryId: territoryCode } : {}),
      ...(filters.outletId ? { id: filters.outletId } : {}),
    };
  }
  if (filters.from || filters.to) {
    visitWhere.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }

  const [outlets, visits] = await Promise.all([
    prisma.outlet.findMany({ where: outletWhere, select: { id: true, acvWeight: true } }),
    prisma.visit.findMany({
      where: visitWhere,
      include: {
        stock: true,
        visibility: true,
        pricing: true,
        competitive: true,
        scorecard: true,
      },
    }),
  ]);

  return referenceKpis(outlets, visits);
}

/** The pre-aggregate `getDashboardByTerritory`, unchanged. */
async function referenceByTerritory(filters: { clientId: string; from?: Date; to?: Date }) {
  const territories = await prisma.territory.findMany({ where: { clientId: filters.clientId } });

  const visitWhere: Prisma.VisitWhereInput = { clientId: filters.clientId };
  if (filters.from || filters.to) {
    visitWhere.checkinTs = {
      ...(filters.from ? { gte: filters.from } : {}),
      ...(filters.to ? { lte: filters.to } : {}),
    };
  }

  const [outlets, visits] = await Promise.all([
    prisma.outlet.findMany({
      where: { clientId: filters.clientId },
      select: { id: true, acvWeight: true, territoryId: true },
    }),
    prisma.visit.findMany({
      where: visitWhere,
      include: {
        stock: true,
        visibility: true,
        pricing: true,
        competitive: true,
        scorecard: true,
      },
    }),
  ]);

  return territories.map((territory) => {
    const scopedOutlets = outlets.filter((outlet) => outlet.territoryId === territory.code);
    const scopedOutletIds = new Set(scopedOutlets.map((outlet) => outlet.id));
    const scopedVisits = visits.filter((visit) => scopedOutletIds.has(visit.outletId));
    return {
      territoryId: territory.id,
      territoryName: territory.name,
      ...referenceKpis(scopedOutlets, scopedVisits),
    };
  });
}

// ── Fixture ───────────────────────────────────────────────────────────────

describe('dashboard aggregate / fold equivalence', () => {
  let clientId: string;
  let northId: string;
  let southId: string;
  let emptyTerritoryId: string;
  /** The twice-visited door, for the score-band "latest visit wins" rule. */
  let repeatOutletId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'EQV-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'eqv-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const sku = await prisma.sku.create({
      data: { clientId, name: 'EQV-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 20 },
    });

    const north = await prisma.territory.create({
      data: { clientId, name: 'EQV-North', code: 'eqv-north' },
    });
    northId = north.id;
    const south = await prisma.territory.create({
      data: { clientId, name: 'EQV-South', code: 'eqv-south' },
    });
    southId = south.id;
    // A territory no outlet carries the code of: it must still come back, as
    // five empty bands and eight zeros, from both implementations.
    const emptyTerritory = await prisma.territory.create({
      data: { clientId, name: 'EQV-Empty', code: 'eqv-empty' },
    });
    emptyTerritoryId = emptyTerritory.id;

    const outlet = (code: string, territoryCode: string, acvWeight: number) =>
      prisma.outlet.create({
        data: {
          name: `EQV-${code}`,
          code,
          channelType: 'hypermarket',
          lat: -26.2,
          lng: 28.0,
          territoryId: territoryCode,
          clientId,
          acvWeight,
        },
      });

    // Weights deliberately unequal and non-integral, so weighted distribution
    // cannot coincide with numeric distribution by accident.
    const n1 = await outlet('EQV-N1', 'eqv-north', 9);
    const n2 = await outlet('EQV-N2', 'eqv-north', 2.5);
    // Never visited: it is denominator only.
    await outlet('EQV-N3', 'eqv-north', 1);
    const s1 = await outlet('EQV-S1', 'eqv-south', 4);
    // An outlet whose territory code has no Territory row at all.
    const orphan = await outlet('EQV-O1', 'eqv-orphan', 3);
    repeatOutletId = n1.id;

    const visit = (outletId: string, at: string) =>
      prisma.visit.create({
        data: {
          outletId,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(at),
          checkinLat: -26.2,
          checkinLng: 28.0,
          geofencePass: true,
          status: 'submitted',
        },
      });

    const v1 = await visit(n1.id, '2026-07-01T09:00:00.000Z');
    // The same door again, later and worse — the band must follow the LATER one.
    const v2 = await visit(n1.id, '2026-07-10T09:00:00.000Z');
    const v3 = await visit(n2.id, '2026-07-05T09:00:00.000Z');
    const v4 = await visit(s1.id, '2026-07-20T09:00:00.000Z');
    const v5 = await visit(orphan.id, '2026-07-21T09:00:00.000Z');
    // A visit that captured nothing at all: no stock, no visibility, no
    // pricing, no competitive, no scorecard. It counts in `visits` and in
    // `outletsVisited` and in no denominator.
    await visit(s1.id, '2026-07-22T09:00:00.000Z');

    const stock = (visitId: string, unitsAvailable: number | null) =>
      prisma.visitStock.create({
        data: {
          visitId,
          skuId: sku.id,
          unitsAvailable,
          lastStockinDate: new Date('2026-06-20T00:00:00.000Z'),
          daysOutOfStock: 0,
          velocityAvg: 4,
          coverageDaysPredicted: unitsAvailable === null ? null : 5,
        },
      });
    await stock(v1.id, 20);
    await stock(v1.id, 0);
    // NULL: never counted, so it must leave the ratio entirely (#389) rather
    // than arriving as a zero and dragging availability down.
    await stock(v1.id, null);
    await stock(v2.id, 7);
    await stock(v3.id, null);
    await stock(v4.id, 3);
    await stock(v5.id, 0);

    const visibility = (visitId: string, planogram: number, facingsCount: Prisma.InputJsonValue) =>
      prisma.visitVisibility.create({
        data: {
          visitId,
          brandingElements: {},
          planogramCompliancePct: planogram,
          facingsCount,
          highTrafficPass: true,
          cleanlinessScore: 4,
        },
      });
    await visibility(v1.id, 80, { total: 10 });
    await visibility(v2.id, 62.5, { total: 4.5 });
    // A `total` that is not a number, and a column that is not an object at
    // all: both count as 0 facings in `facingsTotal`, and the SQL mirror of it
    // must agree rather than erroring or producing NULL.
    await visibility(v3.id, 95, { total: 'lots' });
    await visibility(v4.id, 40, [1, 2, 3]);
    await visibility(v5.id, 100, {});

    const pricing = (visitId: string, deviationPct: number) =>
      prisma.visitPricing.create({
        data: {
          visitId,
          skuId: sku.id,
          priceActual: 20,
          priceMaster: 20,
          deviationPct,
          promoActive: false,
          promoMaterialsDetected: {},
          commsRating: 3,
        },
      });
    // Both tolerance boundaries, which are compliant (`<=`), and both sides of
    // it. An off-by-one on the comparison shows up here.
    await pricing(v1.id, 5);
    await pricing(v1.id, -5);
    await pricing(v1.id, 5.01);
    await pricing(v2.id, -12);
    await pricing(v3.id, 0);
    await pricing(v4.id, 30);

    const competitive = (visitId: string, facings: number) =>
      prisma.visitCompetitive.create({
        data: {
          visitId,
          competitorSku: 'EQV-Rival',
          competitorPrice: 18,
          competitorPosmType: 'end_cap',
          competitorPromoterPresent: false,
          geotag: {},
          facingsCount: facings,
        },
      });
    await competitive(v1.id, 30);
    await competitive(v1.id, 2);
    await competitive(v2.id, 1);
    await competitive(v4.id, 7);

    const scorecard = (visitId: string, weightedTotal: number, ratingBand: string) =>
      prisma.scorecard.create({ data: { visitId, dimensionScores: {}, weightedTotal, ratingBand } });
    // One score in each band, plus the repeat visit that moves a door between
    // bands, plus a 89.9 that must land in 80–89 and never in 90–100.
    await scorecard(v1.id, 92, 'green');
    await scorecard(v2.id, 55, 'red');
    await scorecard(v3.id, 89.9, 'amber');
    await scorecard(v4.id, 73, 'amber');
    await scorecard(v5.id, 64, 'amber');

    // A second client with the SAME territory codes and the same outlet-facing
    // shape. Nothing of it may appear in any figure above.
    const other = await prisma.client.create({
      data: { name: 'EQV-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'eqv-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: other.id,
      },
    });
    await prisma.territory.create({
      data: { clientId: other.id, name: 'EQV-Other-North', code: 'eqv-north' },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'EQV-Other-N1',
        code: 'EQV-X1',
        channelType: 'spaza',
        lat: -25.7,
        lng: 28.2,
        territoryId: 'eqv-north',
        clientId: other.id,
        acvWeight: 50,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: other.id,
        checkinTs: new Date('2026-07-02T09:00:00.000Z'),
        checkinLat: -25.7,
        checkinLng: 28.2,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitStock.create({
      data: {
        visitId: otherVisit.id,
        skuId: (
          await prisma.sku.create({
            data: {
              clientId: other.id,
              name: 'EQV-Other-Cola',
              category: 'Beverages',
              minFacingsStandard: 4,
              rrp: 20,
            },
          })
        ).id,
        unitsAvailable: 0,
        lastStockinDate: new Date('2026-06-01T00:00:00.000Z'),
        daysOutOfStock: 10,
        velocityAvg: 2,
        coverageDaysPredicted: 0,
      },
    });
    await prisma.scorecard.create({
      data: { visitId: otherVisit.id, dimensionScores: {}, weightedTotal: 1, ratingBand: 'red' },
    });
  });

  afterAll(async () => {
    const clientIds = (await prisma.client.findMany({ where: { name: { startsWith: 'EQV-' } } })).map(
      (c) => c.id,
    );
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visitCompetitive.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  /** Every figure, both ways, over one set of filters. */
  async function expectEquivalent(filters: Omit<DashboardFilters, 'clientId'>): Promise<void> {
    const [actual, expected] = await Promise.all([
      getDashboardSummary({ clientId, ...filters }),
      referenceDashboardSummary({ clientId, ...filters }),
    ]);
    expect(actual).toEqual(expected);
  }

  it('matches the fold with no filters at all', async () => {
    await expectEquivalent({});

    // Not only equal to the reference — equal to arithmetic done by hand, so a
    // bug copied into both implementations cannot pass.
    const summary = await getDashboardSummary({ clientId });
    expect(summary.totals).toEqual({ visits: 6, outletsVisited: 4, outletsTotal: 5 });
    // 4 of 5 doors; 9 + 2.5 + 4 + 3 of 19.5 ACV points.
    expect(summary.kpis.numericDistribution).toBe(80);
    expect(summary.kpis.weightedDistribution).toBe(94.87);
    // 7 stock lines, 2 uncounted; 3 of the remaining 5 have stock.
    expect(summary.kpis.osaPct).toBe(60);
    expect(summary.sampleSizes.osaPct).toBe(5);
    // 3 of 6 pricing rows within +-5, counting both boundaries.
    expect(summary.kpis.priceCompliancePct).toBe(50);
    // 10 + 4.5 own facings; the other three visibility rows have no numeric
    // total. 40 competitor facings. 14.5 / 54.5 = 26.6055…
    expect(summary.kpis.shareOfShelf).toBe(26.61);
    expect(summary.sampleSizes.shareOfShelf).toBe(54.5);
    expect(summary.kpis.visibilityCompliancePct).toBe(75.5);
    expect(summary.kpis.executionScore).toBe(74.78);
    expect(summary.kpis.perfectStoreRate).toBe(20);
    // Four doors scored. N1 was scored twice — 92 then 55 — and counts once,
    // at the later visit. 89.9 is in 80–89, not 90–100.
    expect(summary.scoreBands).toEqual([
      { label: '90–100', minScore: 90, outlets: 0 },
      { label: '80–89', minScore: 80, outlets: 1 },
      { label: '70–79', minScore: 70, outlets: 1 },
      { label: '60–69', minScore: 60, outlets: 1 },
      { label: '<60', minScore: 0, outlets: 1 },
    ]);
  });

  it('matches the fold scoped to a territory', async () => {
    await expectEquivalent({ territoryId: northId });
    await expectEquivalent({ territoryId: southId });
    // A territory whose code no outlet carries.
    await expectEquivalent({ territoryId: emptyTerritoryId });
    // A territoryId that does not resolve: it must match nothing, not
    // everything.
    await expectEquivalent({ territoryId: 'no-such-territory-id' });

    const north = await getDashboardSummary({ clientId, territoryId: northId });
    // Three outlets in north, two of them visited. The other client's outlet
    // carries the same territory code and must not be among them.
    expect(north.totals).toEqual({ visits: 3, outletsVisited: 2, outletsTotal: 3 });
  });

  it('matches the fold scoped to a date window', async () => {
    await expectEquivalent({ from: new Date('2026-07-05T00:00:00.000Z') });
    await expectEquivalent({ to: new Date('2026-07-05T23:59:59.999Z') });
    await expectEquivalent({
      from: new Date('2026-07-05T00:00:00.000Z'),
      to: new Date('2026-07-20T09:00:00.000Z'),
    });
    // Boundaries are inclusive on both ends: a window that is exactly one
    // visit's checkin instant contains that visit.
    await expectEquivalent({
      from: new Date('2026-07-10T09:00:00.000Z'),
      to: new Date('2026-07-10T09:00:00.000Z'),
    });
    // A window with nothing in it.
    await expectEquivalent({ from: new Date('2027-01-01T00:00:00.000Z') });

    const window = await getDashboardSummary({
      clientId,
      from: new Date('2026-07-10T09:00:00.000Z'),
      to: new Date('2026-07-10T09:00:00.000Z'),
    });
    expect(window.totals).toEqual({ visits: 1, outletsVisited: 1, outletsTotal: 5 });
  });

  it('matches the fold scoped to a single outlet, and to an outlet and a window together', async () => {
    await expectEquivalent({ outletId: repeatOutletId });
    await expectEquivalent({ outletId: repeatOutletId, from: new Date('2026-07-05T00:00:00.000Z') });
    await expectEquivalent({ outletId: repeatOutletId, territoryId: northId });
    // An outlet that belongs to a different territory than the one asked for:
    // the two filters intersect, they do not override each other.
    await expectEquivalent({ outletId: repeatOutletId, territoryId: southId });
    await expectEquivalent({ outletId: 'no-such-outlet-id' });
  });

  it('matches the fold for every territory in the rollup, unfiltered and date-scoped', async () => {
    for (const filters of [
      {},
      { from: new Date('2026-07-05T00:00:00.000Z') },
      { to: new Date('2026-07-05T00:00:00.000Z') },
      {
        from: new Date('2026-07-05T00:00:00.000Z'),
        to: new Date('2026-07-20T09:00:00.000Z'),
      },
      { from: new Date('2027-01-01T00:00:00.000Z') },
    ]) {
      const [actual, expected] = await Promise.all([
        getDashboardByTerritory({ clientId, ...filters }),
        referenceByTerritory({ clientId, ...filters }),
      ]);
      expect(actual).toEqual(expected);
      // All three territories, every time — including the one with no outlets.
      expect(actual).toHaveLength(3);
    }
  });

  it('agrees with the whole-scope endpoint territory by territory', async () => {
    // The two routes are now one scope expressed two ways. They were not
    // obliged to agree before (the rollup scoped visits through the client's
    // outlets, the summary trusted Visit.clientId alone); they are now.
    const rollup = await getDashboardByTerritory({ clientId });
    for (const territory of rollup) {
      const { territoryId, territoryName, ...figures } = territory;
      void territoryName;
      expect(await getDashboardSummary({ clientId, territoryId })).toEqual(figures);
    }
  });

  it('scopes an empty-string territory code to its own outlets, not the whole client', async () => {
    // The ONE figure that deliberately moved. The fold tested the resolved code
    // for truthiness (`if (territoryCode)`), so a territory whose code is the
    // empty string — which POST /territories accepts, because it only checks
    // the type — applied no filter at all and reported the entire client's
    // figures under that territory's name. The aggregate tests for
    // `!== undefined` and scopes to the outlets that actually carry it.
    const blank = await prisma.territory.create({
      data: { clientId, name: 'EQV-Blank', code: '' },
    });
    const blankOutlet = await prisma.outlet.create({
      data: {
        name: 'EQV-Blank-Outlet',
        code: 'EQV-B1',
        channelType: 'kiosk',
        lat: -26.2,
        lng: 28.0,
        territoryId: '',
        clientId,
        acvWeight: 1,
      },
    });
    try {
      const scoped = await getDashboardSummary({ clientId, territoryId: blank.id });
      // One outlet carries the blank code, and nobody has visited it.
      expect(scoped.totals).toEqual({ visits: 0, outletsVisited: 0, outletsTotal: 1 });

      // And the fold really did report the whole client here — this is the
      // behaviour being corrected, not a coincidence.
      const reference = await referenceDashboardSummary({ clientId, territoryId: blank.id });
      expect(reference.totals.outletsTotal).toBe(6);
      expect(reference.totals.visits).toBe(6);
    } finally {
      await prisma.outlet.delete({ where: { id: blankOutlet.id } });
      await prisma.territory.delete({ where: { id: blank.id } });
    }
  });

  it('breaks a same-timestamp score-band tie the same way twice', async () => {
    // Two scored visits to one door at the identical instant. The fold resolved
    // this by whatever order Prisma happened to return rows in, which is to say
    // arbitrarily; the aggregate decides it on `id DESC`. The figure a manager
    // sees must at least not change between two reads of the same data.
    const agent = await prisma.user.findFirstOrThrow({ where: { email: 'eqv-agent@example.com' } });
    const at = new Date('2026-08-01T09:00:00.000Z');
    const tied = await Promise.all(
      [40, 95].map((score) =>
        prisma.visit
          .create({
            data: {
              outletId: repeatOutletId,
              agentId: agent.id,
              clientId,
              checkinTs: at,
              checkinLat: -26.2,
              checkinLng: 28.0,
              geofencePass: true,
              status: 'submitted',
            },
          })
          .then(async (visit) => {
            await prisma.scorecard.create({
              data: {
                visitId: visit.id,
                dimensionScores: {},
                weightedTotal: score,
                ratingBand: score >= 80 ? 'green' : 'red',
              },
            });
            return visit;
          }),
      ),
    );
    try {
      const first = await getDashboardSummary({ clientId });
      const second = await getDashboardSummary({ clientId });
      expect(first.scoreBands).toEqual(second.scoreBands);
      // And it is the higher id's score, not an arbitrary one.
      const winner = tied.slice().sort((a, b) => (a.id < b.id ? 1 : -1))[0]!;
      const winningScore = await prisma.scorecard.findUniqueOrThrow({
        where: { visitId: winner.id },
      });
      const band = first.scoreBands.find((b) => winningScore.weightedTotal >= b.minScore)!;
      expect(band.outlets).toBeGreaterThanOrEqual(1);
    } finally {
      await prisma.scorecard.deleteMany({ where: { visitId: { in: tied.map((v) => v.id) } } });
      await prisma.visit.deleteMany({ where: { id: { in: tied.map((v) => v.id) } } });
    }
  });
});
