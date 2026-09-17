import { prisma } from '../../lib/prisma';
import { foreignTenant, userIn, type TestUser } from '../../test-utils/tenants';
import { resolvePeriod } from './period';
import {
  findTerritories,
  getAlertSummary,
  getCampaignPerformance,
  getContestLeaderboards,
  getPriceCompliance,
  getSellInForecast,
  getTaskSummary,
  OutletLookupError,
  SkuLookupError,
} from './operations.service';

type Foreign = Awaited<ReturnType<typeof foreignTenant>>;

/**
 * The operational summaries behind the #362 tools, against a real database.
 *
 * Every describe block carries a cross-tenant case. The foreign tenant is built
 * to collide on purpose — the same territory code and name, the same outlet,
 * SKU, campaign and contest names, and large figures — so a missing `clientId`
 * filter anywhere shows up as a wrong number rather than passing unnoticed.
 */

const TZ = 'Africa/Johannesburg';
const NOW = new Date('2026-09-17T10:00:00.000Z');
const AUGUST = resolvePeriod({ kind: 'custom', from: '2026-08-01', to: '2026-08-31' }, NOW, TZ);
const JULY = resolvePeriod({ kind: 'custom', from: '2026-07-01', to: '2026-07-31' }, NOW, TZ);
const MTD = resolvePeriod({ kind: 'mtd' }, NOW, TZ);

let clientId: string;
let manager: TestUser;
let kagiso: TestUser;
let naledi: TestUser;
let foreign: Foreign;

const territory: Record<string, string> = {};
const outlet: Record<string, string> = {};
const sku: Record<string, string> = {};
let foreignTerritoryId: string;
let foreignOutletId: string;
let foreignSkuId: string;
let serial = 0;

async function visit(cid: string, outletId: string, agentId: string, at: string) {
  return prisma.visit.create({
    data: {
      clientId: cid,
      outletId,
      agentId,
      checkinTs: new Date(at),
      checkinLat: -26,
      checkinLng: 28,
      geofencePass: true,
      status: 'submitted',
    },
  });
}

async function priced(visitId: string, skuId: string, priceActual: number, rrp: number, promoActive = false) {
  await prisma.visitPricing.create({
    data: {
      visitId,
      skuId,
      priceActual,
      priceMaster: rrp,
      deviationPct: ((priceActual - rrp) / rrp) * 100,
      promoActive,
      promoMaterialsDetected: {},
      commsRating: 3,
    },
  });
}

async function order(
  cid: string,
  outletId: string,
  agentId: string,
  skuId: string,
  quantity: number,
  total: number,
  capturedAt: string,
  campaignId?: string,
) {
  await prisma.order.create({
    data: {
      clientId: cid,
      outletId,
      agentId,
      total,
      capturedAt: new Date(capturedAt),
      ...(campaignId ? { campaignId } : {}),
      lines: { create: [{ skuId, quantity, unitPrice: 1 }] },
    },
  });
}

async function points(cid: string, agentId: string, amount: number, at: string) {
  serial += 1;
  await prisma.pointsLedgerEntry.create({
    data: {
      clientId: cid,
      agentId,
      points: amount,
      reason: 'visit_submitted',
      sourceType: 'visit',
      sourceId: `ops-${serial}-${Date.now()}`,
      occurredAt: new Date(at),
    },
  });
}

