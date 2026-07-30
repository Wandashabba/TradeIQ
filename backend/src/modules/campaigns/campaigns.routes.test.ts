import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

const WINDOW_START = '2026-07-01T00:00:00.000Z';
const WINDOW_END = '2026-07-31T23:59:59.000Z';

describe('campaigns routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentId: string;
  let agentToken: string;
  let managerToken: string;
  let outletId1: string;
  let outletId2: string;
  let otherOutletId: string;
  let skuId: string;
  let baseCampaignId: string;
  let zeroCampaignId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'CAMP-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const otherClient = await prisma.client.create({
      data: { name: 'CAMP-Other-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;

    const agent = await prisma.user.create({
      data: { email: 'camp-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const outlet1 = await prisma.outlet.create({
      data: {
        name: 'CAMP-Outlet-1',
        code: 'CAMP-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId1 = outlet1.id;

    const outlet2 = await prisma.outlet.create({
      data: {
        name: 'CAMP-Outlet-2',
        code: 'CAMP-002',
        channelType: 'supermarket',
        lat: -26.1,
        lng: 28.1,
        territoryId: 't1',
        clientId,
      },
    });
    outletId2 = outlet2.id;

    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'CAMP-Other-Outlet',
        code: 'CAMP-OTHER-001',
        channelType: 'hypermarket',
        lat: -26.0,
        lng: 28.0,
        territoryId: 't9',
        clientId: otherClientId,
      },
    });
    otherOutletId = otherOutlet.id;

    const sku = await prisma.sku.create({
      data: { clientId, name: 'CAMP-Cola', category: 'Beverages', minFacingsStandard: 4, rrp: 19.99 },
    });
    skuId = sku.id;

    const baseCampaign = await prisma.campaign.create({
      data: {
        clientId,
        name: 'CAMP-Base',
        startDate: new Date(WINDOW_START),
        endDate: new Date(WINDOW_END),
        outlets: { create: [{ outletId: outletId1 }, { outletId: outletId2 }] },
      },
    });
    baseCampaignId = baseCampaign.id;

    const zeroCampaign = await prisma.campaign.create({
      data: {
        clientId,
        name: 'CAMP-Zero',
        startDate: new Date(WINDOW_START),
        endDate: new Date(WINDOW_END),
      },
    });
    zeroCampaignId = zeroCampaign.id;
  });

  afterAll(async () => {
    await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.campaign.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    name: 'CAMP-Summer-Push',
    startDate: WINDOW_START,
    endDate: WINDOW_END,
    objective: 'Lift OSA',
    budget: 50000,
  });

  it('creates a campaign with outlet links (201, status draft)', async () => {
    const res = await request(app)
      .post('/campaigns')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), outletIds: [outletId1, outletId2] });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('draft');
    expect(res.body.clientId).toBe(clientId);
    expect(res.body.outlets).toHaveLength(2);
    expect(res.body.outlets.map((o: { outletId: string }) => o.outletId).sort()).toEqual(
      [outletId1, outletId2].sort(),
    );
  });

  it('rejects a campaign referencing a cross-client outlet with 404', async () => {
    const res = await request(app)
      .post('/campaigns')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), outletIds: [outletId1, otherOutletId] });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe(`Outlet not found: ${otherOutletId}`);
  });

  it('rejects a missing name with 400', async () => {
    const res = await request(app)
      .post('/campaigns')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ startDate: WINDOW_START, endDate: WINDOW_END });
    expect(res.status).toBe(400);
  });

  it('rejects an invalid date with 400', async () => {
    const res = await request(app)
      .post('/campaigns')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), startDate: 'not-a-date' });
    expect(res.status).toBe(400);
  });

  it('forbids a field agent from creating a campaign with 403', async () => {
    const res = await request(app)
      .post('/campaigns')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects a create without a bearer token with 401', async () => {
    const res = await request(app).post('/campaigns').send(validBody());
    expect(res.status).toBe(401);
  });

  it('lists the client campaigns with a linked-outlet count (200)', async () => {
    const res = await request(app).get('/campaigns').set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.every((c: { clientId: string }) => c.clientId === clientId)).toBe(true);

    const base = res.body.data.find((c: { id: string }) => c.id === baseCampaignId);
    expect(base._count.outlets).toBe(2);
  });

  it('gets a campaign by id with its outlets (200)', async () => {
    const res = await request(app)
      .get(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(baseCampaignId);
    expect(res.body.outlets).toHaveLength(2);
  });

  it('returns 404 for a campaign belonging to another client', async () => {
    const otherToken = (await foreignTenant('manager')).token;
    const res = await request(app)
      .get(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('updates a campaign status (200)', async () => {
    const res = await request(app)
      .patch(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'active' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('active');
  });

  it('rejects an invalid status with 400', async () => {
    const res = await request(app)
      .patch(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ status: 'archived' });
    expect(res.status).toBe(400);
  });

  it('rejects an empty PATCH body with 400', async () => {
    const res = await request(app)
      .patch(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('forbids a field agent from updating a campaign with 403', async () => {
    const res = await request(app)
      .patch(`/campaigns/${baseCampaignId}`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ status: 'completed' });
    expect(res.status).toBe(403);
  });

  it('computes the compliance rollup over in-window submitted visits (200)', async () => {
    const visit = await prisma.visit.create({
      data: {
        outletId: outletId1,
        agentId,
        clientId,
        checkinTs: new Date('2026-07-10T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.visitVisibility.create({
      data: {
        visitId: visit.id,
        brandingElements: { poster: true },
        planogramCompliancePct: 80,
        facingsCount: { total: 10 },
        highTrafficPass: true,
        cleanlinessScore: 4,
      },
    });
    await prisma.visitPricing.createMany({
      data: [
        {
          visitId: visit.id,
          skuId,
          priceActual: 22,
          priceMaster: 20,
          deviationPct: 10,
          promoActive: true,
          promoMaterialsDetected: {},
          commsRating: 4,
        },
        {
          visitId: visit.id,
          skuId,
          priceActual: 16,
          priceMaster: 20,
          deviationPct: -20,
          promoActive: false,
          promoMaterialsDetected: {},
          commsRating: 3,
        },
      ],
    });

    const res = await request(app)
      .get(`/campaigns/${baseCampaignId}/compliance`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      outletsTotal: 2,
      outletsVisited: 1,
      visitCoverageRate: 50,
      avgPlanogramCompliancePct: 80,
      avgAbsPriceDeviationPct: 15,
      promoComplianceRate: 50,
    });
  });

  it('returns an all-zero rollup for a campaign with no qualifying data (200)', async () => {
    const res = await request(app)
      .get(`/campaigns/${zeroCampaignId}/compliance`)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      outletsTotal: 0,
      outletsVisited: 0,
      visitCoverageRate: 0,
      avgPlanogramCompliancePct: 0,
      avgAbsPriceDeviationPct: 0,
      promoComplianceRate: 0,
    });
  });

  it('forbids a field agent from reading compliance with 403', async () => {
    const res = await request(app)
      .get(`/campaigns/${baseCampaignId}/compliance`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(403);
  });

  it('rejects a compliance read without a bearer token with 401', async () => {
    const res = await request(app).get(`/campaigns/${baseCampaignId}/compliance`);
    expect(res.status).toBe(401);
  });

  describe('GET /campaigns pagination', () => {
    beforeAll(async () => {
      await prisma.campaign.createMany({
        data: [0, 1, 2].map((i) => ({
          clientId,
          name: `page-campaign-${i}`,
          startDate: new Date(`2026-07-2${i}T00:00:00.000Z`),
          endDate: new Date(WINDOW_END),
        })),
      });
    });

    it('returns an envelope with data and nextCursor, newest first', async () => {
      const res = await request(app)
        .get('/campaigns')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body).toHaveProperty('nextCursor');
      const names = res.body.data.map((c: { name: string }) => c.name);
      expect(names.indexOf('page-campaign-2')).toBeLessThan(names.indexOf('page-campaign-0'));
    });

    it('caps the page at limit and returns a cursor to the next page', async () => {
      const first = await request(app)
        .get('/campaigns?limit=2')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(first.status).toBe(200);
      expect(first.body.data).toHaveLength(2);
      expect(first.body.nextCursor).not.toBeNull();

      const second = await request(app)
        .get(`/campaigns?limit=2&cursor=${first.body.nextCursor}`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(second.status).toBe(200);
      const firstIds = first.body.data.map((c: { id: string }) => c.id);
      const secondIds = second.body.data.map((c: { id: string }) => c.id);
      expect(secondIds.some((id: string) => firstIds.includes(id))).toBe(false);
    });

    it('clamps limit above the max to 200', async () => {
      const res = await request(app)
        .get('/campaigns?limit=9999')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('rejects a non-positive limit with 400', async () => {
      const res = await request(app)
        .get('/campaigns?limit=0')
        .set('Authorization', `Bearer ${managerToken}`);
      expect(res.status).toBe(400);
    });
  });
});
