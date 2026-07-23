import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('alerts routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentToken: string;
  let managerToken: string;
  let outletId: string;
  let visitId: string;
  let otherVisitId: string;
  let outOfStockRuleId: string;
  let ackAlertId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'ALERT- Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'alert-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    const manager = await prisma.user.create({
      data: { email: 'alert-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'ALERT- Outlet',
        code: 'ALERT-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    visitId = visit.id;

    const stockSku = await prisma.sku.create({
      data: { clientId, name: 'ALERT- Stock SKU', category: 'beverage', minFacingsStandard: 4, rrp: 19.99 },
    });
    const priceSku = await prisma.sku.create({
      data: { clientId, name: 'ALERT- Price SKU', category: 'beverage', minFacingsStandard: 4, rrp: 24.99 },
    });

    // A zero-stock row (fires out_of_stock).
    await prisma.visitStock.create({
      data: {
        visitId: visit.id,
        skuId: stockSku.id,
        unitsAvailable: 0,
        lastStockinDate: new Date(),
        daysOutOfStock: 3,
        velocityAvg: 1.5,
        coverageDaysPredicted: 0,
        salesActual: 0,
        salesTarget: 100,
      },
    });
    // A high price-deviation row (fires price_deviation against default 10%).
    await prisma.visitPricing.create({
      data: {
        visitId: visit.id,
        skuId: priceSku.id,
        priceActual: 30,
        priceMaster: 24,
        deviationPct: 25,
        promoActive: false,
        promoMaterialsDetected: {},
        commsRating: 3,
      },
    });
    // A low scorecard (fires low_scorecard against default 60).
    await prisma.scorecard.create({
      data: {
        visitId: visit.id,
        dimensionScores: {},
        weightedTotal: 40,
        ratingBand: 'poor',
      },
    });

    // A second tenant, with its own visit, to prove tenant scoping on evaluate.
    const otherClient = await prisma.client.create({
      data: { name: 'ALERT- Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherAgent = await prisma.user.create({
      data: {
        email: 'alert-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'ALERT- Other Outlet',
        code: 'ALERT-002',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't2',
        clientId: otherClientId,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    otherVisitId = otherVisit.id;
  });

  afterAll(async () => {
    const ids = [clientId, otherClientId];
    await prisma.alert.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.alertRule.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.visitStock.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: ids } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.user.deleteMany({ where: { clientId: { in: ids } } });
    await prisma.client.deleteMany({ where: { id: { in: ids } } });
    await prisma.$disconnect();
  });

  it('evaluates to no alerts when the client has no active rules (201, empty)', async () => {
    const res = await request(app)
      .post('/alerts/evaluate')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId });
    expect(res.status).toBe(201);
    expect(res.body.created).toEqual([]);
  });

  it('creates an alert rule (201)', async () => {
    const res = await request(app)
      .post('/alerts/rules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'Out of stock', metric: 'out_of_stock', severity: 'high' });
    expect(res.status).toBe(201);
    expect(res.body.metric).toBe('out_of_stock');
    expect(res.body.severity).toBe('high');
    expect(res.body.active).toBe(true);
    outOfStockRuleId = res.body.id;
  });

  it('rejects an invalid metric with 400', async () => {
    const res = await request(app)
      .post('/alerts/rules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'Bogus', metric: 'sla_breach' });
    expect(res.status).toBe(400);
  });

  it('creates the price_deviation and low_scorecard rules (201)', async () => {
    const price = await request(app)
      .post('/alerts/rules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'Price deviation', metric: 'price_deviation' });
    expect(price.status).toBe(201);
    const score = await request(app)
      .post('/alerts/rules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'Low scorecard', metric: 'low_scorecard' });
    expect(score.status).toBe(201);
  });

  it("lists the client's rules, newest first (200, any role)", async () => {
    const res = await request(app).get('/alerts/rules').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(200);
    const metrics = res.body.map((r: { metric: string }) => r.metric);
    expect(metrics).toEqual(expect.arrayContaining(['out_of_stock', 'price_deviation', 'low_scorecard']));
    const created = res.body.map((r: { createdAt: string }) => new Date(r.createdAt).getTime());
    expect(created).toEqual([...created].sort((a: number, b: number) => b - a));
  });

  it('updates a rule (200)', async () => {
    const res = await request(app)
      .patch(`/alerts/rules/${outOfStockRuleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ severity: 'critical', threshold: 1 });
    expect(res.status).toBe(200);
    expect(res.body.severity).toBe('critical');
    expect(res.body.threshold).toBe(1);
    expect(res.body.active).toBe(true);
  });

  it('rejects an empty rule patch with 400', async () => {
    const res = await request(app)
      .patch(`/alerts/rules/${outOfStockRuleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it("returns 404 when patching another client's rule is impossible / unknown id", async () => {
    const res = await request(app)
      .patch(`/alerts/rules/${visitId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false });
    expect(res.status).toBe(404);
  });

  it('evaluates a visit and creates one alert per matching rule (201)', async () => {
    const res = await request(app)
      .post('/alerts/evaluate')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId });
    expect(res.status).toBe(201);
    expect(res.body.created).toHaveLength(3);
    const metrics = res.body.created.map((a: { metric: string }) => a.metric).sort();
    expect(metrics).toEqual(['low_scorecard', 'out_of_stock', 'price_deviation']);
    // out_of_stock alert carries the (patched) rule severity and the outlet.
    const oos = res.body.created.find((a: { metric: string }) => a.metric === 'out_of_stock');
    expect(oos.severity).toBe('critical');
    expect(oos.outletId).toBe(outletId);
    expect(oos.acknowledged).toBe(false);
  });

  it("returns 404 when evaluating another client's visit", async () => {
    const res = await request(app)
      .post('/alerts/evaluate')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ visitId: otherVisitId });
    expect(res.status).toBe(404);
  });

  it("lists the client's alerts and filters by acknowledged (200)", async () => {
    const all = await request(app).get('/alerts').set('Authorization', `Bearer ${agentToken}`);
    expect(all.status).toBe(200);
    expect(all.body.data.length).toBeGreaterThanOrEqual(3);
    ackAlertId = all.body.data[0].id;

    const unacked = await request(app)
      .get('/alerts')
      .query({ acknowledged: 'false' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(unacked.status).toBe(200);
    expect(
      unacked.body.data.every((a: { acknowledged: boolean }) => a.acknowledged === false),
    ).toBe(true);

    const acked = await request(app)
      .get('/alerts')
      .query({ acknowledged: 'true' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(acked.status).toBe(200);
    expect(acked.body.data).toHaveLength(0);
  });

  it('acknowledges an alert (200)', async () => {
    const res = await request(app)
      .patch(`/alerts/${ackAlertId}/ack`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.acknowledged).toBe(true);

    const acked = await request(app)
      .get('/alerts')
      .query({ acknowledged: 'true' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(acked.body.data.map((a: { id: string }) => a.id)).toContain(ackAlertId);
  });

  it("returns 404 acknowledging another client's / unknown alert", async () => {
    const res = await request(app)
      .patch(`/alerts/${visitId}/ack`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('forbids a field agent from creating rules, evaluating, or acknowledging (403)', async () => {
    const create = await request(app)
      .post('/alerts/rules')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ name: 'x', metric: 'out_of_stock' });
    expect(create.status).toBe(403);

    const evaluate = await request(app)
      .post('/alerts/evaluate')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ visitId });
    expect(evaluate.status).toBe(403);

    const ack = await request(app)
      .patch(`/alerts/${ackAlertId}/ack`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(ack.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    expect((await request(app).post('/alerts/rules').send({})).status).toBe(401);
    expect((await request(app).get('/alerts/rules')).status).toBe(401);
    expect((await request(app).get('/alerts')).status).toBe(401);
    expect((await request(app).post('/alerts/evaluate').send({ visitId })).status).toBe(401);
    expect((await request(app).patch(`/alerts/${ackAlertId}/ack`)).status).toBe(401);
  });

  describe('GET /alerts pagination', () => {
    beforeAll(async () => {
      await prisma.alert.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          metric: 'oos',
          message: `page-alert-${i}`,
          severity: 'warning',
          acknowledged: false,
          createdAt: new Date(`2026-07-20T0${i}:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/alerts')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const msgs = res.body.data.map((a: { message: string }) => a.message);
      expect(msgs.indexOf('page-alert-2')).toBeLessThan(msgs.indexOf('page-alert-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/alerts?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/alerts?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((a: { id: string }) => a.id);
      const secondIds = second.body.data.map((a: { id: string }) => a.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/alerts?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/alerts?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });
});