beforeAll(async () => {
  const client = await prisma.client.create({
    data: { name: 'OPS-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
  });
  clientId = client.id;
  manager = await userIn(clientId, 'manager');
  kagiso = await userIn(clientId, 'field_agent', { displayName: 'Kagiso Molefe' });
  naledi = await userIn(clientId, 'field_agent', { displayName: 'Naledi Sithole' });
  foreign = await foreignTenant('field_agent');

  for (const [key, name, code, region] of [
    ['gpn', 'Gauteng North', 'OPS-GPN', 'Gauteng'],
    ['gpe', 'Gauteng East', 'OPS-GPE', 'Gauteng'],
    ['nmb', 'Nelson Mandela Bay', 'OPS-NMB', 'Eastern Cape'],
  ] as const) {
    territory[key] = (await prisma.territory.create({ data: { clientId, name, code, region } })).id;
  }
  // The other tenant: the same name and code as ours, and one only it has.
  foreignTerritoryId = (
    await prisma.territory.create({
      data: { clientId: foreign.clientId, name: 'Gauteng North', code: 'OPS-GPN', region: 'Gauteng' },
    })
  ).id;
  await prisma.territory.create({
    data: { clientId: foreign.clientId, name: 'Foreign Only Place', code: 'OPS-FX', region: 'Elsewhere' },
  });

  await prisma.beatPlan.create({
    data: {
      clientId,
      agentId: naledi.userId,
      territoryId: territory.gpe,
      name: 'Soweto beat run',
      scheduledDate: new Date('2026-09-15T00:00:00Z'),
    },
  });

  const mkOutlet = (cid: string, name: string, code: string, territoryCode: string) =>
    prisma.outlet.create({
      data: { clientId: cid, name, code, channelType: 'supermarket', lat: -26, lng: 28, territoryId: territoryCode },
    });
  outlet.quicksave = (await mkOutlet(clientId, 'QuickSave Alpha', 'OPS-QS1', 'OPS-GPN')).id;
  outlet.spaza = (await mkOutlet(clientId, 'Corner Spaza', 'OPS-SP1', 'OPS-GPE')).id;
  foreignOutletId = (await mkOutlet(foreign.clientId, 'QuickSave Alpha', 'OPS-QS1', 'OPS-GPN')).id;

  const mkSku = (cid: string, name: string, rrp: number) =>
    prisma.sku.create({ data: { clientId: cid, name, category: 'Beverages', minFacingsStandard: 2, rrp } });
  sku.cola2 = (await mkSku(clientId, 'OPS Cola 2L', 10)).id;
  sku.cola1 = (await mkSku(clientId, 'OPS Cola 1L', 5)).id;
  foreignSkuId = (await mkSku(foreign.clientId, 'OPS Cola 2L', 10)).id;

  // ── Pricing, August ──────────────────────────────────────────────────
  const qs = await visit(clientId, outlet.quicksave, kagiso.userId, '2026-08-10T10:00:00Z');
  await priced(qs.id, sku.cola2, 12, 10, true); // +20
  await priced(qs.id, sku.cola1, 5.75, 5); // +15
  const sp = await visit(clientId, outlet.spaza, naledi.userId, '2026-08-11T10:00:00Z');
  await priced(sp.id, sku.cola2, 10, 10); // 0
  await priced(sp.id, sku.cola1, 4, 5); // −20
  const fx = await visit(foreign.clientId, foreignOutletId, foreign.userId, '2026-08-10T10:00:00Z');
  await priced(fx.id, foreignSkuId, 19, 10); // +90, and must never show up

  // ── Campaigns ────────────────────────────────────────────────────────
  const winter = await prisma.campaign.create({
    data: {
      clientId,
      name: 'OPS Winter Warmer',
      startDate: new Date('2026-05-04T00:00:00Z'),
      endDate: new Date('2026-06-14T00:00:00Z'),
      budget: 300,
      status: 'completed',
      outlets: { create: [{ outletId: outlet.quicksave }, { outletId: outlet.spaza }] },
    },
  });
  await order(clientId, outlet.quicksave, kagiso.userId, sku.cola2, 1, 100, '2026-05-10T10:00:00Z', winter.id);
  // Baseline: the 42 days before 4 May.
  await order(clientId, outlet.spaza, naledi.userId, sku.cola2, 1, 200, '2026-04-20T10:00:00Z');
  await prisma.campaign.create({
    data: {
      clientId,
      name: 'OPS Braai Day',
      startDate: new Date('2026-09-01T00:00:00Z'),
      endDate: new Date('2026-09-30T00:00:00Z'),
      status: 'active',
      outlets: { create: [{ outletId: outlet.spaza }] },
    },
  });
  await prisma.campaign.create({
    data: {
      clientId,
      name: 'OPS Summer Refresh',
      startDate: new Date('2026-11-16T00:00:00Z'),
      endDate: new Date('2026-12-31T00:00:00Z'),
      budget: 200,
    },
  });
  const foreignWinter = await prisma.campaign.create({
    data: {
      clientId: foreign.clientId,
      name: 'OPS Winter Warmer',
      startDate: new Date('2026-05-04T00:00:00Z'),
      endDate: new Date('2026-06-14T00:00:00Z'),
      budget: 1,
      outlets: { create: [{ outletId: foreignOutletId }] },
    },
  });
  await order(foreign.clientId, foreignOutletId, foreign.userId, foreignSkuId, 1, 99_999, '2026-05-10T10:00:00Z', foreignWinter.id);

  // ── Contests ─────────────────────────────────────────────────────────
  const contest = (cid: string, createdById: string, name: string, start: string, end: string, extra = {}) =>
    prisma.contest.create({
      data: {
        clientId: cid,
        createdById,
        name,
        startDate: new Date(`${start}T00:00:00Z`),
        endDate: new Date(`${end}T00:00:00Z`),
        prizeDescription: 'A braai pack',
        ...extra,
      },
    });
  await contest(clientId, manager.userId, 'OPS Visit Sprint', '2026-09-01', '2026-09-30');
  await contest(clientId, manager.userId, 'OPS August Cup', '2026-08-01', '2026-08-31');
  await contest(clientId, manager.userId, 'OPS Festive Push', '2026-12-01', '2026-12-31');
  await contest(clientId, manager.userId, 'OPS Spot Prize', '2026-09-01', '2026-09-30', {
    cancelledAt: new Date('2026-09-05T00:00:00Z'),
  });
  await contest(foreign.clientId, foreign.userId, 'OPS Visit Sprint', '2026-09-01', '2026-09-30');
  await points(clientId, naledi.userId, 10, '2026-09-05T10:00:00Z');
  await points(clientId, naledi.userId, 10, '2026-09-06T10:00:00Z');
  await points(clientId, kagiso.userId, 5, '2026-09-06T10:00:00Z');
  await points(foreign.clientId, foreign.userId, 500, '2026-09-06T10:00:00Z');

  // ── Tasks ────────────────────────────────────────────────────────────
  const task = (outletId: string, ownerId: string, status: 'open' | 'in_progress' | 'closed', slaDueAt: string, createdAt: string, priority: 'critical' | 'high' | 'normal' = 'normal') =>
    prisma.task.create({
      data: {
        outletId,
        ownerId,
        status,
        priority,
        findingType: 'out_of_stock',
        requiredFix: 'Restock the cola bay',
        slaDueAt: new Date(slaDueAt),
        createdAt: new Date(createdAt),
      },
    });
  await task(outlet.quicksave, kagiso.userId, 'open', '2026-09-10T10:00:00Z', '2026-09-05T10:00:00Z', 'critical');
  await task(outlet.quicksave, kagiso.userId, 'in_progress', '2026-09-20T10:00:00Z', '2026-09-06T10:00:00Z');
  await task(outlet.quicksave, kagiso.userId, 'closed', '2026-09-01T10:00:00Z', '2026-08-25T10:00:00Z');
  await task(outlet.spaza, naledi.userId, 'open', '2026-08-01T10:00:00Z', '2026-07-25T10:00:00Z');
  await task(foreignOutletId, foreign.userId, 'open', '2026-08-01T10:00:00Z', '2026-09-02T10:00:00Z');

  // ── Alerts ───────────────────────────────────────────────────────────
  const alert = (cid: string, outletId: string, metric: string, acknowledged: boolean, severity: string, createdAt: string) =>
    prisma.alert.create({
      data: { clientId: cid, outletId, metric, acknowledged, severity, message: `${metric} alert`, createdAt: new Date(createdAt) },
    });
  await alert(clientId, outlet.quicksave, 'price_deviation', false, 'high', '2026-09-10T10:00:00Z');
  await alert(clientId, outlet.quicksave, 'price_deviation', true, 'high', '2026-09-11T10:00:00Z');
  await alert(clientId, outlet.spaza, 'out_of_stock', false, 'normal', '2026-08-15T10:00:00Z');
  await alert(foreign.clientId, foreignOutletId, 'price_deviation', false, 'high', '2026-09-12T10:00:00Z');

  // ── Forecast history: the last 28 complete days ─────────────────────
  await order(clientId, outlet.quicksave, kagiso.userId, sku.cola2, 10, 10, '2026-09-15T08:00:00Z');
  await order(clientId, outlet.spaza, naledi.userId, sku.cola2, 20, 20, '2026-09-16T08:00:00Z');
  await order(foreign.clientId, foreignOutletId, foreign.userId, foreignSkuId, 5000, 1, '2026-09-16T08:00:00Z');
});

afterAll(async () => {
  const clientIds = [clientId, foreign.clientId];
  await prisma.alert.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.task.deleteMany({ where: { outlet: { clientId: { in: clientIds } } } });
  await prisma.pointsLedgerEntry.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.contest.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.orderLine.deleteMany({ where: { order: { clientId: { in: clientIds } } } });
  await prisma.order.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId: { in: clientIds } } } });
  await prisma.campaign.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
  await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.beatPlan.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
  await prisma.user.deleteMany({ where: { clientId } });
  await prisma.client.delete({ where: { id: clientId } });
  await foreign.cleanup();
});

