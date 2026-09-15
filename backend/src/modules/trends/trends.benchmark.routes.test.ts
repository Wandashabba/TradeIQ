import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { foreignTenant, userIn } from '../../test-utils/tenants';

// Two fixed 2026 weeks (UTC Mondays) so bucketing is deterministic.
const WEEK_A = '2026-03-02T00:00:00.000Z';
const WEEK_B = '2026-03-09T00:00:00.000Z';
const A_DAY_1 = new Date('2026-03-03T10:00:00.000Z');
const A_DAY_2 = new Date('2026-03-05T14:00:00.000Z');
const A_STOCK = new Date('2026-03-04T08:00:00.000Z');
const B_DAY_1 = new Date('2026-03-10T09:00:00.000Z');

/**
 * #123 — territory benchmark and the territory filter on every trend series.
 *
 * The fixtures carry real `Territory` rows whose uuid `id` can never equal the
 * literal `code` outlets link by, plus a decoy outlet whose `territoryId` holds
 * North's *id*. If any join compares `Territory.id` to `Outlet.territoryId`,
 * either North loses all its data or the decoy's 20-point scorecard lands in
 * North — both break the exact figures asserted below (#97, #285).
 *
 * Client A, scorecards (green >= 80):
 *   North outlet N1: A_DAY_1 60 amber, A_DAY_2 90 green, B_DAY_1 100 green
 *   South outlet S1: A_DAY_1 50 red
 *   Decoy outlet X (territoryId = north.id): A_DAY_2 20 red
 *   Empty territory: no outlets at all
 * Client B has its own territory with the SAME code as A's North and a 5-point
 * scorecard in week A, which must never reach client A.
 */
