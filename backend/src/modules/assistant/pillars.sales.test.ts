import { prisma } from '../../lib/prisma';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { monthWindow, parseMonth } from '../salesTargets/salesMonth';
import { getSalesAttainment } from '../salesTargets/salesTargets.service';
import { resolvePeriod } from './period';
import { getSalesPerformance } from './pillars.service';

type Foreign = Awaited<ReturnType<typeof foreignTenant>>;

/**
 * The assistant's sales pillar, after the switch from `VisitStock.salesActual`
 * to order-derived sell-in (#337).
 *
 * The suite that matters most is the first one: the assistant's figure and the
 * console's attainment report must be the same number for the same month, or
 * the two surfaces disagree in front of a manager who has both open.
 */
describe('getSalesPerformance — sell-in, not shelf-typed sales (#337)', () => {
  const TZ = 'Africa/Johannesburg';
  /** A whole month as the assistant would resolve it: local days, half-open. */
  const month = (key: string) => monthWindow(parseMonth(key)!, TZ);
  /** A custom period, resolved exactly as the tool layer resolves one. */
  const custom = (from: string, to: string) =>
    resolvePeriod({ kind: 'custom', from, to }, new Date('2026-06-20T09:00:00.000Z'), TZ);

  let clientId: string;
  let manager: TestUser;
  let agent: TestUser;
  let foreign: Foreign;

  let colaId: string;
  let chipsId: string;
  let edgeId: string;
  let t1Id: string;
  let t2Id: string;
  let o1Id: string;
  let o2Id: string;
  let foreignOutletId: string;
  let foreignSkuId: string;
  let foreignTerritoryId: string;

  async function order(
    outletId: string,
    skuId: string,
    quantity: number,
    capturedAt: string,
    options: { status?: string; clientId?: string; agentId?: string; createdAt?: string } = {},
  ) {
    await prisma.order.create({
      data: {
        clientId: options.clientId ?? clientId,
        outletId,
        agentId: options.agentId ?? agent.userId,
        status: options.status ?? 'submitted',
        total: quantity,
        // `capturedAt` is what every "which month is this order in" rule reads
        // (#338); `createdAt` only differs where a test says it does.
        createdAt: new Date(options.createdAt ?? capturedAt),
        capturedAt: new Date(capturedAt),
        lines: { create: [{ skuId, quantity, unitPrice: 1 }] },
      },
    });
  }

  const target = (skuId: string, monthKey: string, targetUnits: number, scope: { territoryId?: string } = {}) =>
    prisma.salesTarget.create({
      data: {
        clientId,
        skuId,
        month: parseMonth(monthKey)!,
        targetUnits,
        territoryId: scope.territoryId ?? null,
        createdById: manager.userId,
      },
    });

  beforeAll(async () => {
    // Timezone left at the default, Africa/Johannesburg (UTC+2, no DST).
    const client = await prisma.client.create({
      data: { name: 'ASP-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    agent = await userIn(clientId, 'field_agent');

    const sku = (name: string, cid = clientId) =>
      prisma.sku.create({
        data: { clientId: cid, name, category: 'Beverages', minFacingsStandard: 2, rrp: 10 },
      });
    colaId = (await sku('ASP-Cola')).id;
    chipsId = (await sku('ASP-Chips')).id;
    edgeId = (await sku('ASP-Edge')).id;

    t1Id = (await prisma.territory.create({ data: { clientId, name: 'North', code: 'ASP-T1' } })).id;
    t2Id = (await prisma.territory.create({ data: { clientId, name: 'South', code: 'ASP-T2' } })).id;
    const outlet = (code: string, territoryCode: string, cid = clientId) =>
      prisma.outlet.create({
        data: {
          clientId: cid,
          name: code,
          code,
          channelType: 'supermarket',
          lat: -26,
          lng: 28,
          territoryId: territoryCode,
        },
      });
    o1Id = (await outlet('ASP-O1', 'ASP-T1')).id;
    o2Id = (await outlet('ASP-O2', 'ASP-T2')).id;

    foreign = await foreignTenant('field_agent');
    foreignSkuId = (await sku('ASP-Cola', foreign.clientId)).id;
    foreignTerritoryId = (
      await prisma.territory.create({ data: { clientId: foreign.clientId, name: 'Away', code: 'ASP-T1' } })
    ).id;
    foreignOutletId = (await outlet('ASP-FX-O1', 'ASP-T1', foreign.clientId)).id;

    // June: 54 units of real sell-in, plus a cancelled order that is not sell-in.
    await order(o1Id, colaId, 30, '2026-06-15T10:00:00Z');
    await order(o2Id, colaId, 20, '2026-06-16T10:00:00Z');
    await order(o2Id, colaId, 99, '2026-06-17T10:00:00Z', { status: 'cancelled' });
    await order(o1Id, chipsId, 4, '2026-06-18T10:00:00Z', { status: 'confirmed' });
    // Another tenant's order, naming a territory code this client also uses.
    await order(foreignOutletId, foreignSkuId, 1000, '2026-06-15T10:00:00Z', {
      clientId: foreign.clientId,
      agentId: foreign.userId,
    });

    // July: sell-in, and deliberately no target at all.
    await order(o1Id, colaId, 10, '2026-07-06T10:00:00Z');

    await target(colaId, '2026-06', 100);
    await target(colaId, '2026-06', 40, { territoryId: t1Id });
  });

  afterAll(async () => {
    const clientIds = [clientId, foreign.clientId];
    await prisma.salesTarget.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.orderLine.deleteMany({ where: { order: { clientId: { in: clientIds } } } });
    await prisma.order.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await foreign.cleanup();
  });

  describe('the figures are the console\'s figures', () => {
    it('reports the same month sell-in as getSalesAttainment for the same window', async () => {
      // The reason this delegates instead of writing its own query: a manager
      // with the console open and the assistant open must not be shown two
      // different numbers for June.
      const { from, to } = month('2026-06');
      const perf = await getSalesPerformance({ clientId, from, to });
      const report = await getSalesAttainment({ clientId, month: parseMonth('2026-06')! });

      expect(perf.sellInUnits).toBe(report.skus.reduce((sum, sku) => sum + sku.actualUnits, 0));
      expect(perf.sellInUnits).toBe(54);
      // And attainment is the console's attainment, to the unit: the same
      // numerator (targeted SKUs only) over the same targets.
      expect(perf.targetedSellInUnits).toBe(report.summary.client.actualUnits);
      expect(perf.targetUnits).toBe(report.summary.client.targetUnits);
      expect(perf.attainmentPct).toBe(report.summary.client.attainmentPct);
      expect(perf.from).toEqual(report.from);
      expect(perf.to).toEqual(report.to);
    });

    it('labels every result sell-in, and says outright that it is not sell-out', async () => {
      // The assistant reads this on every round. An unlabelled "sales" number
      // gets reported as sales.
      const perf = await getSalesPerformance({ clientId, ...month('2026-06') });
      expect(perf.metric).toBe('sell_in_units');
      expect(perf.metricLabel).toBe('Sell-in (orders)');
      expect(perf.basis).toMatch(/sell-in/i);
      expect(perf.basis).toMatch(/NOT consumer sell-out/);
      expect(perf.basis).toMatch(/never describe these units as what shoppers bought/i);
      expect(perf.timeZone).toBe(TZ);
    });

    it('counts orders, not shelf-typed salesActual', async () => {
      // A VisitStock row carrying the retired columns must not move the figure:
      // agents stopped filling them in (#112) and nothing may read them again.
      const { from, to } = month('2026-06');
      const before = await getSalesPerformance({ clientId, from, to });

      const visit = await prisma.visit.create({
        data: {
          clientId,
          outletId: o1Id,
          agentId: agent.userId,
          checkinTs: new Date('2026-06-15T10:00:00Z'),
          checkinLat: -26,
          checkinLng: 28,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.visitStock.create({
        data: {
          visitId: visit.id,
          skuId: colaId,
          unitsAvailable: 5,
          lastStockinDate: new Date('2026-06-10T10:00:00Z'),
          daysOutOfStock: 0,
          velocityAvg: 1,
          coverageDaysPredicted: 5,
          salesActual: 777,
          salesTarget: 888,
        },
      });

      const after = await getSalesPerformance({ clientId, from, to });
      expect(after.sellInUnits).toBe(before.sellInUnits);
      expect(after.targetUnits).toBe(before.targetUnits);

      await prisma.visitStock.deleteMany({ where: { visitId: visit.id } });
      await prisma.visit.delete({ where: { id: visit.id } });
    });
  });

  describe('targets', () => {
    it('reports target and attainment for a month that has one', async () => {
      const perf = await getSalesPerformance({ clientId, ...month('2026-06') });
      expect(perf).toMatchObject({
        sellInUnits: 54,
        // Only cola has a target, so only cola's 50 units are measured against
        // it. The 4 chips are real sell-in that nobody set a target for.
        targetedSellInUnits: 50,
        targetUnits: 100,
        attainmentPct: 50,
        months: ['2026-06'],
        outletsOrdering: 2,
        skusOrdered: 2,
      });
      expect(perf.targetBasis).toMatch(/manager-set monthly sell-in targets for 2026-06/);
      expect(perf.targetBasis).toMatch(/not total sellInUnits/);
    });

    it('says no target is set rather than implying a target of zero', async () => {
      const perf = await getSalesPerformance({ clientId, ...month('2026-07') });
      expect(perf.sellInUnits).toBe(10);
      expect(perf.targetedSellInUnits).toBeNull();
      expect(perf.targetUnits).toBeNull();
      expect(perf.attainmentPct).toBeNull();
      expect(perf.months).toEqual(['2026-07']);
      expect(perf.targetBasis).toMatch(/No sell-in target is set for 2026-07/);
      expect(perf.targetBasis).toMatch(/not a target of zero/);
    });

    it('sums the targets of every month a multi-month window covers', async () => {
      const perf = await getSalesPerformance({ clientId, ...custom('2026-06-01', '2026-07-31') });
      expect(perf.months).toEqual(['2026-06', '2026-07']);
      expect(perf.sellInUnits).toBe(64);
      // June's 100 and July's nothing. The window is whole months, so the
      // target is real even though only one of the two months has one.
      expect(perf.targetUnits).toBe(100);
      // Cola across both months: 50 in June, 10 in July.
      expect(perf.targetedSellInUnits).toBe(60);
      expect(perf.attainmentPct).toBe(60);
    });

    it('narrows both the sell-in and the target to one territory', async () => {
      const perf = await getSalesPerformance({ clientId, ...month('2026-06'), territoryId: t1Id });
      // O1 only: 30 cola + 4 chips. O2's 20 belongs to the other territory.
      expect(perf.sellInUnits).toBe(34);
      expect(perf.outletsOrdering).toBe(1);
      expect(perf.targetedSellInUnits).toBe(30);
      expect(perf.targetUnits).toBe(40);
      expect(perf.attainmentPct).toBe(75);
      expect(perf.targetBasis).toMatch(/for this territory/);

      // The same figures the console draws for that territory's target.
      const report = await getSalesAttainment({ clientId, month: parseMonth('2026-06')!, skuId: colaId });
      expect(report.skus[0].scoped).toEqual([
        expect.objectContaining({ scope: 'territory', targetUnits: 40, actualUnits: 30, attainmentPct: 75 }),
      ]);
    });

    it('has no territory target where none was set, and still reports the units', async () => {
      const perf = await getSalesPerformance({ clientId, ...month('2026-06'), territoryId: t2Id });
      expect(perf.sellInUnits).toBe(20);
      expect(perf.targetedSellInUnits).toBeNull();
      expect(perf.targetUnits).toBeNull();
      expect(perf.attainmentPct).toBeNull();
      expect(perf.targetBasis).toMatch(/No sell-in target is set/);
    });
  });

  describe('a period that is not a whole month', () => {
    it('returns sell-in units with no target, rather than prorating one', async () => {
      // 1 to 15 June: the cola order on the 15th is in, the one on the 16th is
      // not. June's target is 100 for the whole month and nothing here may
      // scale it — a half-month target is a number nobody set.
      const perf = await getSalesPerformance({ clientId, ...custom('2026-06-01', '2026-06-15') });
      expect(perf.sellInUnits).toBe(30);
      expect(perf.months).toEqual([]);
      expect(perf.targetedSellInUnits).toBeNull();
      expect(perf.targetUnits).toBeNull();
      expect(perf.attainmentPct).toBeNull();
      expect(perf.targetBasis).toMatch(/not a whole calendar month/);
      expect(perf.targetBasis).toMatch(/Do not scale a monthly target/);
    });

    it('treats month-to-date as a part-month, target and all', async () => {
      const now = new Date('2026-06-20T09:00:00.000Z');
      const perf = await getSalesPerformance({
        clientId,
        ...resolvePeriod({ kind: 'mtd' }, now, TZ),
      });
      expect(perf.sellInUnits).toBe(54);
      expect(perf.targetUnits).toBeNull();
      expect(perf.attainmentPct).toBeNull();
      expect(perf.targetBasis).toMatch(/not a whole calendar month/);
    });

    it('reports zero sell-in for a quiet period without inventing a target', async () => {
      const perf = await getSalesPerformance({ clientId, ...custom('2026-05-02', '2026-05-09') });
      expect(perf).toMatchObject({
        sellInUnits: 0,
        outletsOrdering: 0,
        skusOrdered: 0,
        targetUnits: null,
        attainmentPct: null,
      });
    });
  });

  describe('the month boundary is the client\'s, and the clock is the device\'s', () => {
    it('keeps an order captured at 23:30 local on the last day in that month (#338)', async () => {
      // An agent takes an order at 23:30 on 30 September standing in a shop
      // with no signal; the phone syncs the next morning. Dated by arrival it
      // was October sell-in and September was short by it.
      await order(o1Id, edgeId, 9, '2026-09-30T21:30:00Z', {
        createdAt: '2026-10-01T06:00:00Z',
      });
      // And the same instant read as a UTC day: 23:30Z on the 30th is already
      // 1 October in Johannesburg, so it belongs to October.
      await order(o1Id, edgeId, 7, '2026-09-30T23:30:00Z');

      const sep = await getSalesPerformance({ clientId, ...month('2026-09') });
      const oct = await getSalesPerformance({ clientId, ...month('2026-10') });
      expect(sep.sellInUnits).toBe(9);
      expect(sep.from.toISOString()).toBe('2026-08-31T22:00:00.000Z');
      expect(sep.to.toISOString()).toBe('2026-09-30T22:00:00.000Z');
      expect(oct.sellInUnits).toBe(7);
    });
  });

  describe('tenant isolation', () => {
    it('never counts another tenant\'s orders, even on the same territory code', async () => {
      const perf = await getSalesPerformance({ clientId, ...month('2026-06') });
      expect(perf.sellInUnits).toBe(54);

      const theirs = await getSalesPerformance({ clientId: foreign.clientId, ...month('2026-06') });
      expect(theirs.sellInUnits).toBe(1000);
      expect(theirs.targetUnits).toBeNull();
    });

    it('matches nothing for another tenant\'s territory id, rather than everything', async () => {
      // The direction this fails in is the whole point: an unresolvable scope
      // that fell back to "no filter" would answer a narrowed question with the
      // entire tenant, and it would read as a working answer.
      const perf = await getSalesPerformance({
        clientId,
        ...month('2026-06'),
        territoryId: foreignTerritoryId,
      });
      expect(perf.sellInUnits).toBe(0);
      expect(perf.targetUnits).toBeNull();

      const nonsense = await getSalesPerformance({
        clientId,
        ...month('2026-06'),
        territoryId: 'no-such-territory-id',
      });
      expect(nonsense.sellInUnits).toBe(0);
    });
  });
});