describe('findTerritories', () => {
  it('prefers an exact code', async () => {
    const result = await findTerritories({ clientId, query: 'ops-nmb' });
    expect(result.matchedBy).toBe('exact');
    expect(result.matches).toEqual([
      { territoryId: territory.nmb, name: 'Nelson Mandela Bay', code: 'OPS-NMB', region: 'Eastern Cape', outlets: 0 },
    ]);
  });

  it('lists every partial match with outlet counts, and asks rather than picks', async () => {
    const result = await findTerritories({ clientId, query: 'Gauteng' });
    expect(result.matchedBy).toBe('partial');
    expect(result.matches.map((m) => [m.name, m.outlets])).toEqual([
      ['Gauteng East', 1],
      ['Gauteng North', 1],
    ]);
  });

  it('falls back to the region, then to a beat plan name', async () => {
    expect((await findTerritories({ clientId, query: 'Eastern Cape' })).matches.map((m) => m.territoryId)).toEqual([
      territory.nmb,
    ]);
    const beat = await findTerritories({ clientId, query: 'the Soweto beat' });
    expect(beat.matchedBy).toBe('beat_plan');
    expect(beat.matches.map((m) => m.territoryId)).toEqual([territory.gpe]);
  });

  it('lists all of this tenant\'s territories when no place is named', async () => {
    const result = await findTerritories({ clientId });
    expect(result.matchedBy).toBe('all');
    expect(result.matches).toHaveLength(3);
  });

  it('never resolves another tenant\'s territory', async () => {
    const result = await findTerritories({ clientId, query: 'Foreign Only Place' });
    expect(result).toMatchObject({ matchedBy: 'none', matches: [] });
    const shared = await findTerritories({ clientId, query: 'Gauteng North' });
    expect(shared.matches.map((m) => m.territoryId)).toEqual([territory.gpn]);
    expect(shared.matches.map((m) => m.territoryId)).not.toContain(foreignTerritoryId);
  });
});

