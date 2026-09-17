import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { foreignTenant, userIn, type TestUser } from '../../test-utils/tenants';
import { httpServer as app } from '../../testHttpServer';

describe('/competitor-prices (admin only, legal gate)', () => {
  let clientId: string;
  let admin: TestUser;
  let manager: TestUser;
  let skuId: string;
  const previous = process.env.COMPETITOR_PRICE_COLLECTION;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: `CPROUTES-${Date.now()}`, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    admin = await userIn(clientId, 'admin');
    manager = await userIn(clientId, 'manager');
    skuId = (
      await prisma.sku.create({
        data: { clientId, name: 'Our Cola 2L', category: 'beverages', minFacingsStandard: 1, rrp: 25 },
      })
    ).id;
  });

  afterEach(() => {
    if (previous === undefined) delete process.env.COMPETITOR_PRICE_COLLECTION;
    else process.env.COMPETITOR_PRICE_COLLECTION = previous;
  });

  it('is off by default for a new client, and the kill switch is off by default', async () => {
    delete process.env.COMPETITOR_PRICE_COLLECTION;
    const res = await request(app)
      .get('/competitor-prices/settings')
      .set('Authorization', `Bearer ${admin.token}`)
      .expect(200);
    expect(res.body).toEqual({
      enabled: false,
      approvedBy: null,
      approvedAt: null,
      killSwitch: 'off',
      active: false,
      inactiveReason: 'kill_switch',
    });
  });

  it.each([
    ['GET', '/competitor-prices/settings'],
    ['POST', '/competitor-prices/settings/enable'],
    ['POST', '/competitor-prices/settings/disable'],
    ['GET', '/competitor-prices/mappings'],
    ['POST', '/competitor-prices/mappings'],
    ['GET', '/competitor-prices/audit'],
  ])('refuses a manager: %s %s', async (method, path) => {
    const req = method === 'GET' ? request(app).get(path) : request(app).post(path).send({});
    await req.set('Authorization', `Bearer ${manager.token}`).expect(403);
  });

  it.each<[Record<string, string>, string]>([
    [{}, 'both missing'],
    [{ approvedBy: 'Legal: A. Counsel' }, 'approvedAt missing'],
    [{ approvedAt: '2026-09-01' }, 'approvedBy missing'],
    [{ approvedBy: ' ', approvedAt: '2026-09-01' }, 'approvedBy blank'],
    [{ approvedBy: 'Legal', approvedAt: 'yesterday' }, 'approvedAt not a date'],
    [{ approvedBy: 'Legal', approvedAt: '2099-01-01' }, 'approvedAt in the future'],
  ])('will not enable without both approval fields (%j — %s)', async (body) => {
    await request(app)
      .post('/competitor-prices/settings/enable')
      .set('Authorization', `Bearer ${admin.token}`)
      .send(body)
      .expect(400);
    const row = await prisma.client.findUniqueOrThrow({ where: { id: clientId } });
    expect(row.competitorPriceCollectionEnabled).toBe(false);
    expect(await prisma.competitorPriceCollectionAudit.count({ where: { clientId } })).toBe(0);
  });

  it('enables with both approvals, writes an audit row, and still reports the kill switch', async () => {
    delete process.env.COMPETITOR_PRICE_COLLECTION;
    const res = await request(app)
      .post('/competitor-prices/settings/enable')
      .set('Authorization', `Bearer ${admin.token}`)
      .send({ approvedBy: 'Legal: A. Counsel', approvedAt: '2026-09-01T09:00:00Z', note: 'ToU review ref 42' })
      .expect(200);

    expect(res.body).toMatchObject({
      enabled: true,
      approvedBy: 'Legal: A. Counsel',
      approvedAt: '2026-09-01T09:00:00.000Z',
      killSwitch: 'off',
      active: false,
      inactiveReason: 'kill_switch',
    });
    const audit = await prisma.competitorPriceCollectionAudit.findMany({ where: { clientId } });
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({
      userId: admin.userId,
      action: 'enabled',
      approvedBy: 'Legal: A. Counsel',
      note: 'ToU review ref 42',
    });

    process.env.COMPETITOR_PRICE_COLLECTION = 'on';
    const live = await request(app)
      .get('/competitor-prices/settings')
      .set('Authorization', `Bearer ${admin.token}`)
      .expect(200);
    expect(live.body).toMatchObject({ killSwitch: 'on', active: true, inactiveReason: null });
  });

  it('audit rows are append-only', async () => {
    const row = await prisma.competitorPriceCollectionAudit.findFirstOrThrow({ where: { clientId } });
    await expect(
      prisma.competitorPriceCollectionAudit.update({ where: { id: row.id }, data: { approvedBy: 'someone else' } }),
    ).rejects.toThrow(/append-only/);
  });

  it('disables, clears the approval, and audits it', async () => {
    const res = await request(app)
      .post('/competitor-prices/settings/disable')
      .set('Authorization', `Bearer ${admin.token}`)
      .send({ note: 'pausing' })
      .expect(200);
    expect(res.body).toMatchObject({ enabled: false, approvedBy: null, approvedAt: null, active: false });

    const audit = await request(app)
      .get('/competitor-prices/audit')
      .set('Authorization', `Bearer ${admin.token}`)
      .expect(200);
    expect(audit.body.items.map((i: { action: string }) => i.action)).toEqual(['disabled', 'enabled']);
  });

  it('lists retailers without the fixture-only example, stubs marked as such', async () => {
    const res = await request(app)
      .get('/competitor-prices/retailers')
      .set('Authorization', `Bearer ${admin.token}`)
      .expect(200);
    const items = res.body.items as { id: string; status: string }[];
    expect(items.map((i) => i.id)).toEqual(['checkers', 'picknpay', 'shoprite', 'makro', 'woolworths']);
    expect(new Set(items.map((i) => i.status))).toEqual(new Set(['stub']));
  });

  describe('mappings', () => {
    it('creates a mapping on the retailer’s own host, and refuses other hosts and the fixture retailer', async () => {
      const created = await request(app)
        .post('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .send({
          competitorSku: 'Fizzy Cola 2L',
          competitorBrand: 'Fizzy',
          retailer: 'checkers',
          productUrl: 'https://www.checkers.co.za/fizzy-cola-2l/p/10000001',
          packSize: '2L',
          ourSkuId: skuId,
        })
        .expect(201);
      expect(created.body).toMatchObject({ competitorSku: 'Fizzy Cola 2L', retailer: 'checkers', active: true });

      await request(app)
        .post('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ competitorSku: 'X', retailer: 'checkers', productUrl: 'https://evil.example.test/fizzy/p/1' })
        .expect(400);
      await request(app)
        .post('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ competitorSku: 'X', retailer: 'example', productUrl: 'https://shop.example.test/p/x' })
        .expect(400);
    });

    it('is tenant-scoped: another client’s admin can neither see nor change a mapping', async () => {
      const mine = await request(app)
        .post('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ competitorSku: 'Bubbly 1L', retailer: 'makro', productUrl: 'https://www.makro.co.za/bubbly/p/77' })
        .expect(201);

      const other = await foreignTenant('admin');
      try {
        const list = await request(app)
          .get('/competitor-prices/mappings')
          .set('Authorization', `Bearer ${other.token}`)
          .expect(200);
        expect(list.body.items).toEqual([]);
        await request(app)
          .patch(`/competitor-prices/mappings/${mine.body.id}`)
          .set('Authorization', `Bearer ${other.token}`)
          .send({ active: false })
          .expect(404);
        await request(app)
          .post('/competitor-prices/mappings')
          .set('Authorization', `Bearer ${other.token}`)
          .send({
            competitorSku: 'Bubbly 1L',
            retailer: 'makro',
            productUrl: 'https://www.makro.co.za/bubbly/p/78',
            ourSkuId: skuId,
          })
          .expect(400);
      } finally {
        await prisma.competitorSkuMapping.deleteMany({ where: { clientId: other.clientId } });
        await other.cleanup();
      }

      const stillActive = await prisma.competitorSkuMapping.findUniqueOrThrow({ where: { id: mine.body.id } });
      expect(stillActive.active).toBe(true);
    });

    it('deactivates rather than deletes', async () => {
      const created = await request(app)
        .post('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ competitorSku: 'Old 1L', retailer: 'woolworths', productUrl: 'https://www.woolworths.co.za/prod/old-1l/A1' })
        .expect(201);
      await request(app)
        .patch(`/competitor-prices/mappings/${created.body.id}`)
        .set('Authorization', `Bearer ${admin.token}`)
        .send({ active: false })
        .expect(200);
      const active = await request(app)
        .get('/competitor-prices/mappings')
        .set('Authorization', `Bearer ${admin.token}`)
        .expect(200);
      expect(active.body.items.map((m: { id: string }) => m.id)).not.toContain(created.body.id);
      const all = await request(app)
        .get('/competitor-prices/mappings?includeInactive=true')
        .set('Authorization', `Bearer ${admin.token}`)
        .expect(200);
      expect(all.body.items.map((m: { id: string }) => m.id)).toContain(created.body.id);
    });
  });
});
