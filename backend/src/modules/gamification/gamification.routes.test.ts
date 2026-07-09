import express from 'express';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { issueToken } from '../auth/auth.service';
import { gamificationRouter } from './gamification.routes';

// The gamification router is not mounted on the shared app in this branch
// (app.ts is owned elsewhere / parallel work in flight), so we mount it on a
// minimal local app. This keeps the suite self-contained without touching
// app.ts. Deviation from dashboard.routes.test.ts, which imports the shared app.
const app = express();
app.use(express.json());
app.use('/gamification', gamificationRouter);

describe('gamification routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerToken: string;
  let agentAId: string;
  let agentAToken: string;
  let agentBId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'GAME-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'game-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agentA = await prisma.user.create({
      data: { email: 'game-agent-a@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentAId = agentA.id;
    agentAToken = issueToken({ userId: agentA.id, role: 'field_agent', clientId });

    const agentB = await prisma.user.create({
      data: { email: 'game-agent-b@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentBId = agentB.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'GAME-Outlet 1',
        code: 'GAME-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'game-t1',
        clientId,
      },
    });

    // Agent A: two submitted visits (checkinTs 07-01 and 07-05) with scorecards
    // 80 and 90 (createdAt aligned to the visit), plus one closed task.
    const visitA1 = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agentA.id,
        clientId,
        checkinTs: new Date('2026-07-01T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    const visitA2 = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agentA.id,
        clientId,
        checkinTs: new Date('2026-07-05T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: visitA1.id,
        dimensionScores: {},
        weightedTotal: 80,
        ratingBand: 'amber',
        createdAt: new Date('2026-07-01T09:00:00.000Z'),
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: visitA2.id,
        dimensionScores: {},
        weightedTotal: 90,
        ratingBand: 'green',
        createdAt: new Date('2026-07-05T09:00:00.000Z'),
      },
    });
    await prisma.task.create({
      data: {
        outletId: outlet.id,
        findingType: 'out_of_stock',
        requiredFix: 'restock',
        priority: 'normal',
        slaDueAt: new Date('2026-07-10T09:00:00.000Z'),
        ownerId: agentA.id,
        status: 'closed',
      },
    });

    // Agent B: one submitted visit (checkinTs 07-03) with scorecard 60.
    const visitB1 = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId: agentB.id,
        clientId,
        checkinTs: new Date('2026-07-03T09:00:00.000Z'),
        checkinLat: -26.2041,
        checkinLng: 28.0473,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: visitB1.id,
        dimensionScores: {},
        weightedTotal: 60,
        ratingBand: 'amber',
        createdAt: new Date('2026-07-03T09:00:00.000Z'),
      },
    });

    // Second client with its own field agent + activity — must never leak in.
    const otherClient = await prisma.client.create({
      data: { name: 'GAME-Client B', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    otherClientId = otherClient.id;
    const otherAgent = await prisma.user.create({
      data: {
        email: 'game-agent-other@example.com',
        passwordHash: 'x',
        role: 'field_agent',
        clientId: otherClientId,
      },
    });
    const otherOutlet = await prisma.outlet.create({
      data: {
        name: 'GAME-Outlet B',
        code: 'GAME-B01',
        channelType: 'hypermarket',
        lat: -25.7,
        lng: 28.2,
        territoryId: 'game-t1',
        clientId: otherClientId,
      },
    });
    const otherVisit = await prisma.visit.create({
      data: {
        outletId: otherOutlet.id,
        agentId: otherAgent.id,
        clientId: otherClientId,
        checkinTs: new Date('2026-07-02T09:00:00.000Z'),
        checkinLat: -25.7,
        checkinLng: 28.2,
        geofencePass: true,
        status: 'submitted',
      },
    });
    await prisma.scorecard.create({
      data: {
        visitId: otherVisit.id,
        dimensionScores: {},
        weightedTotal: 99,
        ratingBand: 'green',
        createdAt: new Date('2026-07-02T09:00:00.000Z'),
      },
    });
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.task.deleteMany({ where: { outlet: { clientId: { in: clientIds } } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: clientIds } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.user.deleteMany({ where: { clientId: { in: clientIds } } });
    await prisma.client.deleteMany({ where: { id: { in: clientIds } } });
    await prisma.$disconnect();
  });

  it('ranks agents by points, scoped to the caller client', async () => {
    const res = await request(app)
      .get('/gamification/leaderboard')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    // Only the two field agents of client A — client B's agent must not leak in.
    expect(res.body).toHaveLength(2);

    // Agent A: avg(80, 90) = 85 + 1 closed task * 5 + 2 visits * 2 = 94.
    expect(res.body[0]).toEqual({
      agentId: agentAId,
      email: 'game-agent-a@example.com',
      visitsSubmitted: 2,
      tasksClosed: 1,
      avgScorecard: 85,
      points: 94,
      rank: 1,
    });
    // Agent B: 60 + 0 + 1 visit * 2 = 62.
    expect(res.body[1]).toEqual({
      agentId: agentBId,
      email: 'game-agent-b@example.com',
      visitsSubmitted: 1,
      tasksClosed: 0,
      avgScorecard: 60,
      points: 62,
      rank: 2,
    });
  });

  it('filters visits and scorecards by the from/to window', async () => {
    const res = await request(app)
      .get('/gamification/leaderboard')
      .query({ from: '2026-07-02T00:00:00.000Z', to: '2026-07-04T00:00:00.000Z' })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);

    // In [07-02, 07-04] only agent B's activity falls in window, so B leads.
    expect(res.body[0]).toMatchObject({
      agentId: agentBId,
      visitsSubmitted: 1,
      avgScorecard: 60,
      points: 62,
      rank: 1,
    });
    // Agent A has no in-window visits/scorecards; the closed task is not
    // windowed, so points = 0 + 1 * 5 + 0 = 5.
    expect(res.body[1]).toMatchObject({
      agentId: agentAId,
      visitsSubmitted: 0,
      avgScorecard: 0,
      tasksClosed: 1,
      points: 5,
      rank: 2,
    });
  });

  it('returns the caller own entry from /me', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      agentId: agentAId,
      email: 'game-agent-a@example.com',
      visitsSubmitted: 2,
      tasksClosed: 1,
      avgScorecard: 85,
      points: 94,
      rank: 1,
    });
  });

  it('returns a zeroed last-place entry from /me for a caller with no activity', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    // Manager is not a field agent, so absent from the 2-agent board -> rank 3.
    expect(res.body).toEqual({
      agentId: expect.any(String),
      email: 'game-manager@example.com',
      visitsSubmitted: 0,
      tasksClosed: 0,
      avgScorecard: 0,
      points: 0,
      rank: 3,
    });
  });

  it('rejects an unparseable date with 400', async () => {
    const res = await request(app)
      .get('/gamification/leaderboard')
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/gamification/leaderboard');
    expect(res.status).toBe(401);
  });
});