describe('getPriceCompliance', () => {
  const run = (extra: Record<string, string> = {}, window = AUGUST) =>
    getPriceCompliance({ clientId, ...window, ...extra });

  it('measures shelf prices against RRP over the window', async () => {
    const result = await run();
    expect(result).toMatchObject({
      thresholdPct: 10,
      pricedLines: 4,
      outletsPriced: 2,
      avgDeviationPct: 3.75,
      avgAbsDeviationPct: 13.75,
      linesAboveThresholdPct: 50,
      linesBelowThresholdPct: 25,
      promoActivePct: 25,
    });
    expect(result.worstOutlets[0]).toMatchObject({ outletName: 'QuickSave Alpha', avgDeviationPct: 17.5, lines: 2 });
    expect(result.bySku.find((s) => s.skuName === 'OPS Cola 2L')).toMatchObject({
      rrp: 10,
      avgShelfPrice: 11,
      avgDeviationPct: 10,
      linesAboveThresholdPct: 50,
    });
  });

  it('narrows by chain name, product and territory', async () => {
    expect(await run({ outletName: 'quicksave' })).toMatchObject({ pricedLines: 2, avgDeviationPct: 17.5, linesAboveThresholdPct: 100 });
    expect(await run({ sku: 'Cola 2L' })).toMatchObject({ pricedLines: 2, avgDeviationPct: 10 });
    expect(await run({ territoryId: territory.gpe })).toMatchObject({ pricedLines: 2, avgDeviationPct: -10 });
    expect(await run({}, JULY)).toMatchObject({ pricedLines: 0, avgDeviationPct: 0, bySku: [], worstOutlets: [] });
  });

  it('uses the client\'s own deviation threshold', async () => {
    await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: { priceDeviationPct: 16 } } });
    try {
      expect(await run()).toMatchObject({ thresholdPct: 16, linesAboveThresholdPct: 25, linesBelowThresholdPct: 25 });
    } finally {
      await prisma.client.update({ where: { id: clientId }, data: { kpiThresholds: {} } });
    }
  });

  it('never reads another tenant\'s prices, even through a shared code or name', async () => {
    const shared = await run({ outletName: 'QuickSave Alpha', territoryId: territory.gpn });
    expect(shared.pricedLines).toBe(2);
    expect((await run({ territoryId: foreignTerritoryId })).pricedLines).toBe(0);
    expect((await getPriceCompliance({ clientId: foreign.clientId, ...AUGUST })).avgDeviationPct).toBe(90);
  });
});

