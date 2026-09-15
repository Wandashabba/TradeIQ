import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { httpServer as app } from '../../testHttpServer';
import { foreignTenant, userIn } from '../../test-utils/tenants';

// GET /visits/:id — the manager's visit review (#208).

const OUTLET_LAT = -26.2041;
const OUTLET_LNG = 28.0473;
// A tiny but real data URL. Its base64 body is what must never appear in the
// detail payload.
const PHOTO_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const PHOTO_DATA_URL = `data:image/png;base64,${PHOTO_BASE64}`;

describe('GET /visits/:id', () => {
  let clientId: string;
  let managerToken: string;
  let adminToken: string;
  let agentToken: string;
  let agentId: string;
  let agentEmail: string;
  let outletId: string;
  let submittedVisitId: string;
  let draftVisitId: string;
  let photoId: string;
  let foreign: Awaited<ReturnType<typeof foreignTenant>>;
  let foreignVisitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: {
        name: 'VISITDETAIL-Client-A',
        industry: 'FMCG',
        scorecardWeights: {},
        kpiThresholds: { green: 85 },
      },
    });
    clientId = client.id;

    managerToken = (await userIn(clientId, 'manager')).token;
    adminToken = (await userIn(clientId, 'admin')).token;
    const agent = await userIn(clientId, 'field_agent');
    agentToken = agent.token;
    agentId = agent.userId;
    agentEmail = agent.email;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'VISITDETAIL-Outlet',
        code: 'VD-001',
        channelType: 'supermarket',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'territory-1',
        clientId,
      },
    });
    outletId = outlet.id;

    const [cola, chips] = await Promise.all([
      prisma.sku.create({
        data: { clientId, name: 'VD Cola 330ml', category: 'bev', minFacingsStandard: 4, rrp: 12 },
      }),
      prisma.sku.create({
        data: { clientId, name: 'VD Chips 120g', category: 'snacks', minFacingsStandard: 3, rrp: 20 },
      }),
    ]);

    const checkinTs = new Date(Date.now() - 2 * 60 * 60 * 1000);
    const submitted = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs,
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        // Past the 40m edge, so the fraud engine names geofence_distance.
        checkinDistanceM: 44.5,
        status: 'submitted',
        submittedAtClient: new Date(checkinTs.getTime() + 14 * 60 * 1000),
      },
    });
    submittedVisitId = submitted.id;

    await prisma.visitStock.createMany({
      data: [
        {
          visitId: submittedVisitId,
          skuId: cola.id,
          unitsAvailable: 0,
          lastStockinDate: checkinTs,
          daysOutOfStock: 5,
          velocityAvg: 2,
          coverageDaysPredicted: 0,
        },
        {
          visitId: submittedVisitId,
          skuId: chips.id,
          unitsAvailable: 30,
          lastStockinDate: checkinTs,
          daysOutOfStock: 0,
          velocityAvg: 2,
          coverageDaysPredicted: 15,
        },
      ],
    });
    await prisma.visitVisibility.create({
      data: {
        visitId: submittedVisitId,
        brandingElements: {},
        planogramCompliancePct: 72.4,
        facingsCount: {},
        highTrafficPass: false,
        cleanlinessScore: 4,
      },
    });
    await prisma.visitPricing.create({
      data: {
        visitId: submittedVisitId,
        skuId: cola.id,
        priceActual: 15,
        priceMaster: 12,
        deviationPct: 25,
        promoActive: false,
        promoMaterialsDetected: {},
        commsRating: 3,
      },
    });
    await prisma.visitCompetitive.create({
      data: {
        visitId: submittedVisitId,
        competitorSku: 'Rival Cola',
        competitorPrice: 10.5,
        competitorPosmType: 'shelf strip',
        competitorPromoterPresent: true,
        facingsCount: 6,
        geotag: {},
      },
    });
    await prisma.visitRisk.create({
      data: { visitId: submittedVisitId, flagType: 'expired_stock', severity: 'critical', note: 'Two expired packs' },
    });
    await prisma.scorecard.create({
      data: {
        visitId: submittedVisitId,
        dimensionScores: { availability: 50, visibility: 72.4, display: 80, pricing: 75, salesCapability: 0 },
        weightedTotal: 55.48,
        ratingBand: 'red',
      },
    });
    const photo = await prisma.photo.create({
      data: {
        visitId: submittedVisitId,
        section: 'visibility',
        url: PHOTO_DATA_URL,
        gpsTag: { lat: OUTLET_LAT, lng: OUTLET_LNG },
        timestamp: new Date(checkinTs.getTime() + 5 * 60 * 1000),
      },
    });
    photoId = photo.id;

    const draft = await prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs: new Date(),
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 3,
        status: 'in_progress',
      },
    });
    draftVisitId = draft.id;

    foreign = await foreignTenant('manager');
    const foreignOutlet = await prisma.outlet.create({
      data: {
        name: 'VISITDETAIL-Foreign',
        code: 'VD-F-001',
        channelType: 'supermarket',
        lat: OUTLET_LAT,
        lng: OUTLET_LNG,
        territoryId: 'territory-1',
        clientId: foreign.clientId,
      },
    });
    const foreignVisit = await prisma.visit.create({
      data: {
        outletId: foreignOutlet.id,
        agentId: foreign.userId,
        clientId: foreign.clientId,
        checkinTs: new Date(),
        checkinLat: OUTLET_LAT,
        checkinLng: OUTLET_LNG,
        geofencePass: true,
        checkinDistanceM: 0,
        status: 'submitted',
      },
    });
    foreignVisitId = foreignVisit.id;
  });

  afterAll(async () => {
    const visitWhere = { visit: { clientId } };
    await prisma.photo.deleteMany({ where: visitWhere });
    await prisma.scorecard.deleteMany({ where: visitWhere });
    await prisma.visitRisk.deleteMany({ where: visitWhere });
    await prisma.visitCompetitive.deleteMany({ where: visitWhere });
    await prisma.visitPricing.deleteMany({ where: visitWhere });
    await prisma.visitVisibility.deleteMany({ where: visitWhere });
    await prisma.visitStock.deleteMany({ where: visitWhere });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.sku.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });

    await prisma.visit.deleteMany({ where: { clientId: foreign.clientId } });
    await prisma.outlet.deleteMany({ where: { clientId: foreign.clientId } });
    await foreign.cleanup();
  });

  const get = (id: string, token: string) =>
    request(app).get(`/visits/${id}`).set('Authorization', `Bearer ${token}`);

  it('returns the review shape for a submitted visit', async () => {
    const res = await get(submittedVisitId, managerToken);

    expect(res.status).toBe(200);
    const body = res.body;
    expect(body.id).toBe(submittedVisitId);
    expect(body.status).toBe('submitted');
    expect(body.outlet).toEqual({
      id: outletId,
      name: 'VISITDETAIL-Outlet',
      code: 'VD-001',
      channelType: 'supermarket',
    });
    expect(body.agent).toEqual({ id: agentId, email: agentEmail });
    expect(typeof body.checkinTs).toBe('string');
    expect(typeof body.submittedAtClient).toBe('string');
    expect(body.geofence).toEqual({ pass: true, distanceM: 44.5 });

    // The score, against the CLIENT's green line, with every dimension named
    // and the unmeasured one (competitive) null rather than absent or zero.
    expect(body.score.weightedTotal).toBe(55.48);
    expect(body.score.ratingBand).toBe('red');
    expect(body.score.target).toBe(85);
    expect(body.score.dimensions.map((d: { key: string }) => d.key)).toEqual([
      'availability',
      'visibility',
      'display',
      'pricing',
      'competitive',
      'salesCapability',
    ]);
    expect(body.score.dimensions[4]).toEqual({ key: 'competitive', score: null });
    expect(body.score.dimensions[5]).toEqual({ key: 'salesCapability', score: 0 });

    const section = (key: string) =>
      body.sections.find((s: { key: string }) => s.key === key);
    expect(body.sections.map((s: { key: string }) => s.key)).toEqual([
      'stock',
      'visibility',
      'pricing',
      'competitive',
      'risks',
    ]);
    expect(section('stock')).toMatchObject({ count: 2, flagged: 1, truncated: false });
    expect(section('stock').findings).toEqual([
      '1 of 2 SKUs out of stock',
      'VD Cola 330ml: out of stock, 5 days',
    ]);
    expect(section('visibility')).toMatchObject({ count: 1, flagged: 1 });
    expect(section('visibility').findings).toContain('High-traffic placement missed');
    expect(section('pricing')).toMatchObject({ count: 1, flagged: 1 });
    expect(section('pricing').findings[1]).toBe('VD Cola 330ml: 15.00 vs 12.00 (+25%)');
    expect(section('competitive')).toMatchObject({ count: 1, flagged: 1 });
    expect(section('risks')).toMatchObject({ count: 1, flagged: 1 });
    expect(section('risks').findings).toEqual(['critical: expired_stock, Two expired packs']);
    for (const s of body.sections) {
      expect(s.findings.length).toBeLessThanOrEqual(3);
    }

    expect(body.photos.total).toBe(1);
    expect(body.photos.items).toEqual([
      {
        id: photoId,
        section: 'visibility',
        timestamp: expect.any(String),
        thumbnailUrl: `/photos/${photoId}/thumbnail`,
      },
    ]);

    // The fraud engine's own verdict, not a re-implementation.
    expect(body.fraud.riskScore).toBe(20);
    expect(body.fraud.signals.map((s: { code: string }) => s.code)).toEqual(['geofence_distance']);
  });

  it('never carries photo bytes', async () => {
    const res = await get(submittedVisitId, managerToken);

    expect(res.status).toBe(200);
    const raw = JSON.stringify(res.body);
    expect(raw).not.toContain(PHOTO_BASE64);
    expect(raw).not.toContain('data:image');
    expect(res.body.photos.items[0]).not.toHaveProperty('url');
  });

  it('the advertised thumbnail URL resolves for the same manager', async () => {
    const detail = await get(submittedVisitId, managerToken);
    const res = await request(app)
      .get(detail.body.photos.items[0].thumbnailUrl)
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('image/jpeg');
  });

  it('a draft visit: no submit time, no score, empty sections, no submit-only signals', async () => {
    const res = await get(draftVisitId, adminToken);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('in_progress');
    expect(res.body.submittedAtClient).toBeNull();
    expect(res.body.score).toBeNull();
    for (const s of res.body.sections) {
      expect(s.count).toBe(0);
      expect(s.flagged).toBe(0);
      expect(s.findings).toEqual([]);
    }
    expect(res.body.photos).toEqual({ total: 0, items: [] });
    // no_capture only applies once a visit is submitted — a draft with nothing
    // captured yet is not a ghost visit.
    expect(res.body.fraud).toEqual({ riskScore: 0, signals: [] });
  });

  it("404s for another tenant's visit, without revealing it exists", async () => {
    const res = await get(foreignVisitId, managerToken);

    expect(res.status).toBe(404);
    expect(res.body.outlet).toBeUndefined();
  });

  it("404s for the foreign tenant's own manager asking for our visit", async () => {
    const res = await get(submittedVisitId, foreign.token);
    expect(res.status).toBe(404);
  });

  it('404s for an unknown id', async () => {
    const res = await get('00000000-0000-0000-0000-000000000000', managerToken);
    expect(res.status).toBe(404);
  });

  it('403s for a field agent, even on their own visit', async () => {
    const res = await get(submittedVisitId, agentToken);
    expect(res.status).toBe(403);
  });

  it('401s without a token', async () => {
    const res = await request(app).get(`/visits/${submittedVisitId}`);
    expect(res.status).toBe(401);
  });
});
