import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { TestUser, foreignTenant, userIn } from '../../test-utils/tenants';
import { attainmentPct } from './salesTargets.service';

type Foreign = Awaited<ReturnType<typeof foreignTenant>>;

describe('sales targets routes (#119)', () => {
  let clientId: string;
  let manager: TestUser;
  let admin: TestUser;
  let agent: TestUser;
  let foreign: Foreign;
  let foreignManager: TestUser;

  let colaId: string;
  let chipsId: string;
  let edgeId: string;
  let t1Id: string;
  let t2Id: string;
  let o1Id: string;
  let o2Id: string;

  let foreignSkuId: string;
  let foreignTerritoryId: string;
  let foreignOutletId: string;

  const auth = (user: TestUser) => ({ Authorization: `Bearer ${user.token}` });

  async function order(
    outletId: string,
    skuId: string,
    quantity: number,
    createdAt: string,
    options: { status?: string; clientId?: string; agentId?: string } = {},
  ) {
    await prisma.order.create({
      data: {
        clientId: options.clientId ?? clientId,
        outletId,
        agentId: options.agentId ?? agent.userId,
        status: options.status ?? 'submitted',
        total: quantity,
        createdAt: new Date(createdAt),
        lines: { create: [{ skuId, quantity, unitPrice: 1 }] },
      },
    });
  }

  beforeAll(async () => {
    // Timezone left at the default, Africa/Johannesburg (UTC+2, no DST).
    const client = await prisma.client.create({
      data: { name: 'STGT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    manager = await userIn(clientId, 'manager');
    admin = await userIn(clientId, 'admin');
    agent = await userIn(clientId, 'field_agent');

    const sku = (name: string, cid = clientId) =>
      prisma.sku.create({ data: { clientId: cid, name, category: 'Beverages', minFacingsStandard: 2, rrp: 10 } });
    colaId = (await sku('STGT-Cola')).id;
    chipsId = (await sku('STGT-Chips')).id;
    edgeId = (await sku('STGT-Edge')).id;

    t1Id = (await prisma.territory.create({ data: { clientId, name: 'North', code: 'STGT-T1' } })).id;
    t2Id = (await prisma.territory.create({ data: { clientId, name: 'South', code: 'STGT-T2' } })).id;
    const outlet = (code: string, territoryCode: string, cid = clientId) =>
      prisma.outlet.create({
        data: { clientId: cid, name: code, code, channelType: 'supermarket', lat: -26, lng: 28, territoryId: territoryCode },
      });
    o1Id = (await outlet('STGT-O1', 'STGT-T1')).id;
    o2Id = (await outlet('STGT-O2', 'STGT-T2')).id;

    foreign = await foreignTenant('field_agent');
    foreignManager = await userIn(foreign.clientId, 'manager');
    foreignSkuId = (await sku('STGT-Cola', foreign.clientId)).id;
    foreignTerritoryId = (
      await prisma.territory.create({ data: { clientId: foreign.clientId, name: 'Away', code: 'STGT-T1' } })
    ).id;
    foreignOutletId = (await outlet('STGT-FX-O1', 'STGT-T1', foreign.clientId)).id;
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
    await prisma.$disconnect();
  });

  describe('permissions', () => {
    it('refuses a field agent with 403 on every route', async () => {
      const calls = [
        request(app).get('/sales-targets').query({ month: '2026-01' }),
        request(app).get('/sales-targets/attainment').query({ month: '2026-01' }),
        request(app).put('/sales-targets').send({ skuId: colaId, month: '2026-01', targetUnits: 5 }),
        request(app).post('/sales-targets/import').send({ csv: 'month,sku,targetUnits\n2026-01,STGT-Cola,5' }),
        request(app).delete('/sales-targets/anything'),
      ];
      for (const call of calls) {
        const res = await call.set(auth(agent));
        expect(res.status).toBe(403);
      }
      expect(await prisma.salesTarget.count({ where: { clientId } })).toBe(0);
    });

    it('requires a bearer token', async () => {
      const res = await request(app).get('/sales-targets');
      expect(res.status).toBe(401);
    });

    it('lets an admin set a target too', async () => {
      const res = await request(app)
        .put('/sales-targets')
        .set(auth(admin))
        .send({ skuId: chipsId, month: '2026-01', targetUnits: 7 });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ skuId: chipsId, month: '2026-01', scope: 'client', targetUnits: 7 });
      expect(res.body.createdById).toBe(admin.userId);
    });
  });

  describe('CRUD', () => {
    it('creates with 201, then replaces the same scope with 200 and the same id', async () => {
      const first = await request(app)
        .put('/sales-targets')
        .set(auth(manager))
        .send({ skuId: colaId, month: '2026-02', targetUnits: 100 });
      expect(first.status).toBe(201);
      expect(first.body.sku).toEqual({ id: colaId, name: 'STGT-Cola' });

      const second = await request(app)
        .put('/sales-targets')
        .set(auth(manager))
        .send({ skuId: colaId, month: '2026-02', targetUnits: 120, territoryId: null, outletId: null });
      expect(second.status).toBe(200);
      expect(second.body.id).toBe(first.body.id);
      expect(second.body.targetUnits).toBe(120);

      const list = await request(app).get('/sales-targets').set(auth(manager)).query({ month: '2026-02' });
      expect(list.status).toBe(200);
      expect(list.body.data).toHaveLength(1);
      expect(list.body.nextCursor).toBeNull();
    });

    it('keeps client, territory and outlet targets for one SKU and month as separate scopes', async () => {
      const put = (extra: object, targetUnits: number) =>
        request(app).put('/sales-targets').set(auth(manager)).send({ skuId: colaId, month: '2026-03', targetUnits, ...extra });
      expect((await put({}, 90)).status).toBe(201);
      const territory = await put({ territoryId: t1Id }, 40);
      expect(territory.status).toBe(201);
      expect(territory.body).toMatchObject({ scope: 'territory', territory: { id: t1Id, name: 'North', code: 'STGT-T1' } });
      const outlet = await put({ outletId: o2Id }, 10);
      expect(outlet.status).toBe(201);
      expect(outlet.body).toMatchObject({ scope: 'outlet', outlet: { id: o2Id, code: 'STGT-O2' } });
      expect((await put({ territoryId: t1Id }, 45)).status).toBe(200);

      const all = await request(app).get('/sales-targets').set(auth(manager)).query({ month: '2026-03' });
      expect(all.body.data).toHaveLength(3);

      const byScope = async (query: object) =>
        (await request(app).get('/sales-targets').set(auth(manager)).query({ month: '2026-03', ...query })).body.data;
      expect(await byScope({ scope: 'client' })).toHaveLength(1);
      expect((await byScope({ territoryId: t1Id }))[0].targetUnits).toBe(45);
      expect(await byScope({ outletId: o2Id })).toHaveLength(1);
      expect(await byScope({ skuId: chipsId })).toHaveLength(0);
    });

    it('enforces one row per scope in the database, including the client-wide (all-NULL) scope', async () => {
      const data = { clientId, skuId: edgeId, month: new Date('2027-01-01T00:00:00Z'), targetUnits: 1, createdById: manager.userId };
      await prisma.salesTarget.create({ data });
      await expect(prisma.salesTarget.create({ data })).rejects.toThrow(/Unique constraint/);
      await prisma.salesTarget.create({ data: { ...data, territoryId: t1Id } });
      await expect(prisma.salesTarget.create({ data: { ...data, territoryId: t1Id } })).rejects.toThrow(/Unique constraint/);
      // The same scope in another month is a different target.
      await prisma.salesTarget.create({ data: { ...data, month: new Date('2027-02-01T00:00:00Z') } });
      // And the database refuses a row scoped to both at once, or a mid-month date.
      await expect(prisma.salesTarget.create({ data: { ...data, territoryId: t2Id, outletId: o1Id } })).rejects.toThrow();
      await expect(prisma.salesTarget.create({ data: { ...data, month: new Date('2027-03-15T00:00:00Z') } })).rejects.toThrow();
    });

    it('validates the body', async () => {
      const put = (body: object) => request(app).put('/sales-targets').set(auth(manager)).send(body);
      const base = { skuId: colaId, month: '2026-04', targetUnits: 5 };
      expect((await put({ ...base, month: '2026-4' })).status).toBe(400);
      expect((await put({ ...base, month: '2026-04-15' })).status).toBe(400);
      expect((await put({ ...base, targetUnits: -1 })).status).toBe(400);
      expect((await put({ ...base, targetUnits: 1.5 })).status).toBe(400);
      expect((await put({ ...base, targetUnits: '5' })).status).toBe(400);
      expect((await put({ ...base, skuId: '' })).status).toBe(400);
      expect((await put({ ...base, territoryId: '' })).status).toBe(400);
      const both = await put({ ...base, territoryId: t1Id, outletId: o1Id });
      expect(both.status).toBe(400);
      expect(both.body.error).toMatch(/not both/);

      const list = await request(app).get('/sales-targets').set(auth(manager)).query({ month: 'April' });
      expect(list.status).toBe(400);
      const scope = await request(app).get('/sales-targets').set(auth(manager)).query({ scope: 'region' });
      expect(scope.status).toBe(400);
    });

    it('deletes with 204, then 404s', async () => {
      const created = await request(app)
        .put('/sales-targets')
        .set(auth(manager))
        .send({ skuId: chipsId, month: '2026-05', targetUnits: 3 });
      const del = await request(app).delete(`/sales-targets/${created.body.id}`).set(auth(manager));
      expect(del.status).toBe(204);
      const again = await request(app).delete(`/sales-targets/${created.body.id}`).set(auth(manager));
      expect(again.status).toBe(404);
    });
  });

  describe('tenant isolation', () => {
    it("rejects another client's SKU, territory or outlet with 404", async () => {
      const put = (body: object) =>
        request(app).put('/sales-targets').set(auth(manager)).send({ month: '2026-04', targetUnits: 5, ...body });
      expect((await put({ skuId: foreignSkuId })).status).toBe(404);
      expect((await put({ skuId: colaId, territoryId: foreignTerritoryId })).status).toBe(404);
      expect((await put({ skuId: colaId, outletId: foreignOutletId })).status).toBe(404);
      expect(await prisma.salesTarget.count({ where: { month: new Date('2026-04-01T00:00:00Z') } })).toBe(0);
    });

    it("never lists, deletes or counts another client's targets", async () => {
      const mine = await request(app)
        .put('/sales-targets')
        .set(auth(manager))
        .send({ skuId: colaId, month: '2026-08', targetUnits: 10 });
      expect(mine.status).toBe(201);

      const theirList = await request(app).get('/sales-targets').set(auth(foreignManager)).query({ month: '2026-08' });
      expect(theirList.body.data).toEqual([]);
      const theirDelete = await request(app).delete(`/sales-targets/${mine.body.id}`).set(auth(foreignManager));
      expect(theirDelete.status).toBe(404);
      const theirReport = await request(app)
        .get('/sales-targets/attainment')
        .set(auth(foreignManager))
        .query({ month: '2026-08' });
      expect(theirReport.body.summary.client.targets).toBe(0);
      expect(theirReport.body.skus.map((s: { skuId: string }) => s.skuId)).toEqual([foreignSkuId]);
    });
  });

  describe('CSV import', () => {
    const csv = () =>
      [
        'Month,SKU,Target Units,Territory,Outlet',
        '2026-07,stgt-cola,120,,', // 2: by name, any case
        '2026-07,STGT-Cola,50,STGT-T1,', // 3: territory by code; replaces an existing target
        `2026-07,${chipsId},15,,STGT-O2`, // 4: SKU by id, outlet by code
        '2026-7,STGT-Cola,10,,', // 5: bad month
        '2026-07,STGT-Nope,10,,', // 6: unknown SKU
        '2026-07,STGT-Cola,-3,,', // 7: bad units
        '2026-07,STGT-Cola,5,STGT-T1,STGT-O1', // 8: both scopes
        `2026-07,${foreignSkuId},5,,`, // 9: another client's SKU
        `2026-07,STGT-Cola,5,${foreignTerritoryId},`, // 10: another client's territory
        '2026-07,STGT-Cola,5,,STGT-FX-O1', // 11: another client's outlet code
        '', // 12: blank, skipped
        '"2026-07","STGT-Cola",130,"",""', // 13: duplicates row 2
      ].join('\r\n');

    const july = new Date('2026-07-01T00:00:00Z');

    beforeAll(async () => {
      const res = await request(app)
        .put('/sales-targets')
        .set(auth(manager))
        .send({ skuId: colaId, month: '2026-07', territoryId: t1Id, targetUnits: 45 });
      expect(res.status).toBe(201);
    });

    it('previews on a dry run: per-row errors, actions, and nothing written', async () => {
      const res = await request(app).post('/sales-targets/import').set(auth(manager)).send({ csv: csv(), dryRun: true });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ dryRun: true, totalRows: 11, validRows: 3, invalidRows: 8, created: 2, updated: 1 });
      expect(res.body.rows.map((r: { row: number; action: string }) => [r.row, r.action])).toEqual([
        [2, 'create'],
        [3, 'update'],
        [4, 'create'],
      ]);
      expect(res.body.rows[2]).toMatchObject({ skuName: 'STGT-Chips', scope: 'outlet', outletId: o2Id, outletCode: 'STGT-O2' });

      const errorsByRow = Object.fromEntries(
        res.body.errors.map((e: { row: number; column: string | null; message: string }) => [e.row, e]),
      );
      expect(Object.keys(errorsByRow).map(Number)).toEqual([5, 6, 7, 8, 9, 10, 11, 13]);
      expect(errorsByRow[5].column).toBe('month');
      expect(errorsByRow[6]).toMatchObject({ column: 'sku', message: expect.stringContaining('STGT-Nope') });
      expect(errorsByRow[7].column).toBe('targetUnits');
      expect(errorsByRow[8].message).toMatch(/not both/);
      expect(errorsByRow[9].column).toBe('sku');
      expect(errorsByRow[10].column).toBe('territory');
      expect(errorsByRow[11].column).toBe('outlet');
      expect(errorsByRow[13].message).toMatch(/Duplicates row 2/);

      const stored = await prisma.salesTarget.findMany({ where: { clientId, month: july } });
      expect(stored).toHaveLength(1);
      expect(stored[0].targetUnits).toBe(45);
    });

    it('applies every valid row in one go and reports the invalid ones', async () => {
      const res = await request(app).post('/sales-targets/import').set(auth(manager)).send({ csv: csv() });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ dryRun: false, validRows: 3, invalidRows: 8, created: 2, updated: 1 });

      const stored = await prisma.salesTarget.findMany({ where: { clientId, month: july } });
      expect(stored).toHaveLength(3);
      expect(stored.find((s) => s.territoryId === t1Id)?.targetUnits).toBe(50);
      expect(stored.find((s) => !s.territoryId && !s.outletId)?.targetUnits).toBe(120);
      expect(stored.every((s) => s.createdById === manager.userId)).toBe(true);
      expect(await prisma.salesTarget.count({ where: { clientId: foreign.clientId } })).toBe(0);

      // Re-uploading is idempotent: the same rows now all update.
      const again = await request(app).post('/sales-targets/import').set(auth(manager)).query({ dryRun: 'true' }).send({ csv: csv() });
      expect(again.body).toMatchObject({ dryRun: true, created: 0, updated: 3 });
    });

    it('refuses a file it cannot read as targets with 400', async () => {
      const post = (body: object) => request(app).post('/sales-targets/import').set(auth(manager)).send(body);
      expect((await post({})).status).toBe(400);
      expect((await post({ csv: '' })).status).toBe(400);
      expect((await post({ csv: 'month,sku,targetUnits' })).status).toBe(400);
      const missing = await post({ csv: 'month,sku\n2026-07,STGT-Cola' });
      expect(missing.status).toBe(400);
      expect(missing.body.error).toMatch(/targetUnits/);
      expect((await post({ csv: 'month,sku,targetUnits\n"2026-07,STGT-Cola,1' })).status).toBe(400);
      expect((await post({ csv: 'month,sku,targetUnits', dryRun: 'yes' })).status).toBe(400);
    });
  });

  describe('actual sell-in vs target', () => {
    it('divides actual by target, and has no attainment without a positive target', () => {
      expect(attainmentPct(50, 100)).toBe(50);
      expect(attainmentPct(20, 10)).toBe(200);
      expect(attainmentPct(1, 3)).toBe(33.33);
      expect(attainmentPct(4, 0)).toBeNull();
      expect(attainmentPct(4, null)).toBeNull();
    });

    it('sums non-cancelled order lines per SKU, territory and outlet for the month', async () => {
      const put = (body: object) => request(app).put('/sales-targets').set(auth(manager)).send({ month: '2026-06', ...body });
      await put({ skuId: colaId, targetUnits: 100 });
      await put({ skuId: colaId, territoryId: t1Id, targetUnits: 40 });
      await put({ skuId: colaId, outletId: o2Id, targetUnits: 10 });
      await put({ skuId: chipsId, targetUnits: 0 });

      await order(o1Id, colaId, 30, '2026-06-15T10:00:00Z');
      await order(o2Id, colaId, 20, '2026-06-16T10:00:00Z');
      await order(o2Id, colaId, 99, '2026-06-17T10:00:00Z', { status: 'cancelled' });
      await order(o1Id, chipsId, 4, '2026-06-18T10:00:00Z', { status: 'confirmed' });
      // Another tenant's order, even one naming this client's SKU, is not this client's sell-in.
      await order(foreignOutletId, colaId, 1000, '2026-06-15T10:00:00Z', {
        clientId: foreign.clientId,
        agentId: foreign.userId,
      });

      const res = await request(app).get('/sales-targets/attainment').set(auth(manager)).query({ month: '2026-06' });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({
        month: '2026-06',
        timeZone: 'Africa/Johannesburg',
        metric: 'sell_in_units',
        metricLabel: 'Sell-in (orders)',
        truncated: false,
      });

      const cola = res.body.skus.find((s: { skuId: string }) => s.skuId === colaId);
      expect(cola).toMatchObject({ targetUnits: 100, actualUnits: 50, attainmentPct: 50 });
      expect(cola.scoped).toEqual([
        expect.objectContaining({ scope: 'territory', targetUnits: 40, actualUnits: 30, attainmentPct: 75 }),
        expect.objectContaining({ scope: 'outlet', targetUnits: 10, actualUnits: 20, attainmentPct: 200 }),
      ]);
      const chips = res.body.skus.find((s: { skuId: string }) => s.skuId === chipsId);
      expect(chips).toMatchObject({ targetUnits: 0, actualUnits: 4, attainmentPct: null });
      const edge = res.body.skus.find((s: { skuId: string }) => s.skuId === edgeId);
      expect(edge).toMatchObject({ targetId: null, targetUnits: null, attainmentPct: null, scoped: [] });

      expect(res.body.summary).toEqual({
        client: { targets: 2, targetUnits: 100, actualUnits: 54, attainmentPct: 54 },
        territory: { targets: 1, targetUnits: 40, actualUnits: 30, attainmentPct: 75 },
        outlet: { targets: 1, targetUnits: 10, actualUnits: 20, attainmentPct: 200 },
      });

      const one = await request(app).get('/sales-targets/attainment').set(auth(manager)).query({ month: '2026-06', skuId: chipsId });
      expect(one.body.skus).toHaveLength(1);
      expect(one.body.summary.client).toMatchObject({ targets: 1, actualUnits: 4 });
    });

    it("draws the month boundary on the client's local calendar days", async () => {
      await order(o1Id, edgeId, 11, '2026-08-31T21:30:00Z'); // 23:30 on 31 Aug in Johannesburg
      await order(o1Id, edgeId, 3, '2026-08-31T22:30:00Z'); // 00:30 on 1 Sep
      await order(o1Id, edgeId, 5, '2026-09-30T21:59:00Z'); // 23:59 on 30 Sep
      await order(o1Id, edgeId, 7, '2026-09-30T23:30:00Z'); // last UTC day of Sep, but 01:30 on 1 Oct locally

      const units = async (month: string) => {
        const res = await request(app).get('/sales-targets/attainment').set(auth(manager)).query({ month, skuId: edgeId });
        expect(res.status).toBe(200);
        return res.body;
      };
      const sep = await units('2026-09');
      expect(sep.skus[0].actualUnits).toBe(8);
      expect(sep.from).toBe('2026-08-31T22:00:00.000Z');
      expect(sep.to).toBe('2026-09-30T22:00:00.000Z');
      expect((await units('2026-10')).skus[0].actualUnits).toBe(7);
      expect((await units('2026-08')).skus[0].actualUnits).toBe(11);

      // The same instants read in UTC split differently — the zone is what decides:
      // 22:30Z on 31 Aug is August again, and 23:30Z on 30 Sep is September.
      await prisma.client.update({ where: { id: clientId }, data: { timezone: 'UTC' } });
      try {
        expect((await units('2026-08')).skus[0].actualUnits).toBe(14);
        expect((await units('2026-09')).skus[0].actualUnits).toBe(12);
        expect((await units('2026-10')).skus[0].actualUnits).toBe(0);
      } finally {
        await prisma.client.update({ where: { id: clientId }, data: { timezone: 'Africa/Johannesburg' } });
      }
    });

    it('requires a month', async () => {
      const res = await request(app).get('/sales-targets/attainment').set(auth(manager));
      expect(res.status).toBe(400);
    });
  });
});