describe('getCampaignPerformance', () => {
  it('delegates ROI and execution to the campaign module', async () => {
    const result = await getCampaignPerformance({ clientId, now: NOW, campaign: 'winter' });
    expect(result.campaigns).toHaveLength(1);
    const [winter] = result.campaigns;
    expect(winter).toMatchObject({
      name: 'OPS Winter Warmer',
      windowState: 'ended',
      startDate: '2026-05-04',
      endDate: '2026-06-14',
      daysTotal: 42,
      daysElapsed: 42,
      outlets: 2,
    });
    expect(winter.performance).toMatchObject({
      liftPct: -50,
      liftComparable: true,
      roi: { attributedRevenue: 100, baselineRevenue: 200, incrementalRevenue: -100, roiPct: -133.33 },
      execution: { outletsTotal: 2 },
    });
  });

  it('marks a running campaign\'s lift as not yet comparable, and measures nothing upcoming', async () => {
    const running = await getCampaignPerformance({ clientId, now: NOW, state: 'running' });
    expect(running.campaigns.map((c) => c.name)).toEqual(['OPS Braai Day']);
    expect(running.campaigns[0]).toMatchObject({ daysElapsed: 17, daysTotal: 30 });
    expect(running.campaigns[0].performance).toMatchObject({ liftComparable: false, roi: { roiPct: null } });

    const upcoming = await getCampaignPerformance({ clientId, now: NOW, state: 'upcoming' });
    expect(upcoming.campaigns).toMatchObject([{ name: 'OPS Summer Refresh', performance: null, daysElapsed: 0 }]);
  });

  it('selects by overlap with a period', async () => {
    const may = resolvePeriod({ kind: 'custom', from: '2026-05-01', to: '2026-05-31' }, NOW, TZ);
    const result = await getCampaignPerformance({ clientId, now: NOW, window: may });
    expect(result.campaigns.map((c) => c.name)).toEqual(['OPS Winter Warmer']);
  });

  it('never lists or counts another tenant\'s campaigns', async () => {
    const all = await getCampaignPerformance({ clientId, now: NOW });
    expect(all.campaigns.map((c) => c.name).sort()).toEqual(['OPS Braai Day', 'OPS Summer Refresh', 'OPS Winter Warmer']);
    expect(all.omitted).toBe(0);
    const winter = all.campaigns.find((c) => c.name === 'OPS Winter Warmer')!;
    expect(winter.performance?.roi.attributedRevenue).toBe(100);
  });
});

