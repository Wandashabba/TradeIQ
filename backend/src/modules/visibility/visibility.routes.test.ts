import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';
import { foreignTenant, userIn } from '../../test-utils/tenants';

describe('visibility routes', () => {
  let clientId: string;
  let agentToken: string;
  let agentBToken: string;
  let managerToken: string;
  let visitId: string;
  let emptyVisitId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'Vis Test Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'vis-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    managerToken = (await userIn(clientId, 'manager')).token;

    const agentB = await prisma.user.create({
      data: { email: 'vis-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBToken = issueToken({ userId: agentB.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'Vis Outlet',
        code: 'VIS-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    const visit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    visitId = visit.id;

    // A second visit that never gets a VisitVisibility row (GET 404 case).
    const emptyVisit = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agent.id,
        clientId,
        checkinTs: new Date(),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    emptyVisitId = emptyVisit.id;
  });

  afterAll(async () => {
    await prisma.visitVisibility.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.delete({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    visitId,
    brandingElements: { poster: true, shelfStrip: false },
    planogramCompliancePct: 82.5,
    facingsCount: { total: 12 },
    highTrafficPass: true,
    cleanlinessScore: 90,
  });

  it('records visibility for a visit (201)', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.planogramCompliancePct).toBe(82.5);
    expect(res.body.highTrafficPass).toBe(true);
  });

  it('is idempotent — re-submitting upserts the same row', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ ...validBody(), cleanlinessScore: 75 });

    expect(res.status).toBe(201);
    expect(res.body.cleanlinessScore).toBe(75);

    const rows = await prisma.visitVisibility.findMany({ where: { visitId } });
    expect(rows).toHaveLength(1);
  });

  it("forbids an agent from writing visibility onto another agent's visit (404)", async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentBToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${otherToken}`)
      .send(validBody());
    expect(res.status).toBe(404);
  });

  it('rejects a missing required field with 400', async () => {
    const { planogramCompliancePct, ...rest } = validBody();
    void planogramCompliancePct;
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(rest);
    expect(res.status).toBe(400);
  });

  it('forbids a manager from recording visibility with 403', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());
    expect(res.status).toBe(403);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).post('/visibility').send(validBody());
    expect(res.status).toBe(401);
  });

  describe('the computer-vision seam (#92)', () => {
    const original = process.env.VISION_ENABLED;

    afterEach(() => {
      if (original === undefined) {
        delete process.env.VISION_ENABLED;
      } else {
        process.env.VISION_ENABLED = original;
      }
    });

    it('KEEPS the agent\'s measurements when a photo is sent while CV is off', async () => {
      // This is the whole point of the guard. The CV implementation is still
      // Math.random(); if a photo alone were enough to trigger it, a real
      // measurement taken in a store would be silently replaced by noise that
      // then feeds the scorecard, the dashboard and the perfect-store trend.
      delete process.env.VISION_ENABLED;

      const res = await request(app)
        .post('/visibility')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({
          visitId,
          photoUrl: 'https://example.com/shelf.jpg',
          highTrafficPass: true,
          brandingElements: { poster: true },
          planogramCompliancePct: 87.5,
          facingsCount: { total: 12 },
          cleanlinessScore: 4,
        });

      expect(res.status).toBe(201);
      // Exactly what the agent measured — untouched.
      expect(res.body.planogramCompliancePct).toBe(87.5);
      expect(res.body.facingsCount.total).toBe(12);
      expect(res.body.cleanlinessScore).toBe(4);
      // The stub never ran, so it contributed no branding verdict.
      expect(res.body.brandingElements.detected).toBeUndefined();
    });

    it('rejects a photo with no manual values while CV is off (400)', async () => {
      // Without this the service would write undefined into the vision columns.
      delete process.env.VISION_ENABLED;

      const res = await request(app)
        .post('/visibility')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({
          visitId,
          photoUrl: 'https://example.com/shelf.jpg',
          highTrafficPass: true,
        });

      expect(res.status).toBe(400);
    });

    it('derives the vision fields from the model only when explicitly enabled', async () => {
      process.env.VISION_ENABLED = 'true';

      const res = await request(app)
        .post('/visibility')
        .set('Authorization', `Bearer ${agentToken}`)
        .send({
          visitId,
          photoUrl: 'https://example.com/shelf.jpg',
          templateId: 'tmpl-1',
          skuId: 'sku-1',
          highTrafficPass: true,
          brandingElements: { poster: true },
        });

      expect(res.status).toBe(201);
      expect(res.body.planogramCompliancePct).toBeGreaterThanOrEqual(0);
      expect(res.body.planogramCompliancePct).toBeLessThanOrEqual(100);
      expect(Number.isInteger(res.body.facingsCount.total)).toBe(true);
      expect(Number.isInteger(res.body.cleanlinessScore)).toBe(true);
      // The stub's branding verdict is merged over the manual object.
      expect(res.body.brandingElements.poster).toBe(true);
      expect(Number.isInteger(res.body.brandingElements.detected)).toBe(true);
      expect(res.body.highTrafficPass).toBe(true);
    });
  });

  it('GET returns the visibility row for a visit (200)', async () => {
    await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());

    const res = await request(app)
      .get('/visibility')
      .query({ visitId })
      .set('Authorization', `Bearer ${agentToken}`);

    expect(res.status).toBe(200);
    expect(res.body.visitId).toBe(visitId);
    expect(res.body.planogramCompliancePct).toBe(82.5);
  });

  it('GET without visitId returns 400', async () => {
    const res = await request(app).get('/visibility').set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(400);
  });

  it('GET returns 404 for a visit belonging to another client', async () => {
    const otherToken = (await foreignTenant('field_agent')).token;
    const res = await request(app)
      .get('/visibility')
      .query({ visitId })
      .set('Authorization', `Bearer ${otherToken}`);
    expect(res.status).toBe(404);
  });

  it('GET returns 404 when the visit has no visibility row', async () => {
    const res = await request(app)
      .get('/visibility')
      .query({ visitId: emptyVisitId })
      .set('Authorization', `Bearer ${agentToken}`);
    expect(res.status).toBe(404);
  });

  it('GET rejects requests without a bearer token', async () => {
    const res = await request(app).get('/visibility').query({ visitId });
    expect(res.status).toBe(401);
  });
});