describe('trends territory benchmark (#123)', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let otherManagerToken: string;
  let northId: string;
  let southId: string;
  let emptyId: string;
  let otherNorthId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'TBENCH-Client A',
        industry: 'FMCG',
        scorecardWeights: {},
        // A non-default green floor, so the target provably comes from config.
        kpiThresholds: { green: 75, amber: 60 },
      },
    });
    clientId = client.id;
    managerToken = (await userIn(clientId, 'manager')).token;
    const agent = await userIn(clientId, 'field_agent');
    agentToken = agent.token;

    const [north, south, empty] = await Promise.all([
      prisma.territory.create({ data: { clientId, name: 'TBENCH North', code: 'tb-north' } }),
      prisma.territory.create({ data: { clientId, name: 'TBENCH South', code: 'tb-south' } }),
      prisma.territory.create({ data: { clientId, name: 'TBENCH Empty', code: 'tb-empty' } }),
    ]);
    northId = north.id;
    southId = south.id;
    emptyId = empty.id;
    expect(north.id).not.toBe(north.code);

    const outlet = (code: string, territoryId: string, owner = clientId) =>
      prisma.outlet.create({
        data: {
          name: `TBENCH ${code}`,
          code,
          channelType: 'hypermarket',
          lat: -26.2,
          lng: 28.0,
          territoryId,
          clientId: owner,
        },
      });
    const n1 = await outlet('TBENCH-N1', north.code);
    const s1 = await outlet('TBENCH-S1', south.code);
    // The trap: an outlet whose territoryId is North's id, not its code.
    const decoy = await outlet('TBENCH-X', north.id);

    const sku = await prisma.sku.create({
      data: { clientId, name: 'TBENCH-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });

    const visit = async (outletId: string, at: Date, owner = clientId, agentId = agent.userId) =>
      (
        await prisma.visit.create({
          data: {
            outletId,
            agentId,
            clientId: owner,
            checkinTs: at,
            checkinLat: -26.2,
            checkinLng: 28.0,
            geofencePass: true,
            status: 'submitted',
          },
        })
      ).id;

    const vN1a = await visit(n1.id, A_DAY_1);
    const vN1b = await visit(n1.id, A_DAY_2);
    const vN1c = await visit(n1.id, B_DAY_1);
    const vS1 = await visit(s1.id, A_DAY_1);
    const vX = await visit(decoy.id, A_DAY_2);

    const card = (visitId: string, weightedTotal: number, ratingBand: string, createdAt: Date) => ({
      visitId,
      dimensionScores: {},
      weightedTotal,
      ratingBand,
      createdAt,
    });
    await prisma.scorecard.createMany({
      data: [
        card(vN1a, 60, 'amber', A_DAY_1),
        card(vN1b, 90, 'green', A_DAY_2),
        card(vN1c, 100, 'green', B_DAY_1),
        card(vS1, 50, 'red', A_DAY_1),
        card(vX, 20, 'red', A_DAY_2),
      ],
    });

    const stock = (visitId: string, units: number) => ({
      visitId,
      skuId: sku.id,
      unitsAvailable: units,
      lastStockinDate: new Date('2026-02-20T00:00:00.000Z'),
      daysOutOfStock: units > 0 ? 0 : 5,
      velocityAvg: 4,
      coverageDaysPredicted: units > 0 ? 5 : 0,
      salesActual: 100,
      salesTarget: 120,
      createdAt: A_STOCK,
    });
    // North: 1 of 2 in stock (50%). South: 1 of 1 (100%). Client: 2 of 3.
    await prisma.visitStock.createMany({
      data: [stock(vN1a, 10), stock(vN1a, 0), stock(vS1, 5)],
    });

    // Share of shelf: North 8 own vs 2 competitor (80%); South 3 vs 3 (50%).
    // Every other visit captured no facings and must not count as 0%.
    const visibility = (visitId: string, total: number) => ({
      visitId,
      brandingElements: {},
      planogramCompliancePct: 80,
      facingsCount: { total },
      highTrafficPass: true,
      cleanlinessScore: 4,
    });
    await prisma.visitVisibility.createMany({ data: [visibility(vN1a, 8), visibility(vS1, 3)] });
    const competitive = (visitId: string, facingsCount: number) => ({
      visitId,
      competitorSku: 'TBENCH-Rival',
      competitorPrice: 17.99,
      competitorPosmType: 'shelf_strip',
      competitorPromoterPresent: false,
      facingsCount,
      geotag: {},
    });
    await prisma.visitCompetitive.createMany({ data: [competitive(vN1a, 2), competitive(vS1, 3)] });

    // Client B: same territory code as A's North, with data in week A.
    const other = await prisma.client.create({
      data: { name: 'TBENCH-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;
    otherManagerToken = (await userIn(otherClientId, 'manager')).token;
    const otherAgent = await userIn(otherClientId, 'field_agent');
    const otherNorth = await prisma.territory.create({
      data: { clientId: otherClientId, name: 'TBENCH-B North', code: 'tb-north' },
    });
    otherNorthId = otherNorth.id;
    const otherOutlet = await outlet('TBENCH-B1', 'tb-north', otherClientId);
    const vB = await visit(otherOutlet.id, A_DAY_1, otherClientId, otherAgent.userId);
    await prisma.scorecard.create({ data: card(vB, 5, 'red', A_DAY_1) });
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    const byVisit = { where: { visit: { clientId: { in: clientIds } } } };
    await prisma.scorecard.deleteMany(byVisit);
    await prisma.visitStock.deleteMany(byVisit);
    await prisma.visitVisibility.deleteMany(byVisit);
    await prisma.visitCompetitive.deleteMany(byVisit);
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.territory.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  const get = (path: string, query: Record<string, string> = {}, token = managerToken) =>
    request(app).get(path).query(query).set('Authorization', `Bearer ${token}`);

  describe('territoryId filter on the series', () => {
    it('resolves a Territory.id to its code (North)', async () => {
      const res = await get('/trends/scorecards', { territoryId: northId });
      expect(res.status).toBe(200);
      // Id-vs-code: comparing the id matches the decoy (20) instead of N1.
      expect(res.body.points).toEqual([
        { period: WEEK_A, value: 75, count: 2 },
        { period: WEEK_B, value: 100, count: 1 },
      ]);
    });

    it('scopes every metric, not just scorecards', async () => {
      const [perfect, availability, share] = await Promise.all([
        get('/trends/perfect-store', { territoryId: southId }),
        get('/trends/availability', { territoryId: southId }),
        get('/trends/share-of-shelf', { territoryId: southId }),
      ]);
      expect(perfect.body.points).toEqual([{ period: WEEK_A, value: 0, count: 1 }]);
      expect(availability.body.points).toEqual([{ period: WEEK_A, value: 100, count: 1 }]);
      expect(share.body.points).toEqual([{ period: WEEK_A, value: 50, count: 1 }]);
    });

    it('treats a code passed as territoryId as unknown, not as a match', async () => {
      const res = await get('/trends/scorecards', { territoryId: 'tb-north' });
      expect(res.status).toBe(200);
      expect(res.body.points).toEqual([]);
    });

    it("matches nothing for another client's territory or a bogus id", async () => {
      const [foreign, bogus] = await Promise.all([
        get('/trends/scorecards', { territoryId: otherNorthId }),
        get('/trends/scorecards', { territoryId: 'no-such-territory' }),
      ]);
      expect(foreign.body.points).toEqual([]);
      expect(bogus.body.points).toEqual([]);
    });

    it('returns an empty series for a territory with no outlets', async () => {
      const res = await get('/trends/availability', { territoryId: emptyId });
      expect(res.status).toBe(200);
      expect(res.body.points).toEqual([]);
    });
  });

  describe('GET /trends/benchmark', () => {
    it('ranks territories against the client average for scorecards', async () => {
      const res = await get('/trends/benchmark', { metric: 'scorecards' });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        metric: 'scorecards',
        interval: 'week',
        unit: 'score',
        target: { value: 75, label: 'Green threshold' },
        // All five of A's scorecards, including the unassigned decoy.
        client: {
          average: 64,
          count: 5,
          points: [
            { period: WEEK_A, value: 55, count: 4 },
            { period: WEEK_B, value: 100, count: 1 },
          ],
        },
        unassigned: { count: 1 },
      });
      expect(res.body.territories).toEqual([
        {
          territoryId: northId,
          territoryName: 'TBENCH North',
          territoryCode: 'tb-north',
          average: 83.33,
          count: 3,
          points: [
            { period: WEEK_A, value: 75, count: 2 },
            { period: WEEK_B, value: 100, count: 1 },
          ],
          rank: 1,
          deltaFromClient: 19.33,
          position: 'above',
        },
        {
          territoryId: southId,
          territoryName: 'TBENCH South',
          territoryCode: 'tb-south',
          average: 50,
          count: 1,
          // No week-B point: South had no scorecards then, and a 0 would lie.
          points: [{ period: WEEK_A, value: 50, count: 1 }],
          rank: 2,
          deltaFromClient: -14,
          position: 'below',
        },
        {
          territoryId: emptyId,
          territoryName: 'TBENCH Empty',
          territoryCode: 'tb-empty',
          average: null,
          count: 0,
          points: [],
          rank: null,
          deltaFromClient: null,
          position: null,
        },
      ]);
    });

    it('keeps the client line identical to the unfiltered trend series', async () => {
      for (const [metric, path] of [
        ['scorecards', '/trends/scorecards'],
        ['perfectStore', '/trends/perfect-store'],
        ['availability', '/trends/availability'],
      ] as const) {
        const [bench, series] = await Promise.all([
          get('/trends/benchmark', { metric }),
          get(path),
        ]);
        expect(bench.body.client.points).toEqual(series.body.points);
      }
    });

    it('distinguishes a measured 0% from a territory with no data (perfect store)', async () => {
      const res = await get('/trends/benchmark', { metric: 'perfectStore' });
      expect(res.status).toBe(200);
      expect(res.body.unit).toBe('percent');
      expect(res.body.target).toBeNull();
      expect(res.body.client).toMatchObject({ average: 40, count: 5 });
      const byName = Object.fromEntries(
        res.body.territories.map((t: { territoryName: string }) => [t.territoryName, t]),
      );
      expect(byName['TBENCH North']).toMatchObject({ average: 66.67, rank: 1, position: 'above' });
      expect(byName['TBENCH South']).toMatchObject({ average: 0, count: 1, rank: 2, position: 'below' });
      expect(byName['TBENCH Empty']).toMatchObject({ average: null, count: 0, rank: null });
    });

    it('ranks by the requested metric (availability flips the order)', async () => {
      const res = await get('/trends/benchmark', { metric: 'availability' });
      expect(res.body.client).toMatchObject({ average: 66.67, count: 3 });
      expect(
        res.body.territories.map((t: { territoryName: string; average: number | null }) => [
          t.territoryName,
          t.average,
        ]),
      ).toEqual([
        ['TBENCH South', 100],
        ['TBENCH North', 50],
        ['TBENCH Empty', null],
      ]);
      expect(res.body.unassigned).toEqual({ count: 0 });
    });

    it('counts only visits that captured facings for share of shelf', async () => {
      const res = await get('/trends/benchmark', { metric: 'shareOfShelf' });
      expect(res.status).toBe(200);
      // own 8+3=11, competitor 2+3=5 → 68.75 over the two visits with facings.
      // Week B's visit captured none, so there is no week-B point at all.
      expect(res.body.client).toEqual({
        average: 68.75,
        count: 2,
        points: [{ period: WEEK_A, value: 68.75, count: 2 }],
      });
      expect(res.body.unassigned).toEqual({ count: 0 });
      expect(res.body.territories[0]).toMatchObject({ territoryName: 'TBENCH North', average: 80, count: 1 });
      expect(res.body.territories[1]).toMatchObject({ territoryName: 'TBENCH South', average: 50, count: 1 });
    });

    it('buckets by day and honours the window', async () => {
      const daily = await get('/trends/benchmark', { metric: 'scorecards', interval: 'day' });
      expect(daily.body.interval).toBe('day');
      expect(daily.body.territories[0].points).toEqual([
        { period: '2026-03-03T00:00:00.000Z', value: 60, count: 1 },
        { period: '2026-03-05T00:00:00.000Z', value: 90, count: 1 },
        { period: '2026-03-10T00:00:00.000Z', value: 100, count: 1 },
      ]);

      const weekB = await get('/trends/benchmark', {
        metric: 'scorecards',
        from: '2026-03-09T00:00:00.000Z',
        to: '2026-03-16T00:00:00.000Z',
      });
      expect(weekB.body.client).toMatchObject({ average: 100, count: 1 });
      expect(weekB.body.unassigned).toEqual({ count: 0 });
      const [first, ...rest] = weekB.body.territories;
      expect(first).toMatchObject({ territoryName: 'TBENCH North', average: 100, position: 'level', rank: 1 });
      for (const territory of rest) {
        expect(territory).toMatchObject({ average: null, count: 0, points: [], position: null });
      }
    });

    it("only ever shows the caller's own tenant", async () => {
      const res = await get('/trends/benchmark', { metric: 'scorecards' }, otherManagerToken);
      expect(res.status).toBe(200);
      expect(res.body.client).toMatchObject({ average: 5, count: 1 });
      expect(res.body.target).toEqual({ value: 80, label: 'Green threshold' });
      expect(res.body.territories).toEqual([
        expect.objectContaining({ territoryId: otherNorthId, average: 5, count: 1, position: 'level' }),
      ]);

      // And A never sees B's 5-point card, despite the shared territory code.
      const mine = await get('/trends/benchmark', { metric: 'scorecards' });
      expect(mine.body.territories.map((t: { territoryId: string }) => t.territoryId)).not.toContain(
        otherNorthId,
      );
    });

    it('returns no territories and a null average for a client with nothing', async () => {
      const tenant = await foreignTenant('manager');
      try {
        const res = await get('/trends/benchmark', { metric: 'availability' }, tenant.token);
        expect(res.status).toBe(200);
        expect(res.body).toEqual({
          metric: 'availability',
          interval: 'week',
          unit: 'percent',
          target: null,
          client: { average: null, count: 0, points: [] },
          unassigned: { count: 0 },
          territories: [],
        });
      } finally {
        await tenant.cleanup();
      }
    });

    it.each([
      [{}, /metric/],
      [{ metric: 'revenue' }, /metric/],
      [{ metric: 'scorecards', interval: 'month' }, /interval/],
      [{ metric: 'scorecards', from: 'not-a-date' }, /from/],
      [{ metric: 'scorecards', territoryId: 'x' }, /territoryId/],
    ])('rejects %j with 400', async (query, message) => {
      const res = await get('/trends/benchmark', query as Record<string, string>);
      expect(res.status).toBe(400);
      expect(res.body.error).toMatch(message);
    });

    it('forbids a field agent and requires a token', async () => {
      const forbidden = await get('/trends/benchmark', { metric: 'scorecards' }, agentToken);
      expect(forbidden.status).toBe(403);
      const anonymous = await request(app).get('/trends/benchmark').query({ metric: 'scorecards' });
      expect(anonymous.status).toBe(401);
    });
  });
});
