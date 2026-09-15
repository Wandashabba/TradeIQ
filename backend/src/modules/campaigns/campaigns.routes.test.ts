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
    // Orders first: the ROI tests create them, and they hold FKs to both the
    // outlets and the campaigns deleted below. Lines before orders, orders
    // before campaigns, campaigns before outlets — the FK order, not the
    // reading order.
    await prisma.orderLine.deleteMany({ where: { order: { clientId } } });
    await prisma.order.deleteMany({
      where: { clientId: { in: [clientId, otherClientId] } },
    });
    await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId } } });
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitPricing.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.campaign.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    // The ROI cross-tenant test creates its own client + campaign; sweep any
    // ROI- prefixed leftovers so the suite is re-runnable.
    await prisma.campaign.deleteMany({ where: { name: { startsWith: 'ROI-' } } });
    await prisma.client.deleteMany({ where: { name: { startsWith: 'ROI-' } } });
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
  describe('GET /:id/roi (#94)', () => {
    let roiCampaignId: string;

    beforeAll(async () => {
      // A campaign that ran through June over outlet 1, stored the way the
      // campaign form sends it: plain dates, inclusive (#324).
      const start = new Date('2026-06-01');
      const end = new Date('2026-06-30');
      const campaign = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ROI- Winter push',
          startDate: start,
          endDate: end,
          budget: 1000,
          status: 'active',
          outlets: { create: [{ outletId: outletId1 }] },
        },
      });
      roiCampaignId = campaign.id;

      // Baseline: the equal-length window immediately before (May). Counted by
      // date, because there was no campaign then to attribute to.
      await prisma.order.create({
        data: {
          clientId,
          outletId: outletId1,
          agentId,
          status: 'submitted',
          total: 2000,
          createdAt: new Date('2026-05-15T00:00:00.000Z'),
        },
      });

      // Attributed: stamped with the campaign id, as order creation now does.
      await prisma.order.create({
        data: {
          clientId,
          outletId: outletId1,
          agentId,
          campaignId: campaign.id,
          status: 'submitted',
          total: 5000,
          createdAt: new Date('2026-06-15T00:00:00.000Z'),
        },
      });

      // Cancelled, inside the campaign — must count on neither side.
      await prisma.order.create({
        data: {
          clientId,
          outletId: outletId1,
          agentId,
          campaignId: campaign.id,
          status: 'cancelled',
          total: 9999,
          createdAt: new Date('2026-06-20T00:00:00.000Z'),
        },
      });
    });

    it('measures incremental sell-in against spend', async () => {
      const res = await request(app)
        .get(`/campaigns/${roiCampaignId}/roi`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.attributedRevenue).toBe(5000);
      expect(res.body.baselineRevenue).toBe(2000);
      expect(res.body.incrementalRevenue).toBe(3000);
      expect(res.body.spend).toBe(1000);
      // (3000 - 1000) / 1000
      expect(res.body.roiPct).toBe(200);
      expect(res.body.unmeasurable).toBeNull();
    });

    it('excludes cancelled orders — 9999 of them, in this case', async () => {
      const res = await request(app)
        .get(`/campaigns/${roiCampaignId}/roi`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.body.attributedRevenue).toBe(5000);
      expect(res.body.orderCount.attributed).toBe(1);
    });

    it('reports the baseline window it actually used', async () => {
      const res = await request(app)
        .get(`/campaigns/${roiCampaignId}/roi`)
        .set('Authorization', `Bearer ${managerToken}`);

      // 1–30 Jun inclusive in the client's zone (Africa/Johannesburg, the
      // default), so the baseline is the 30 local days 2–31 May (#324).
      expect(res.body.window).toEqual({
        from: '2026-05-31T22:00:00.000Z',
        to: '2026-06-30T22:00:00.000Z',
      });
      expect(res.body.baselineWindow.to).toBe('2026-05-31T22:00:00.000Z');
      expect(res.body.baselineWindow.from).toBe('2026-05-01T22:00:00.000Z');
    });

    it('says unmeasurable rather than inventing a number when there is no budget', async () => {
      const noBudget = await prisma.campaign.create({
        data: {
          clientId,
          name: 'ROI- No budget',
          startDate: new Date('2026-06-01T00:00:00.000Z'),
          endDate: new Date('2026-07-01T00:00:00.000Z'),
          status: 'active',
          outlets: { create: [{ outletId: outletId2 }] },
        },
      });

      const res = await request(app)
        .get(`/campaigns/${noBudget.id}/roi`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.roiPct).toBeNull();
      expect(res.body.unmeasurable).toBe('no_budget');
    });

    it('404s a campaign from another client', async () => {
      const other = await prisma.client.create({
        data: { name: 'ROI- Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
      });
      const foreign = await prisma.campaign.create({
        data: {
          clientId: other.id,
          name: 'ROI- Foreign',
          startDate: new Date('2026-06-01T00:00:00.000Z'),
          endDate: new Date('2026-07-01T00:00:00.000Z'),
          status: 'active',
        },
      });

      const res = await request(app)
        .get(`/campaigns/${foreign.id}/roi`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(404);
    });

    it('forbids a field agent — spend is commercially sensitive', async () => {
      const res = await request(app)
        .get(`/campaigns/${roiCampaignId}/roi`)
        .set('Authorization', `Bearer ${agentToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe('window is inclusive local calendar days (#324)', () => {
    /** A submitted visit with a planogram score that identifies it in the rollup. */
    async function visitAt(tenantId: string, byAgent: string, outlet: string, iso: string, pct: number) {
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet,
          agentId: byAgent,
          clientId: tenantId,
          checkinTs: new Date(iso),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.visitVisibility.create({
        data: {
          visitId: visit.id,
          brandingElements: {},
          planogramCompliancePct: pct,
          facingsCount: {},
          highTrafficPass: true,
          cleanlinessScore: 3,
        },
      });
    }

    async function outletIn(tenantId: string, code: string) {
      const outlet = await prisma.outlet.create({
        data: {
          name: `CAMP-${code}`,
          code: `CAMP-${code}`,
          channelType: 'supermarket',
          lat: -26.2,
          lng: 28.0,
          territoryId: 't1',
          clientId: tenantId,
        },
      });
      return outlet.id;
    }

    async function orderAt(tenantId: string, byAgent: string, outlet: string, iso: string, total: number) {
      await prisma.order.create({
        data: {
          clientId: tenantId,
          outletId: outlet,
          agentId: byAgent,
          status: 'submitted',
          total,
          createdAt: new Date(iso),
        },
      });
    }

    describe('in SAST (the default zone)', () => {
      let campaignId: string;

      beforeAll(async () => {
        const outlets = await Promise.all(
          ['W-1', 'W-2', 'W-3', 'W-4'].map((code) => outletIn(clientId, code)),
        );

        // Created through the API with plain dates, as the campaign form sends.
        const res = await request(app)
          .post('/campaigns')
          .set('Authorization', `Bearer ${managerToken}`)
          .send({
            name: 'CAMP-Sep-2024',
            startDate: '2024-09-01',
            endDate: '2024-09-30',
            budget: 100,
            outletIds: outlets,
          });
        expect(res.status).toBe(201);
        // Stored as UTC midnight of each date.
        expect(res.body.startDate).toBe('2024-09-01T00:00:00.000Z');
        expect(res.body.endDate).toBe('2024-09-30T00:00:00.000Z');
        campaignId = res.body.id;

        const [w1, w2, w3, w4] = outlets;
        await visitAt(clientId, agentId, w1, '2024-08-31T22:30:00.000Z', 70); // 00:30, start date
        await visitAt(clientId, agentId, w2, '2024-09-30T13:00:00.000Z', 90); // 15:00, end date
        await visitAt(clientId, agentId, w3, '2024-09-30T22:30:00.000Z', 10); // 00:30, day after end
        await visitAt(clientId, agentId, w4, '2024-08-31T21:30:00.000Z', 20); // 23:30, day before start

        // Baseline is 2–31 Aug local.
        await orderAt(clientId, agentId, w1, '2024-08-31T21:30:00.000Z', 300); // 23:30 31 Aug: in
        await orderAt(clientId, agentId, w1, '2024-08-31T22:30:00.000Z', 700); // 00:30 1 Sep: out
        await orderAt(clientId, agentId, w1, '2024-08-01T21:30:00.000Z', 20); // 23:30 1 Aug: out
        await orderAt(clientId, agentId, w1, '2024-08-01T22:30:00.000Z', 5); // 00:30 2 Aug: in
      });

      it('counts visits on the start and end dates and none either side', async () => {
        const res = await request(app)
          .get(`/campaigns/${campaignId}/compliance`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.outletsTotal).toBe(4);
        expect(res.body.outletsVisited).toBe(2);
        // Only the 70 and the 90: the 10 and the 20 are outside the window.
        expect(res.body.avgPlanogramCompliancePct).toBe(80);
      });

      it('measures the baseline over the same number of local days just before', async () => {
        const res = await request(app)
          .get(`/campaigns/${campaignId}/roi`)
          .set('Authorization', `Bearer ${managerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.window).toEqual({
          from: '2024-08-31T22:00:00.000Z',
          to: '2024-09-30T22:00:00.000Z',
        });
        expect(res.body.baselineWindow).toEqual({
          from: '2024-08-01T22:00:00.000Z',
          to: '2024-08-31T22:00:00.000Z',
        });
        expect(res.body.orderCount.baseline).toBe(2);
        expect(res.body.baselineRevenue).toBe(305);
      });
    });

    describe('in America/New_York across a DST change', () => {
      let nyClientId: string;
      let nyManagerToken: string;
      let nyCampaignId: string;

      beforeAll(async () => {
        const ny = await prisma.client.create({
          data: {
            name: 'CAMP-NY-Client',
            industry: 'FMCG',
            scorecardWeights: {},
            kpiThresholds: {},
            timezone: 'America/New_York',
          },
        });
        nyClientId = ny.id;
        nyManagerToken = (await userIn(nyClientId, 'manager')).token;
        const nyAgentId = (await userIn(nyClientId, 'field_agent')).userId;
        const outlet = await outletIn(nyClientId, 'NY-1');

        // US clocks fall back on 2 Nov 2025, the campaign's last day.
        const campaign = await prisma.campaign.create({
          data: {
            clientId: nyClientId,
            name: 'CAMP-NY-Fall-Back',
            startDate: new Date('2025-10-27'),
            endDate: new Date('2025-11-02'),
            outlets: { create: [{ outletId: outlet }] },
          },
        });
        nyCampaignId = campaign.id;

        await visitAt(nyClientId, nyAgentId, outlet, '2025-11-02T20:00:00.000Z', 100); // 15:00 EST, end date
        await visitAt(nyClientId, nyAgentId, outlet, '2025-11-03T04:30:00.000Z', 60); // 23:30 EST, end date
        await visitAt(nyClientId, nyAgentId, outlet, '2025-11-03T05:30:00.000Z', 10); // 00:30 EST, 3 Nov
        await visitAt(nyClientId, nyAgentId, outlet, '2025-10-27T03:30:00.000Z', 20); // 23:30 EDT, 26 Oct
      });

      afterAll(async () => {
        await prisma.visitVisibility.deleteMany({ where: { visit: { clientId: nyClientId } } });
        await prisma.visit.deleteMany({ where: { clientId: nyClientId } });
        await prisma.campaignOutlet.deleteMany({ where: { campaign: { clientId: nyClientId } } });
        await prisma.campaign.deleteMany({ where: { clientId: nyClientId } });
        await prisma.outlet.deleteMany({ where: { clientId: nyClientId } });
        await prisma.user.deleteMany({ where: { clientId: nyClientId } });
        await prisma.client.delete({ where: { id: nyClientId } });
      });

      it('counts the whole local end date, including the hour DST adds', async () => {
        const res = await request(app)
          .get(`/campaigns/${nyCampaignId}/compliance`)
          .set('Authorization', `Bearer ${nyManagerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.outletsVisited).toBe(1);
        // The 100 and the 60 only.
        expect(res.body.avgPlanogramCompliancePct).toBe(80);
      });

      it('reports windows bounded by local midnight on each side of the change', async () => {
        const res = await request(app)
          .get(`/campaigns/${nyCampaignId}/roi`)
          .set('Authorization', `Bearer ${nyManagerToken}`);

        expect(res.status).toBe(200);
        expect(res.body.window).toEqual({
          from: '2025-10-27T04:00:00.000Z', // 00:00 EDT
          to: '2025-11-03T05:00:00.000Z', // 00:00 EST
        });
        // Seven local days before: 20–26 Oct, all EDT.
        expect(res.body.baselineWindow).toEqual({
          from: '2025-10-20T04:00:00.000Z',
          to: '2025-10-27T04:00:00.000Z',
        });
      });
    });
  });
});
