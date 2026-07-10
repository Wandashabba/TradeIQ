import request from 'supertest';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { app } from '../../app';
import { issueToken } from '../auth/auth.service';

describe('report-schedules routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentToken: string;
  let otherToken: string;
  let outletId: string;
  let reportDefinitionId: string;
  let otherReportDefinitionId: string;
  let scheduleId: string;
  let otherScheduleId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'SCHED-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'SCHED-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const agent = await prisma.user.create({
      data: { email: 'SCHED-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentToken = issueToken({ userId: agent.id, role: 'field_agent', clientId });

    const outlet = await prisma.outlet.create({
      data: {
        name: 'SCHED-Outlet',
        code: 'SCHED-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;

    // A couple of visits so the linked (type 'visits') report yields rows.
    await prisma.visit.createMany({
      data: [
        {
          outletId,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
        {
          outletId,
          agentId: agent.id,
          clientId,
          checkinTs: new Date(),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'in_progress',
        },
      ],
    });

    const definition = await prisma.reportDefinition.create({
      data: { clientId, name: 'SCHED-Visits Report', type: 'visits', filters: {} },
    });
    reportDefinitionId = definition.id;

    // A second tenant with its own outlet + definition + schedule, to prove scoping.
    const otherClient = await prisma.client.create({
      data: { name: 'SCHED-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherManager = await prisma.user.create({
      data: {
        email: 'SCHED-other-manager@example.com',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherToken = issueToken({ userId: otherManager.id, role: 'manager', clientId: otherClientId });
    const otherDefinition = await prisma.reportDefinition.create({
      data: { clientId: otherClientId, name: 'SCHED-Other Report', type: 'visits', filters: {} },
    });
    otherReportDefinitionId = otherDefinition.id;
    const otherSchedule = await prisma.reportSchedule.create({
      data: {
        clientId: otherClientId,
        reportDefinitionId: otherReportDefinitionId,
        cadence: 'weekly',
        recipients: ['other@example.com'] as Prisma.InputJsonValue,
      },
    });
    otherScheduleId = otherSchedule.id;
  });

  afterAll(async () => {
    await prisma.reportSchedule.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.reportDefinition.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.user.deleteMany({ where: { clientId: { in: [clientId, otherClientId] } } });
    await prisma.client.deleteMany({ where: { id: { in: [clientId, otherClientId] } } });
    await prisma.$disconnect();
  });

  const validBody = () => ({
    reportDefinitionId,
    cadence: 'daily',
    recipients: ['ops@example.com', 'lead@example.com'],
  });

  it('creates a schedule (201)', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send(validBody());

    expect(res.status).toBe(201);
    expect(res.body.reportDefinitionId).toBe(reportDefinitionId);
    expect(res.body.cadence).toBe('daily');
    expect(res.body.recipients).toEqual(['ops@example.com', 'lead@example.com']);
    expect(res.body.active).toBe(true);
    expect(res.body.lastRunAt).toBeNull();
    scheduleId = res.body.id;
  });

  it('rejects an invalid cadence with 400', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), cadence: 'monthly' });
    expect(res.status).toBe(400);
  });

  it('rejects empty recipients with 400', async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), recipients: [] });
    expect(res.status).toBe(400);
  });

  it("returns 404 when the report definition belongs to another client", async () => {
    const res = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ ...validBody(), reportDefinitionId: otherReportDefinitionId });
    expect(res.status).toBe(404);
  });

  it("lists only the caller's schedules with the definition name (200)", async () => {
    const res = await request(app)
      .get('/report-schedules')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    const ids = res.body.map((s: { id: string }) => s.id);
    expect(ids).toContain(scheduleId);
    expect(ids).not.toContain(otherScheduleId);
    const mine = res.body.find((s: { id: string }) => s.id === scheduleId);
    expect(mine.reportDefinition.name).toBe('SCHED-Visits Report');
  });

  it('patches active and cadence (200)', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ active: false, cadence: 'weekly' });
    expect(res.status).toBe(200);
    expect(res.body.active).toBe(false);
    expect(res.body.cadence).toBe('weekly');
  });

  it('rejects an empty patch body with 400', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('rejects an invalid patch cadence with 400', async () => {
    const res = await request(app)
      .patch(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send({ cadence: 'hourly' });
    expect(res.status).toBe(400);
  });

  it('runs a schedule: sets lastRunAt and returns rowCount + deliveredTo (200)', async () => {
    const res = await request(app)
      .post(`/report-schedules/${scheduleId}/run`)
      .set('Authorization', `Bearer ${managerToken}`)
      .send();

    expect(res.status).toBe(200);
    expect(res.body.schedule.lastRunAt).not.toBeNull();
    expect(typeof res.body.rowCount).toBe('number');
    expect(res.body.rowCount).toBeGreaterThanOrEqual(2);
    expect(res.body.deliveredTo).toEqual(['ops@example.com', 'lead@example.com']);

    const row = await prisma.reportSchedule.findUnique({ where: { id: scheduleId } });
    expect(row?.lastRunAt).not.toBeNull();
  });

  it("returns 404 when running another client's schedule", async () => {
    // Client B's manager cannot run client A's schedule (tenant-scoped 404).
    const res = await request(app)
      .post(`/report-schedules/${scheduleId}/run`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send();
    expect(res.status).toBe(404);
  });

  it("returns 404 when deleting another client's schedule", async () => {
    const res = await request(app)
      .delete(`/report-schedules/${otherScheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(404);
  });

  it('deletes a schedule (204) then it is gone', async () => {
    const res = await request(app)
      .delete(`/report-schedules/${scheduleId}`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(204);

    const row = await prisma.reportSchedule.findUnique({ where: { id: scheduleId } });
    expect(row).toBeNull();
  });

  it('forbids a field agent from create/run/delete (403)', async () => {
    const created = await request(app)
      .post('/report-schedules')
      .set('Authorization', `Bearer ${agentToken}`)
      .send(validBody());
    expect(created.status).toBe(403);

    const ran = await request(app)
      .post(`/report-schedules/${otherScheduleId}/run`)
      .set('Authorization', `Bearer ${agentToken}`)
      .send();
    expect(ran.status).toBe(403);

    const deleted = await request(app)
      .delete(`/report-schedules/${otherScheduleId}`)
      .set('Authorization', `Bearer ${agentToken}`);
    expect(deleted.status).toBe(403);
  });

  it('rejects requests without a bearer token (401)', async () => {
    const created = await request(app).post('/report-schedules').send(validBody());
    expect(created.status).toBe(401);
    const listed = await request(app).get('/report-schedules');
    expect(listed.status).toBe(401);
  });
});
