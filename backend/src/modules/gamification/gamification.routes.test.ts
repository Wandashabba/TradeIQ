import { createServer } from 'http';
import express from 'express';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { errorHandler } from '../../middleware/errorHandler';
import { issueToken } from '../auth/auth.service';
import { gamificationRouter } from './gamification.routes';
import { backfillPointsLedger } from './pointsLedgerBackfill';

// The gamification router is mounted on a minimal local app so the suite stays
// self-contained; errorHandler turns NotFoundError/ValidationError into 404/400
// exactly as app.ts does.
const expressApp = express();
expressApp.use(express.json());
expressApp.use('/gamification', gamificationRouter);
expressApp.use(errorHandler);
// Listening once, so supertest reuses this socket instead of binding a fresh
// ephemeral port per request — see src/testHttpServer.ts (#227).
const app = createServer(expressApp).listen(0);
app.unref();

describe('gamification routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerId: string;
  let managerToken: string;
  let agentAId: string;
  let agentAToken: string;
  let agentBId: string;
  let otherAgentId: string;
  let closedTaskId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'GAME-Client A', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'game-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerId = manager.id;
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agentA = await prisma.user.create({
      data: {
        email: 'game-agent-a@example.com',
        displayName: 'Aisha Patel',
        passwordHash: 'x',
        role: 'field_agent',
        clientId,
      },
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
    // 80 and 90 (createdAt aligned to the visit), plus one task closed on 07-06
    // (backfilled closures are dated by createdAt).
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
    const closedTask = await prisma.task.create({
      data: {
        outletId: outlet.id,
        findingType: 'out_of_stock',
        requiredFix: 'restock',
        priority: 'normal',
        slaDueAt: new Date('2026-07-10T09:00:00.000Z'),
        ownerId: agentA.id,
        status: 'closed',
        createdAt: new Date('2026-07-06T09:00:00.000Z'),
      },
    });
    closedTaskId = closedTask.id;

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
    otherAgentId = otherAgent.id;
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

    // The rows above were written directly, past the live hooks — build their
    // ledger entries the way production history is.
    await backfillPointsLedger();
  });

  afterAll(async () => {
    const clientIds = [clientId, otherClientId];
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId: { in: clientIds } } });
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
    // A has a display name (#280); B was never given one, so B's is null and
    // the app falls back to the email.
    expect(res.body[0]).toEqual({
      agentId: agentAId,
      email: 'game-agent-a@example.com',
      displayName: 'Aisha Patel',
      visitsSubmitted: 2,
      tasksClosed: 1,
      avgScorecard: 85,
      scorecardsCounted: 2,
      points: 94,
      rank: 1,
    });
    // Agent B: 60 + 0 + 1 visit * 2 = 62.
    expect(res.body[1]).toEqual({
      agentId: agentBId,
      email: 'game-agent-b@example.com',
      displayName: null,
      visitsSubmitted: 1,
      tasksClosed: 0,
      avgScorecard: 60,
      scorecardsCounted: 1,
      points: 62,
      rank: 2,
    });
  });

  it('filters visits, scorecards and task closures by the from/to window', async () => {
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
    // Agent A has nothing in window. #124: the task closed on 07-06 is dated on
    // the ledger, so it no longer counts here — the computed board counted
    // closures for all time whatever the window (see gamification.parity.test.ts).
    //
    // And #398: nothing measured is not second place. A window an agent did no
    // work in is a window the board cannot rank them in, so the place is null
    // and the row still appears — the client says "not ranked in this window"
    // rather than printing a number that reads as a verdict.
    expect(res.body[1]).toMatchObject({
      agentId: agentAId,
      visitsSubmitted: 0,
      avgScorecard: 0,
      tasksClosed: 0,
      points: 0,
      rank: null,
    });
  });

  it('returns the caller own entry from /me, with how the points were earned', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(res.status).toBe(200);
    const { recentEntries, ...entry } = res.body;
    expect(entry).toEqual({
      agentId: agentAId,
      email: 'game-agent-a@example.com',
      displayName: 'Aisha Patel',
      visitsSubmitted: 2,
      tasksClosed: 1,
      avgScorecard: 85,
      scorecardsCounted: 2,
      points: 94,
      rank: 1,
    });

    // Newest first: the 07-06 closure, then 07-05's visit + scorecard, then 07-01's.
    expect(recentEntries).toHaveLength(5);
    expect(recentEntries[0]).toEqual({
      id: expect.any(String),
      points: 5,
      reason: 'task_closed',
      sourceType: 'task',
      sourceId: closedTaskId,
      score: null,
      occurredAt: '2026-07-06T09:00:00.000Z',
      outletName: 'GAME-Outlet 1',
    });
    const dates = recentEntries.map((e: { occurredAt: string }) => e.occurredAt);
    expect(dates).toEqual([...dates].sort().reverse());
    // The entries explain the number: sum of points + mean of scores = 94.
    const sum = recentEntries.reduce((s: number, e: { points: number }) => s + e.points, 0);
    const scores = recentEntries
      .filter((e: { reason: string }) => e.reason === 'scorecard')
      .map((e: { score: number }) => e.score);
    expect(sum + scores.reduce((s: number, v: number) => s + v, 0) / scores.length).toBe(94);
    expect(recentEntries.every((e: { outletName: string }) => e.outletName === 'GAME-Outlet 1')).toBe(
      true,
    );
  });

  it('windows /me recentEntries like the entry', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .query({ from: '2026-07-05T00:00:00.000Z', to: '2026-07-05T23:59:59.000Z' })
      .set('Authorization', `Bearer ${agentAToken}`);

    expect(res.status).toBe(200);
    expect(res.body.recentEntries.map((e: { reason: string }) => e.reason).sort()).toEqual([
      'scorecard',
      'visit_submitted',
    ]);
  });

  it('returns a zeroed, UNRANKED entry and no history from /me for a caller with no activity', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    // The manager is not a field agent, so they are not on the 2-agent board
    // at all. That is an absence, not a third place: this used to answer
    // `rank: 3` — a place computed as `length + 1` from a list the caller is
    // not in — and the agent app printed it as a measured figure.
    expect(res.body).toEqual({
      agentId: expect.any(String),
      email: 'game-manager@example.com',
      displayName: null,
      visitsSubmitted: 0,
      tasksClosed: 0,
      avgScorecard: 0,
      // Nobody has scored them, which is not the same as scoring them zero.
      scorecardsCounted: 0,
      points: 0,
      rank: null,
      recentEntries: [],
    });
  });

  it('never invents a place: /me is ranked for a board member and null for everyone else', async () => {
    // The failure this pins is a fabricated rank reaching a client that cannot
    // tell it from a measured one. A real row keeps a real place; a caller off
    // the board gets null and never a number one past the end.
    const [agent, manager] = await Promise.all([
      request(app).get('/gamification/me').set('Authorization', `Bearer ${agentAToken}`),
      request(app).get('/gamification/me').set('Authorization', `Bearer ${managerToken}`),
    ]);

    const board = await request(app)
      .get('/gamification/leaderboard')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(agent.body.rank).toBeGreaterThanOrEqual(1);
    expect(agent.body.rank).toBeLessThanOrEqual(board.body.length);
    expect(manager.body.rank).toBeNull();
    expect(manager.body.rank).not.toBe(board.body.length + 1);
    // And every MEASURED row of the board itself still carries a place, in an
    // unbroken run from 1 — an unranked row (#398) must not leave a hole in
    // anyone else's place.
    const places = board.body
      .filter((row: { rank: unknown }) => row.rank !== null)
      .map((row: { rank: number }) => row.rank);
    expect(places).toEqual(places.map((_: number, index: number) => index + 1));
    expect(places.length).toBeGreaterThan(0);
  });

  describe('GET /gamification/agents/:agentId/points', () => {
    it('lists one agent entries, newest first, for a manager', async () => {
      const res = await request(app)
        .get(`/gamification/agents/${agentAId}/points`)
        .set('Authorization', `Bearer ${managerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.agent).toEqual({
        agentId: agentAId,
        email: 'game-agent-a@example.com',
        displayName: 'Aisha Patel',
      });
      expect(res.body.data).toHaveLength(5);
      expect(res.body.data[0]).toMatchObject({ reason: 'task_closed', points: 5 });
      expect(res.body.nextCursor).toBeNull();
    });

    it('paginates with limit and cursor without repeating or dropping entries', async () => {
      const seen: string[] = [];
      let cursor: string | null = null;
      do {
        const res: request.Response = await request(app)
          .get(`/gamification/agents/${agentAId}/points`)
          .query({ limit: 2, ...(cursor ? { cursor } : {}) })
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(200);
        expect(res.body.data.length).toBeLessThanOrEqual(2);
        seen.push(...res.body.data.map((e: { id: string }) => e.id));
        cursor = res.body.nextCursor;
      } while (cursor);

      expect(seen).toHaveLength(5);
      expect(new Set(seen).size).toBe(5);
    });

    it('is manager/admin only', async () => {
      const res = await request(app)
        .get(`/gamification/agents/${agentAId}/points`)
        .set('Authorization', `Bearer ${agentAToken}`);
      expect(res.status).toBe(403);
    });

    it('404s for another tenant agent and for a non-agent', async () => {
      for (const id of [otherAgentId, managerId, 'no-such-user']) {
        const res = await request(app)
          .get(`/gamification/agents/${id}/points`)
          .set('Authorization', `Bearer ${managerToken}`);
        expect(res.status).toBe(404);
      }
    });

    it('rejects a bad limit or date with 400', async () => {
      const badLimit = await request(app)
        .get(`/gamification/agents/${agentAId}/points`)
        .query({ limit: '0' })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(badLimit.status).toBe(400);

      const badDate = await request(app)
        .get(`/gamification/agents/${agentAId}/points`)
        .query({ to: 'soon' })
        .set('Authorization', `Bearer ${managerToken}`);
      expect(badDate.status).toBe(400);
    });
  });

  it('rejects an unparseable date with 400', async () => {
    const res = await request(app)
      .get('/gamification/leaderboard')
      .query({ from: 'not-a-date' })
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects an unparseable /me date with 400', async () => {
    const res = await request(app)
      .get('/gamification/me')
      .query({ to: 'not-a-date' })
      .set('Authorization', `Bearer ${agentAToken}`);
    expect(res.status).toBe(400);
  });

  it('rejects requests without a bearer token', async () => {
    const res = await request(app).get('/gamification/leaderboard');
    expect(res.status).toBe(401);
  });
});

// Isolated client + single agent so the non-terminating mean is exercised
// without perturbing the ordering/length assertions above. Three scorecards
// 70/80/85 give a mean of 235/3 = 78.3333… -> round2 -> 78.33, which the
// integer-only seeds in the main block never reach.
describe('gamification leaderboard — fractional mean', () => {
  let clientId: string;
  let managerToken: string;
  let agentId: string;

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'GAME-Frac Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;

    const manager = await prisma.user.create({
      data: { email: 'game-frac-manager@example.com', passwordHash: 'x', role: 'manager', clientId },
    });
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });

    const agent = await prisma.user.create({
      data: { email: 'game-frac-agent@example.com', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;

    const outlet = await prisma.outlet.create({
      data: {
        name: 'GAME-Frac Outlet',
        code: 'GAME-FRAC-001',
        channelType: 'hypermarket',
        lat: -26.2041,
        lng: 28.0473,
        territoryId: 'game-frac-t1',
        clientId,
      },
    });

    // Three submitted visits, each with one scorecard: 70, 80, 85. No tasks.
    for (const weightedTotal of [70, 80, 85]) {
      const visit = await prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agent.id,
          clientId,
          checkinTs: new Date('2026-07-01T09:00:00.000Z'),
          checkinLat: -26.2041,
          checkinLng: 28.0473,
          geofencePass: true,
          status: 'submitted',
        },
      });
      await prisma.scorecard.create({
        data: {
          visitId: visit.id,
          dimensionScores: {},
          weightedTotal,
          ratingBand: 'amber',
          createdAt: new Date('2026-07-01T09:00:00.000Z'),
        },
      });
    }
    await backfillPointsLedger({ clientId });
  });

  afterAll(async () => {
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('round2s a non-terminating scorecard mean (235/3 -> 78.33)', async () => {
    const res = await request(app)
      .get('/gamification/leaderboard')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    // mean(70, 80, 85) = 78.3333… -> 78.33; points = 78.33 + 0*5 + 3*2 = 84.33.
    expect(res.body[0]).toEqual({
      agentId,
      email: 'game-frac-agent@example.com',
      displayName: null,
      visitsSubmitted: 3,
      tasksClosed: 0,
      avgScorecard: 78.33,
      scorecardsCounted: 3,
      points: 84.33,
      rank: 1,
    });
  });
});
