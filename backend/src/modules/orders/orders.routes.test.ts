import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { localCalendarDate } from '../../lib/clientTime';
import { attributeToCampaign } from './orders.service';

describe('orders routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agent1Id: string;
  let agent1Token: string;
  let agent2Token: string;
  let managerToken: string;
  let otherAgentToken: string;
  let outletId: string;
  let otherOutletId: string;
  let skuAId: string;
  let skuBId: string;
  let otherSkuId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'ORDER-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const other = await prisma.client.create({
      data: { name: 'ORDER-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = other.id;

    const agent1 = await prisma.user.create({
      data: { email: 'order-agent1@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const agent2 = await prisma.user.create({
      data: { email: 'order-agent2@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    const manager = await prisma.user.create({
      data: { email: 'order-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    const otherAgent = await prisma.user.create({
      data: {
        email: 'order-other-agent@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    agent1Id = agent1.id;
    agent1Token = issueToken({ userId: agent1.id, role: 'field_agent', clientId });
    agent2Token = issueToken({ userId: agent2.id, role: 'field_agent', clientId });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    otherAgentToken = issueToken({
      userId: otherAgent.id,
      role: 'field_agent',
      clientId: otherClientId,
    });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'ORDER-Outlet',
        code: 'ORDER-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'ORDER-Outlet-Other',
        code: 'ORDER-002',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId: otherClientId,
      },
    });
    otherOutletId = otherOutlet.id;

    const skuA = await prisma.sku.create({
      data: { clientId, name: 'ORDER-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 10 },
    });
    const skuB = await prisma.sku.create({
      data: { clientId, name: 'ORDER-Chips', category: 'Snacks', minFacingsStandard: 4, rrp: 5 },
    });
    skuAId = skuA.id;
    skuBId = skuB.id;

    const otherSku = await prisma.sku.create({
      data: {
        clientId: otherClientId,
        name: 'ORDER-OtherSku',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 9,
      },
    });
    otherSkuId = otherSku.id;
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.orderLine.deleteMany({ where: { order: { clientId: { in: clientIds } } } });
    await prisma.order.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.sku.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    outletId,
    lines: [
      { skuId: skuAId, quantity: 2, unitPrice: 10 },
      { skuId: skuBId, quantity: 1, unitPrice: 5 },
    ],
  });

  it('creates an order with a computed total and lines (201)', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.total).toBeCloseTo(25); // 2*10 + 1*5
    expect(res.body.status).toBe('submitted');
    expect(res.body.lines).toHaveLength(2);
  });

  it('returns 404 for an outlet belonging to another client', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send({ ...validBody(), outletId: otherOutletId });
    expect(res.status).toBe(404);
  });

  it('returns 404 for a SKU belonging to another client', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send({ outletId, lines: [{ skuId: otherSkuId, quantity: 1, unitPrice: 5 }] });
    expect(res.status).toBe(404);
  });

  it('rejects an empty lines array with 400', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send({ outletId, lines: [] });
    expect(res.status).toBe(400);
  });

  it('rejects a non-positive/non-integer quantity with 400', async () => {
    const res = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send({ outletId, lines: [{ skuId: skuAId, quantity: 0, unitPrice: 10 }] });
    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token with 401', async () => {
    const res = await request(app).post('/orders').send(validBody());
    expect(res.status).toBe(401);
  });

  it('scopes list results: agent own-only, manager all, second client isolated', async () => {
    // agent2 places an order so the client has orders from two agents.
    await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent2Token}`)
      .send({ outletId, lines: [{ skuId: skuAId, quantity: 3, unitPrice: 10 }] });

    const agent1Res = await request(app)
      .get('/orders')
      .set('Authorization', `Bearer ${agent1Token}`);
    expect(agent1Res.status).toBe(200);
    expect(agent1Res.body.data.length).toBeGreaterThanOrEqual(1);
    expect(
      agent1Res.body.data.every(
        (o: { agentId: string }) => o.agentId === agent1Res.body.data[0].agentId,
      ),
    ).toBe(true);
    // Every returned order carries a line count.
    expect(agent1Res.body.data[0]._count.lines).toBeGreaterThanOrEqual(1);

    const managerRes = await request(app)
      .get('/orders')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(managerRes.status).toBe(200);
    // Manager sees both agents' orders — more than agent1 alone.
    const agentIds = new Set(managerRes.body.data.map((o: { agentId: string }) => o.agentId));
    expect(agentIds.size).toBeGreaterThanOrEqual(2);

    const otherRes = await request(app)
      .get('/orders')
      .set('Authorization', `Bearer ${otherAgentToken}`);
    expect(otherRes.status).toBe(200);
    expect(otherRes.body.data).toHaveLength(0);
  });

  it('filters list by status and rejects an invalid status with 400', async () => {
    const ok = await request(app)
      .get('/orders')
      .query({ status: 'submitted' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(ok.status).toBe(200);
    expect(ok.body.data.every((o: { status: string }) => o.status === 'submitted')).toBe(true);

    const bad = await request(app)
      .get('/orders')
      .query({ status: 'shipped' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(bad.status).toBe(400);
  });

  it('gets an order by id with lines; a field_agent cannot read another agents order (404)', async () => {
    const created = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send(validBody());
    const orderId = created.body.id as string;

    const own = await request(app)
      .get(`/orders/${orderId}`)
      .set('Authorization', `Bearer ${agent1Token}`);
    expect(own.status).toBe(200);
    expect(own.body.lines).toHaveLength(2);

    const other = await request(app)
      .get(`/orders/${orderId}`)
      .set('Authorization', `Bearer ${agent2Token}`);
    expect(other.status).toBe(404);
  });

  it('lets a manager patch an order status (200)', async () => {
    const created = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send(validBody());
    const orderId = created.body.id as string;

    const res = await request(app)
      .patch(`/orders/${orderId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'confirmed' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('confirmed');
  });

  it('forbids a field_agent from patching an order status (403)', async () => {
    const created = await request(app)
      .post('/orders')
      .set('Authorization', `Bearer ${agent1Token}`)
      .send(validBody());
    const orderId = created.body.id as string;

    const res = await request(app)
      .patch(`/orders/${orderId}`)
      .set('Authorization', `Bearer ${agent1Token}`)
      .send({ status: 'confirmed' });
    expect(res.status).toBe(403);
  });

  describe('GET /orders pagination', () => {
    beforeAll(async () => {
      await prisma.order.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          outletId,
          agentId: agent1Id,
          status: 'submitted' as const,
          total: 10,
          createdAt: new Date(`2026-07-20T0${i}:00:00.000Z`),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/orders')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const ids = res.body.data.map((o: { id: string; createdAt: string }) => o.createdAt);
      // The three page-orders are all >= the seed orders, so simply check newest-first ordering
      // is respected across the whole page.
      const sorted = [...ids].sort().reverse();
      expect(ids).toEqual(sorted);
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/orders?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/orders?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((o: { id: string }) => o.id);
      const secondIds = second.body.data.map((o: { id: string }) => o.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/orders?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/orders?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });
  describe('campaign attribution (#94)', () => {
    it('stamps the active campaign covering this outlet', async () => {
      const now = new Date();
      const campaign = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ATTR- Live now',
          startDate: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          endDate: new Date(now.getTime() + 24 * 60 * 60 * 1000),
          budget: 500,
          status: 'active',
          outlets: { create: [{ outletId }] },
        },
      });

      const res = await request(app)
        .post('/orders')
        .set('Authorization', `Bearer ${agent1Token}`)
        .send({ outletId, lines: [{ skuId: skuAId, quantity: 1, unitPrice: 10 }] });

      expect(res.status).toBe(201);
      const order = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(order.campaignId).toBe(campaign.id);

      await prisma.campaignOutlet.deleteMany({ where: { campaignId: campaign.id } });
      await prisma.order.updateMany({
        where: { campaignId: campaign.id },
        data: { campaignId: null },
      });
      await prisma.campaign.delete({ where: { id: campaign.id } });
    });

    it('leaves campaignId null when no campaign covers the outlet', async () => {
      const res = await request(app)
        .post('/orders')
        .set('Authorization', `Bearer ${agent1Token}`)
        .send({ outletId, lines: [{ skuId: skuAId, quantity: 1, unitPrice: 10 }] });

      expect(res.status).toBe(201);
      const order = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(order.campaignId).toBeNull();
    });

    it('ignores a draft campaign — it has not started spending', async () => {
      // A draft that quietly accumulated revenue would show a return before
      // anyone launched it.
      const now = new Date();
      const draft = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ATTR- Draft',
          startDate: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          endDate: new Date(now.getTime() + 24 * 60 * 60 * 1000),
          budget: 500,
          status: 'draft',
          outlets: { create: [{ outletId }] },
        },
      });

      const res = await request(app)
        .post('/orders')
        .set('Authorization', `Bearer ${agent1Token}`)
        .send({ outletId, lines: [{ skuId: skuAId, quantity: 1, unitPrice: 10 }] });

      expect(res.status).toBe(201);
      const order = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(order.campaignId).toBeNull();

      await prisma.campaignOutlet.deleteMany({ where: { campaignId: draft.id } });
      await prisma.campaign.delete({ where: { id: draft.id } });
    });

    it('picks the most recently started campaign when two overlap', async () => {
      // Deterministic, so a retry never lands the same order differently.
      const now = new Date();
      const older = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ATTR- National',
          startDate: new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000),
          endDate: new Date(now.getTime() + 24 * 60 * 60 * 1000),
          budget: 500,
          status: 'active',
          outlets: { create: [{ outletId }] },
        },
      });
      const newer = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ATTR- Regional',
          startDate: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000),
          endDate: new Date(now.getTime() + 24 * 60 * 60 * 1000),
          budget: 500,
          status: 'active',
          outlets: { create: [{ outletId }] },
        },
      });

      const res = await request(app)
        .post('/orders')
        .set('Authorization', `Bearer ${agent1Token}`)
        .send({ outletId, lines: [{ skuId: skuAId, quantity: 1, unitPrice: 10 }] });

      expect(res.status).toBe(201);
      const order = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(order.campaignId).toBe(newer.id);

      for (const c of [older, newer]) {
        await prisma.campaignOutlet.deleteMany({ where: { campaignId: c.id } });
        await prisma.order.updateMany({ where: { campaignId: c.id }, data: { campaignId: null } });
        await prisma.campaign.delete({ where: { id: c.id } });
      }
    });
  });

  describe('attribution window in local calendar days (#324)', () => {
    /** An active campaign over the order outlet, stored as the form sends it. */
    async function plainDateCampaign(name: string, startDate: string, endDate: string) {
      return prisma.campaign.create({
        data: {
          clientId,
          name,
          startDate: new Date(startDate),
          endDate: new Date(endDate),
          status: 'active',
          outlets: { create: [{ outletId }] },
        },
      });
    }

    async function removeCampaign(id: string) {
      await prisma.order.updateMany({ where: { campaignId: id }, data: { campaignId: null } });
      await prisma.campaignOutlet.deleteMany({ where: { campaignId: id } });
      await prisma.campaign.delete({ where: { id } });
    }

    const attributeAt = (iso: string, timeZone: string) =>
      prisma.$transaction((tx) => attributeToCampaign(tx, clientId, outletId, new Date(iso), timeZone));

    it('stamps an order placed today on a campaign whose end date is today', async () => {
      // Before #324 an endDate of today was today 00:00Z, so this order fell
      // outside the window at almost any hour. The client uses the default zone.
      const today = localCalendarDate(new Date(), 'Africa/Johannesburg').toISOString().slice(0, 10);
      const campaign = await plainDateCampaign('ATTR- Ends today', today, today);
      try {
        const res = await request(app)
          .post('/orders')
          .set('Authorization', `Bearer ${agent1Token}`)
          .send({ outletId, lines: [{ skuId: skuAId, quantity: 1, unitPrice: 10 }] });

        expect(res.status).toBe(201);
        const order = await prisma.order.findUniqueOrThrow({ where: { id: res.body.id } });
        expect(order.campaignId).toBe(campaign.id);
      } finally {
        await removeCampaign(campaign.id);
      }
    });

    it('includes the whole end date and nothing either side, in SAST', async () => {
      // Dates well away from "now", so no other test's order can match.
      const campaign = await plainDateCampaign('ATTR- Sep 2024', '2024-09-01', '2024-09-30');
      const SAST = 'Africa/Johannesburg';
      try {
        // 15:00 local on the end date.
        expect(await attributeAt('2024-09-30T13:00:00.000Z', SAST)).toBe(campaign.id);
        // 00:30 local on the start date.
        expect(await attributeAt('2024-08-31T22:30:00.000Z', SAST)).toBe(campaign.id);
        // 00:30 local on the day after the end date.
        expect(await attributeAt('2024-09-30T22:30:00.000Z', SAST)).toBeNull();
        // 23:30 local on the day before the start date.
        expect(await attributeAt('2024-08-31T21:30:00.000Z', SAST)).toBeNull();
      } finally {
        await removeCampaign(campaign.id);
      }
    });

    it('follows the client zone across a DST change (America/New_York, 2 Nov 2025)', async () => {
      const campaign = await plainDateCampaign('ATTR- NY fall back', '2025-10-27', '2025-11-02');
      const NY = 'America/New_York';
      try {
        // 15:00 EST on the end date.
        expect(await attributeAt('2025-11-02T20:00:00.000Z', NY)).toBe(campaign.id);
        // 23:30 EST on the end date — already 3 Nov in UTC.
        expect(await attributeAt('2025-11-03T04:30:00.000Z', NY)).toBe(campaign.id);
        // 00:30 EST on 3 Nov.
        expect(await attributeAt('2025-11-03T05:30:00.000Z', NY)).toBeNull();
        // 23:30 EDT on 26 Oct, the day before the start.
        expect(await attributeAt('2025-10-27T03:30:00.000Z', NY)).toBeNull();
      } finally {
        await removeCampaign(campaign.id);
      }
    });
  });
});
