import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('visibility routes', () => {
  let clientId: string;
  let agentToken: string;
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
    managerToken = issueToken({ userId: 'vis-manager', role: 'manager', clientId });

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

  it('returns 404 for a visit belonging to another client', async () => {
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
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

  it('derives vision fields from the stub when photoUrl is provided (201)', async () => {
    const res = await request(app)
      .post('/visibility')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({
        visitId,
        photoUrl: 'https://example.com/shelf.jpg',
        templateId: 'tmpl-1',
        skuId: 'sku-1',
        highTrafficPass: true,
        // Manual brandingElements are merged with the stub result.
        brandingElements: { poster: true },
      });

    expect(res.status).toBe(201);

    // Stub returns 0..1; the service stores a 0..100 percentage.
    expect(typeof res.body.planogramCompliancePct).toBe('number');
    expect(res.body.planogramCompliancePct).toBeGreaterThanOrEqual(0);
    expect(res.body.planogramCompliancePct).toBeLessThanOrEqual(100);

    // facingsCount is { total: <int 1..6> } from countFacings.
    expect(Number.isInteger(res.body.facingsCount.total)).toBe(true);
    expect(res.body.facingsCount.total).toBeGreaterThanOrEqual(1);
    expect(res.body.facingsCount.total).toBeLessThanOrEqual(6);

    // cleanlinessScore is 1..5 from scoreCleanliness.
    expect(Number.isInteger(res.body.cleanlinessScore)).toBe(true);
    expect(res.body.cleanlinessScore).toBeGreaterThanOrEqual(1);
    expect(res.body.cleanlinessScore).toBeLessThanOrEqual(5);

    // brandingElements reflects the stub (detected 0..8 int, pass bool) merged
    // over the manual object.
    expect(res.body.brandingElements.poster).toBe(true);
    expect(Number.isInteger(res.body.brandingElements.detected)).toBe(true);
    expect(res.body.brandingElements.detected).toBeGreaterThanOrEqual(0);
    expect(res.body.brandingElements.detected).toBeLessThanOrEqual(8);
    expect(typeof res.body.brandingElements.pass).toBe('boolean');

    // highTrafficPass stays a manual field.
    expect(res.body.highTrafficPass).toBe(true);
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
    const otherToken = issueToken({ userId: 'x', role: 'field_agent', clientId: 'no-such-client' });
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
