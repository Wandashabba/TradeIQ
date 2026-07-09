import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('reports routes', () => {
  let clientId: string;
  let otherClientId: string;
  let agentToken: string;
  let managerToken: string;
  let otherManagerToken: string;
  let outletId: string;
  let recentVisitId: string;
  let visitsDefId: string;
  let otherDefId: string;

  const OLD_TS = new Date('2020-01-01T00:00:00.000Z');
  const RECENT_TS = new Date('2024-06-01T00:00:00.000Z');
  // Between the two check-ins — a `from` here keeps only the recent visit.
  const CUTOFF = '2022-01-01T00:00:00.000Z';

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'RPT Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const agent = await prisma.user.create({
      data: { email: 'rpt-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });
    const manager = await prisma.user.create({
      data: { email: 'rpt-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'RPT Outlet',
        code: 'RPT-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    const oldVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agent.id,
        clientId,
        checkinTs: OLD_TS,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'in_progress',
      },
    });
    const recentVisit = await prisma.visit.create({
      data: {
        outletId,
        agentId: agent.id,
        clientId,
        checkinTs: RECENT_TS,
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    recentVisitId = recentVisit.id;

    await prisma.scorecard.create({
      data: {
        visitId: recentVisit.id,
        dimensionScores: { availability: 80 },
        weightedTotal: 80,
        ratingBand: 'green',
      },
    });
    await prisma.task.create({
      data: {
        visitId: oldVisit.id,
        findingType: 'stockout',
        outletId,
        requiredFix: 'Restock',
        priority: 'normal',
        slaDueAt: new Date(),
        ownerId: agent.id,
      },
    });

    const visitsDef = await prisma.reportDefinition.create({
      data: { clientId, name: 'RPT-all-visits', type: 'visits', filters: {} },
    });
    visitsDefId = visitsDef.id;

    // A second tenant, with its own report definition, to prove tenant scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'RPT Other Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherManager = await prisma.user.create({
      data: {
        email: 'rpt-other-manager@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherManagerToken = issueToken({
      userId: otherManager.id,
      role: 'manager',
      clientId: otherClientId,
    });
    const otherDef = await prisma.reportDefinition.create({
      data: { clientId: otherClientId, name: 'RPT-other', type: 'orders', filters: {} },
    });
    otherDefId = otherDef.id;
  });

  afterAll(async () => {
    await prisma.reportDefinition.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.task.deleteMany({ where: { outlet: { clientId } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  it('creates a report definition for each supported type (201)', async () => {
    for (const type of ['visits', 'scorecards', 'tasks', 'orders'] as const) {
      const res = await request(app)
        .post('/reports')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ name: `RPT-def-${type}`, type, filters: { outletId } });
      expect(res.status).toBe(201);
      expect(res.body.type).toBe(type);
      expect(res.body.clientId).toBe(clientId);
    }
  });

  it('rejects an unknown report type with 400', async () => {
    const res = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'RPT-bad', type: 'bogus', filters: {} });
    expect(res.status).toBe(400);
  });

  it('rejects a missing name with 400', async () => {
    const res = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ type: 'visits', filters: {} });
    expect(res.status).toBe(400);
  });

  it('rejects missing/invalid filters with 400', async () => {
    const missing = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'RPT-nofilters', type: 'visits' });
    expect(missing.status).toBe(400);

    const nulled = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'RPT-nullfilters', type: 'visits', filters: null });
    expect(nulled.status).toBe(400);
  });

  it("lists only the caller's definitions, newest first (200)", async () => {
    const res = await request(app).get('/reports').set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    const ids = res.body.map((d: { id: string }) => d.id);
    expect(ids).toContain(visitsDefId);
    expect(ids).not.toContain(otherDefId);
    const created = res.body.map((d: { createdAt: string }) => new Date(d.createdAt).getTime());
    expect(created).toEqual([...created].sort((a: number, b: number) => b - a));
  });

  it('generates a visits report returning matching rows + rowCount (200)', async () => {
    const res = await request(app)
      .get(`/reports/${visitsDefId}/generate`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.definition.id).toBe(visitsDefId);
    expect(typeof res.body.generatedAt).toBe('string');
    expect(res.body.rowCount).toBe(2);
    expect(res.body.rows).toHaveLength(2);
    const rowIds = res.body.rows.map((r: { id: string }) => r.id);
    expect(rowIds).toContain(recentVisitId);
  });

  it('narrows the generated rows with a date filter', async () => {
    const created = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'RPT-recent-visits', type: 'visits', filters: { from: CUTOFF } });
    expect(created.status).toBe(201);

    const res = await request(app)
      .get(`/reports/${created.body.id}/generate`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.rowCount).toBe(1);
    expect(res.body.rows[0].id).toBe(recentVisitId);
  });

  it('returns CSV when ?format=csv is set', async () => {
    const res = await request(app)
      .get(`/reports/${visitsDefId}/generate`)
      .query({ format: 'csv' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    expect(res.type).toBe('text/csv');
    // Header row is the first line and carries the visit's scalar column names.
    expect(res.text.split('\n')[0]).toContain('checkinTs');
  });

  it("returns 404 generating another client's definition", async () => {
    const res = await request(app)
      .get(`/reports/${otherDefId}/generate`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it("returns 404 deleting another client's definition", async () => {
    const res = await request(app)
      .delete(`/reports/${otherDefId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);

    // Untouched under its real owner.
    const stillThere = await prisma.reportDefinition.findUnique({ where: { id: otherDefId } });
    expect(stillThere).not.toBeNull();
    expect(otherManagerToken).toBeDefined();
  });

  it('deletes a definition (204) and then it is gone', async () => {
    const created = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ name: 'RPT-throwaway', type: 'tasks', filters: {} });
    expect(created.status).toBe(201);
    const id = created.body.id as string;

    const del = await request(app).delete(`/reports/${id}`).set('Authorization', `Bearer ${managerToken}`);
    expect(del.status).toBe(204);

    const gen = await request(app)
      .get(`/reports/${id}/generate`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(gen.status).toBe(404);
  });

  it('forbids a field agent from create/generate/delete (403)', async () => {
    const created = await request(app)
      .post('/reports')
      .set('Authorization', `Bearer ${agentToken}`)
      .send({ name: 'RPT-agent', type: 'visits', filters: {} });
    expect(created.status).toBe(403);

    const generated = await request(app)
      .get(`/reports/${visitsDefId}/generate`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(generated.status).toBe(403);

    const deleted = await request(app)
      .delete(`/reports/${visitsDefId}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(deleted.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    const created = await request(app)
      .post('/reports')
      .send({ name: 'RPT-noauth', type: 'visits', filters: {} });
    expect(created.status).toBe(401);
    const listed = await request(app).get('/reports');
    expect(listed.status).toBe(401);
    const generated = await request(app).get(`/reports/${visitsDefId}/generate`);
    expect(generated.status).toBe(401);
    const deleted = await request(app).delete(`/reports/${visitsDefId}`);
    expect(deleted.status).toBe(401);
  });
});