describe('getContestLeaderboards', () => {
  it('shows current contests with the module\'s standings, named', async () => {
    const result = await getContestLeaderboards({ clientId, now: NOW, filter: 'current' });
    expect(result.contests.map((c) => c.name).sort()).toEqual(['OPS August Cup', 'OPS Visit Sprint']);
    const sprint = result.contests.find((c) => c.name === 'OPS Visit Sprint')!;
    expect(sprint).toMatchObject({ status: 'active', prize: 'A braai pack', participants: 2, daysLeft: 14 });
    expect(sprint.standings.slice(0, 2)).toMatchObject([
      { rank: 1, agentName: 'Naledi Sithole', points: 20, visitsSubmitted: 2 },
      { rank: 2, agentName: 'Kagiso Molefe', points: 5 },
    ]);
  });

  it('filters by status and name, and draws no board before a contest starts', async () => {
    const upcoming = await getContestLeaderboards({ clientId, now: NOW, filter: 'upcoming' });
    expect(upcoming.contests).toMatchObject([{ name: 'OPS Festive Push', standings: [], participants: 0 }]);
    const cancelled = await getContestLeaderboards({ clientId, now: NOW, filter: 'cancelled' });
    expect(cancelled.contests.map((c) => c.name)).toEqual(['OPS Spot Prize']);
    const named = await getContestLeaderboards({ clientId, now: NOW, filter: 'all', contest: 'august' });
    expect(named.contests.map((c) => c.name)).toEqual(['OPS August Cup']);
  });

  it('never shows another tenant\'s contest or its agents', async () => {
    const all = await getContestLeaderboards({ clientId, now: NOW, filter: 'all' });
    expect(all.contests).toHaveLength(4);
    const agentIds = all.contests.flatMap((c) => c.standings.map((s) => s.agentId));
    expect(agentIds).not.toContain(foreign.userId);
  });
});

describe('getTaskSummary', () => {
  it('reports the backlog as of now, by agent and territory', async () => {
    const result = await getTaskSummary({ clientId, now: NOW });
    expect(result.backlog).toEqual({
      open: 2,
      inProgress: 1,
      overdue: 2,
      overdueByPriority: [
        { priority: 'critical', overdue: 1 },
        { priority: 'normal', overdue: 1 },
      ],
    });
    expect(result.raisedInPeriod).toBeNull();
    expect(result.overdueByAgent.map((a) => a.agentName).sort()).toEqual(['Kagiso Molefe', 'Naledi Sithole']);
    expect(result.overdueByTerritory).toEqual([
      { territoryCode: 'OPS-GPE', territoryName: 'Gauteng East', overdue: 1 },
      { territoryCode: 'OPS-GPN', territoryName: 'Gauteng North', overdue: 1 },
    ]);
    expect(result.oldestOverdue[0]).toMatchObject({ outletName: 'Corner Spaza', ownerName: 'Naledi Sithole' });
  });

  it('counts tasks raised in a period, and narrows by territory or agent', async () => {
    const mtd = await getTaskSummary({ clientId, now: NOW, window: MTD });
    expect(mtd.raisedInPeriod).toEqual({ raised: 2, closed: 0, stillOpen: 2, overdue: 1 });
    expect((await getTaskSummary({ clientId, now: NOW, territoryId: territory.gpn })).backlog).toMatchObject({
      open: 1,
      inProgress: 1,
      overdue: 1,
    });
    expect((await getTaskSummary({ clientId, now: NOW, agentId: naledi.userId })).backlog.overdue).toBe(1);
  });

  it('never counts another tenant\'s tasks', async () => {
    const foreignScope = await getTaskSummary({ clientId, now: NOW, territoryId: foreignTerritoryId });
    expect(foreignScope.backlog).toMatchObject({ open: 0, overdue: 0 });
    const byForeignAgent = await getTaskSummary({ clientId, now: NOW, agentId: foreign.userId });
    expect(byForeignAgent.backlog.overdue).toBe(0);
    expect((await getTaskSummary({ clientId: foreign.clientId, now: NOW })).backlog.overdue).toBe(1);
  });
});

describe('getAlertSummary', () => {
  it('counts alerts by type and state, with the outlets holding the most open', async () => {
    const result = await getAlertSummary({ clientId });
    expect(result).toMatchObject({ raised: 3, unacknowledged: 2 });
    expect(result.byType).toEqual([
      { type: 'price_deviation', raised: 2, unacknowledged: 1 },
      { type: 'out_of_stock', raised: 1, unacknowledged: 1 },
    ]);
    expect(result.unacknowledgedBySeverity).toEqual([
      { severity: 'high', unacknowledged: 1 },
      { severity: 'normal', unacknowledged: 1 },
    ]);
    expect(result.topOutlets.map((o) => o.outletName).sort()).toEqual(['Corner Spaza', 'QuickSave Alpha']);
    expect(result.newestUnacknowledged[0]).toMatchObject({ type: 'price_deviation', outletName: 'QuickSave Alpha' });
  });

  it('narrows by type, period and territory', async () => {
    expect(await getAlertSummary({ clientId, type: 'price_deviation' })).toMatchObject({ raised: 2, unacknowledged: 1 });
    expect(await getAlertSummary({ clientId, window: MTD })).toMatchObject({ raised: 2 });
    expect(await getAlertSummary({ clientId, territoryId: territory.gpe })).toMatchObject({ raised: 1 });
  });

  it('never counts another tenant\'s alerts', async () => {
    expect(await getAlertSummary({ clientId, territoryId: foreignTerritoryId })).toMatchObject({
      raised: 0,
      topOutlets: [],
      newestUnacknowledged: [],
    });
    expect((await getAlertSummary({ clientId, window: MTD })).newestUnacknowledged).toHaveLength(1);
  });
});

describe('getSellInForecast', () => {
  it('wraps the forecast module and says plainly that there is no confidence measure', async () => {
    const result = await getSellInForecast({ clientId, now: NOW, sku: 'ops cola 2l' });
    expect(result).toMatchObject({
      skuId: sku.cola2,
      skuName: 'OPS Cola 2L',
      historyDays: 28,
      historyTotalUnits: 30,
      daysWithOrders: 2,
      confidence: null,
      daysOfCover: 0,
    });
    expect(result.historyPoints.slice(-2)).toEqual([10, 20]);
    expect(result.forecastDailyUnits).toBeGreaterThan(0);
    expect(result.method).toMatch(/exponential smoothing/);
    expect(result.confidenceNote).toMatch(/No confidence interval/);
  });

  it('forecasts one outlet', async () => {
    const result = await getSellInForecast({ clientId, now: NOW, sku: sku.cola2, outletId: outlet.spaza });
    expect(result).toMatchObject({ outletName: 'Corner Spaza', historyTotalUnits: 20 });
  });

  it('asks which product when a name is ambiguous, and says when none matches', async () => {
    await expect(getSellInForecast({ clientId, now: NOW, sku: 'Cola' })).rejects.toThrow(SkuLookupError);
    await expect(getSellInForecast({ clientId, now: NOW, sku: 'Cola' })).rejects.toThrow(/OPS Cola 1L, OPS Cola 2L/);
    await expect(getSellInForecast({ clientId, now: NOW, sku: 'Rusks' })).rejects.toThrow(/No product/);
  });

  it('never resolves another tenant\'s product or outlet, or counts its orders', async () => {
    await expect(getSellInForecast({ clientId, now: NOW, sku: foreignSkuId })).rejects.toThrow(SkuLookupError);
    await expect(
      getSellInForecast({ clientId, now: NOW, sku: sku.cola2, outletId: foreignOutletId }),
    ).rejects.toThrow(OutletLookupError);
    expect((await getSellInForecast({ clientId, now: NOW, sku: 'OPS Cola 2L' })).historyTotalUnits).toBe(30);
  });
});
