import { randomUUID } from 'crypto';
import request from 'supertest';
import { prisma } from '../../lib/prisma';
import { addCalendarDays } from '../../lib/clientTime';
import { httpServer as app } from '../../testHttpServer';
import { issueToken } from '../auth/auth.service';
import { formatCalendarDate, localToday } from './contestRules';

const TZ = 'Africa/Johannesburg'; // UTC+2, no DST
const JULY = { startDate: '2026-07-01', endDate: '2026-07-31' };

/** A calendar date `offset` days from the client's local today. */
const dayFromToday = (offset: number) => formatCalendarDate(addCalendarDays(localToday(TZ), offset));

describe('contests routes', () => {
  let clientId: string;
  let otherClientId: string;
  let managerId: string;
  let managerToken: string;
  let adminToken: string;
  let otherManagerToken: string;
  let otherAgentToken: string;
  let agentAId: string;
  let agentAToken: string;
  let agentBId: string;
  let agentCId: string; // deactivated, earned points in July
  let agentDId: string; // deactivated, earned nothing
  let agentEId: string; // active, earned nothing
  let agentTId: string; // active, assigned to the territory
  let agentTToken: string;
  let territoryId: string;
  let otherTerritoryId: string;

  async function agent(email: string, cid: string, options: { active?: boolean; displayName?: string } = {}) {
    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: 'x',
        role: 'field_agent',
        clientId: cid,
        active: options.active ?? true,
        displayName: options.displayName ?? null,
      },
    });
    return { id: user.id, token: issueToken({ userId: user.id, role: 'field_agent', clientId: cid }) };
  }

  async function ledger(
    agentId: string,
    reason: 'visit_submitted' | 'task_closed' | 'scorecard',
    occurredAt: string | Date,
    options: { cid?: string; score?: number } = {},
  ) {
    const points = reason === 'visit_submitted' ? 2 : reason === 'task_closed' ? 5 : 0;
    const sourceType = reason === 'visit_submitted' ? 'visit' : reason === 'task_closed' ? 'task' : 'scorecard';
    await prisma.pointsLedgerEntry.create({
      data: {
        clientId: options.cid ?? clientId,
        agentId,
        points,
        reason,
        sourceType,
        sourceId: randomUUID(),
        score: reason === 'scorecard' ? (options.score ?? 0) : null,
        occurredAt: new Date(occurredAt),
      },
    });
  }

  async function createContest(body: Record<string, unknown>, token = managerToken) {
    const res = await request(app)
      .post('/contests')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'CONTEST', ...body });
    expect(res.status).toBe(201);
    return res.body as { id: string; status: string };
  }

  async function standings(id: string) {
    const res = await request(app)
      .get(`/contests/${id}/standings`)
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
    return res.body as {
      participantCount: number;
      standings: Array<{ agentId: string; rank: number; points: number; visitsSubmitted: number }>;
    };
  }

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'CONTEST-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {}, timezone: TZ },
    });
    clientId = client.id;
    const otherClient = await prisma.client.create({
      data: { name: 'CONTEST-Other', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {}, timezone: TZ },
    });
    otherClientId = otherClient.id;

    const manager = await prisma.user.create({
      data: { email: 'contest-manager@example.test', passwordHash: 'x', role: 'manager', clientId },
    });
    managerId = manager.id;
    managerToken = issueToken({ userId: manager.id, role: 'manager', clientId });
    const admin = await prisma.user.create({
      data: { email: 'contest-admin@example.test', passwordHash: 'x', role: 'admin', clientId },
    });
    adminToken = issueToken({ userId: admin.id, role: 'admin', clientId });
    const otherManager = await prisma.user.create({
      data: {
        email: 'contest-other-manager@example.test',
        passwordHash: 'x',
        role: 'manager',
        clientId: otherClientId,
      },
    });
    otherManagerToken = issueToken({ userId: otherManager.id, role: 'manager', clientId: otherClientId });

    ({ id: agentAId, token: agentAToken } = await agent('contest-a@example.test', clientId, {
      displayName: 'Aisha Patel',
    }));
    ({ id: agentBId } = await agent('contest-b@example.test', clientId));
    ({ id: agentCId } = await agent('contest-c@example.test', clientId, { active: false }));
    ({ id: agentDId } = await agent('contest-d@example.test', clientId, { active: false }));
    ({ id: agentEId } = await agent('contest-e@example.test', clientId));
    ({ id: agentTId, token: agentTToken } = await agent('contest-t@example.test', clientId));
    const otherAgent = await agent('contest-other-agent@example.test', otherClientId);
    otherAgentToken = otherAgent.token;

    const territory = await prisma.territory.create({ data: { clientId, name: 'North', code: 'CONTEST-N' } });
    territoryId = territory.id;
    const otherTerritory = await prisma.territory.create({
      data: { clientId: otherClientId, name: 'Foreign', code: 'CONTEST-F' },
    });
    otherTerritoryId = otherTerritory.id;
    await prisma.userTerritory.createMany({
      data: [
        { userId: agentTId, territoryId },
        { userId: agentBId, territoryId },
      ],
    });

    // July in Johannesburg is [2026-06-30T22:00Z, 2026-07-31T22:00Z).
    // A: +5 at 15:00 local on the last day (counts), +2 at 00:30 local the
    //    day after (does not), +2 at 00:30 local on the first day (counts) = 7.
    await ledger(agentAId, 'task_closed', '2026-07-31T13:00:00Z');
    await ledger(agentAId, 'visit_submitted', '2026-07-31T22:30:00Z');
    await ledger(agentAId, 'visit_submitted', '2026-06-30T22:30:00Z');
    // B: +2 at 23:30 local the day before (does not), +5 and a scorecard of 2
    //    inside = 7, tied with A.
    await ledger(agentBId, 'visit_submitted', '2026-06-30T21:30:00Z');
    await ledger(agentBId, 'task_closed', '2026-07-10T08:00:00Z');
    await ledger(agentBId, 'scorecard', '2026-07-10T08:00:00Z', { score: 2 });
    // C (deactivated): +2 inside.
    await ledger(agentCId, 'visit_submitted', '2026-07-15T08:00:00Z');
    // D (deactivated): only outside the window.
    await ledger(agentDId, 'task_closed', '2026-08-15T08:00:00Z');
    // Another tenant's agent, inside the window: never on this board.
    await ledger(otherAgent.id, 'task_closed', '2026-07-15T08:00:00Z', { cid: otherClientId });
    // Today, for the current-contest views.
    await ledger(agentAId, 'visit_submitted', new Date());
  });

  afterAll(async () => {
    const clients = { in: [clientId, otherClientId] };
    await prisma.contest.deleteMany({ where: { clientId: clients } });
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId: clients } });
    await prisma.userTerritory.deleteMany({ where: { territory: { clientId: clients } } });
    await prisma.territory.deleteMany({ where: { clientId: clients } });
    await prisma.user.deleteMany({ where: { clientId: clients } });
    await prisma.client.deleteMany({ where: { id: clients } });
    await prisma.$disconnect();
  });

  describe('permissions', () => {
    let contestId: string;

    beforeAll(async () => {
      contestId = (await createContest({ ...JULY, name: 'CONTEST-perm' })).id;
    });

    it.each([
      ['post', '/contests'],
      ['get', '/contests'],
      ['get', '/contests/:id'],
      ['patch', '/contests/:id'],
      ['delete', '/contests/:id'],
      ['post', '/contests/:id/cancel'],
      ['get', '/contests/:id/standings'],
    ] as const)('a field agent gets 403 on %s %s', async (method, path) => {
      const res = await request(app)[method](path.replace(':id', contestId))
        .set('Authorization', `Bearer ${agentAToken}`)
        .send({ name: 'nope', ...JULY });
      expect(res.status).toBe(403);
    });

    it('401 without a token', async () => {
      expect((await request(app).get('/contests/current')).status).toBe(401);
    });

    it('an admin can create and list', async () => {
      const created = await createContest({ ...JULY, name: 'CONTEST-admin' }, adminToken);
      const res = await request(app).get('/contests').set('Authorization', `Bearer ${adminToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.map((c: { id: string }) => c.id)).toContain(created.id);
    });
  });

  describe('create / edit validation', () => {
    it('creates with defaults and the computed status', async () => {
      const res = await request(app)
        .post('/contests')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          name: '  CONTEST-July  ',
          description: '',
          prizeDescription: 'A R500 voucher',
          ...JULY,
          eventTypes: ['scorecard', 'task_closed', 'task_closed'],
        });
      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({
        name: 'CONTEST-July',
        description: null,
        prizeDescription: 'A R500 voucher',
        startDate: '2026-07-01',
        endDate: '2026-07-31',
        territoryId: null,
        eventTypes: ['task_closed', 'scorecard'],
        createdById: managerId,
        cancelledAt: null,
        window: { from: '2026-06-30T22:00:00.000Z', to: '2026-07-31T22:00:00.000Z' },
      });
      expect(['upcoming', 'active', 'ended']).toContain(res.body.status);
    });

    it.each([
      [{ ...JULY }, 'name is required'],
      [{ name: 'x', startDate: '2026-07-31', endDate: '2026-07-01' }, 'endDate must be on or after startDate'],
      [{ name: 'x', startDate: '2026-02-30', endDate: '2026-03-01' }, 'startDate must be a calendar date (YYYY-MM-DD)'],
      [{ name: 'x', startDate: '2026-07-01T00:00:00Z', endDate: '2026-07-31' }, 'startDate must be a calendar date (YYYY-MM-DD)'],
      [{ name: 'x', ...JULY, eventTypes: ['manual'] }, 'eventTypes must be an array of: visit_submitted, task_closed, scorecard'],
      [{ name: 'x', ...JULY, prizeDescription: 5 }, 'prizeDescription must be a string or null'],
    ])('400 for %j', async (body, error) => {
      const res = await request(app).post('/contests').set('Authorization', `Bearer ${managerToken}`).send(body);
      expect(res.status).toBe(400);
      expect(res.body.error).toBe(error);
    });

    it('404 for a territory of another tenant', async () => {
      const res = await request(app)
        .post('/contests')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ name: 'x', ...JULY, territoryId: otherTerritoryId });
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('Territory not found');
    });

    it('edits fields, and checks dates against the stored ones', async () => {
      const { id } = await createContest({ ...JULY, name: 'CONTEST-edit' });

      const moved = await request(app)
        .patch(`/contests/${id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ startDate: '2026-08-01' });
      expect(moved.status).toBe(400);
      expect(moved.body.error).toBe('endDate must be on or after startDate');

      const empty = await request(app).patch(`/contests/${id}`).set('Authorization', `Bearer ${managerToken}`).send({});
      expect(empty.status).toBe(400);

      const foreign = await request(app)
        .patch(`/contests/${id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ territoryId: otherTerritoryId });
      expect(foreign.status).toBe(404);

      const ok = await request(app)
        .patch(`/contests/${id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ name: 'CONTEST-edited', endDate: '2026-07-15', territoryId, eventTypes: null });
      expect(ok.status).toBe(200);
      expect(ok.body).toMatchObject({
        name: 'CONTEST-edited',
        endDate: '2026-07-15',
        territoryId,
        territory: { id: territoryId, name: 'North', code: 'CONTEST-N' },
        eventTypes: [],
      });
    });
  });

  describe('tenant isolation', () => {
    let contestId: string;

    beforeAll(async () => {
      contestId = (await createContest({ ...JULY, name: 'CONTEST-isolated' })).id;
    });

    it.each([
      ['get', '/contests/:id'],
      ['patch', '/contests/:id'],
      ['delete', '/contests/:id'],
      ['post', '/contests/:id/cancel'],
      ['get', '/contests/:id/standings'],
    ] as const)("another tenant's manager gets 404 on %s %s", async (method, path) => {
      const res = await request(app)[method](path.replace(':id', contestId))
        .set('Authorization', `Bearer ${otherManagerToken}`)
        .send({ name: 'hijack' });
      expect(res.status).toBe(404);
    });

    it("another tenant's list and current view never include it", async () => {
      const list = await request(app).get('/contests').set('Authorization', `Bearer ${otherManagerToken}`);
      expect(list.body.data).toEqual([]);
      const current = await request(app).get('/contests/current').set('Authorization', `Bearer ${otherAgentToken}`);
      expect(current.status).toBe(200);
      expect(current.body.data).toEqual([]);
    });
  });

  describe('standings', () => {
    it('counts the local-day window, ties share a rank, and deactivated agents appear only when they earned', async () => {
      const { id } = await createContest({ ...JULY, name: 'CONTEST-all' });
      const body = await standings(id);

      expect(body.standings.map((s) => [s.agentId, s.rank, s.points])).toEqual([
        [agentAId, 1, 7],
        [agentBId, 1, 7],
        [agentCId, 3, 2],
        [agentEId, 4, 0],
        [agentTId, 4, 0],
      ]);
      expect(body.participantCount).toBe(5);
      expect(body.standings.map((s) => s.agentId)).not.toContain(agentDId);
      // The end-day 15:00 closure counted; the 00:30 next-day visit did not.
      expect(body.standings[0]).toMatchObject({
        visitsSubmitted: 1,
        tasksClosed: 1,
        displayName: 'Aisha Patel',
        email: 'contest-a@example.test',
      });
    });

    it('a one-day window keeps 15:00 local on the day and drops 00:30 local the next day', async () => {
      const { id } = await createContest({ name: 'CONTEST-last-day', startDate: '2026-07-31', endDate: '2026-07-31' });
      const a = (await standings(id)).standings.find((s) => s.agentId === agentAId)!;
      expect(a).toMatchObject({ points: 5, tasksClosed: 1, visitsSubmitted: 0 });
    });

    it('filters by event type', async () => {
      const tasks = await standings((await createContest({ ...JULY, eventTypes: ['task_closed'] })).id);
      expect(tasks.standings.map((s) => [s.agentId, s.rank, s.points])).toEqual([
        [agentAId, 1, 5],
        [agentBId, 1, 5],
        [agentEId, 3, 0],
        [agentTId, 3, 0],
      ]);

      const visits = await standings((await createContest({ ...JULY, eventTypes: ['visit_submitted'] })).id);
      const byAgent = new Map(visits.standings.map((s) => [s.agentId, s.points]));
      expect(byAgent.get(agentAId)).toBe(2);
      expect(byAgent.get(agentCId)).toBe(2);
      expect(byAgent.get(agentBId)).toBe(0);

      const scorecards = await standings((await createContest({ ...JULY, eventTypes: ['scorecard'] })).id);
      expect(scorecards.standings[0]).toMatchObject({ agentId: agentBId, rank: 1, points: 2 });
      expect(scorecards.standings.find((s) => s.agentId === agentAId)?.points).toBe(0);
    });

    it('scopes to agents assigned to the territory', async () => {
      const body = await standings((await createContest({ ...JULY, territoryId })).id);
      expect(body.standings.map((s) => [s.agentId, s.rank, s.points])).toEqual([
        [agentBId, 1, 7],
        [agentTId, 2, 0],
      ]);
    });
  });

  describe('cancel and delete', () => {
    it('cancels an active contest once, then refuses edits; a cancelled one can be deleted', async () => {
      const { id } = await createContest({ name: 'CONTEST-cancel', startDate: dayFromToday(-1), endDate: dayFromToday(1) });

      const cancel = await request(app).post(`/contests/${id}/cancel`).set('Authorization', `Bearer ${managerToken}`);
      expect(cancel.status).toBe(200);
      expect(cancel.body.status).toBe('cancelled');
      expect(cancel.body.cancelledAt).not.toBeNull();

      const again = await request(app).post(`/contests/${id}/cancel`).set('Authorization', `Bearer ${managerToken}`);
      expect(again.status).toBe(409);

      const edit = await request(app)
        .patch(`/contests/${id}`)
        .set('Authorization', `Bearer ${managerToken}`)
        .send({ name: 'revived' });
      expect(edit.status).toBe(409);

      // Managers still see it, with its full standings.
      const list = await request(app).get('/contests').set('Authorization', `Bearer ${managerToken}`);
      expect(list.body.data.find((c: { id: string }) => c.id === id)?.status).toBe('cancelled');
      expect((await standings(id)).participantCount).toBeGreaterThan(0);

      const del = await request(app).delete(`/contests/${id}`).set('Authorization', `Bearer ${managerToken}`);
      expect(del.status).toBe(204);
      const gone = await request(app).get(`/contests/${id}`).set('Authorization', `Bearer ${managerToken}`);
      expect(gone.status).toBe(404);
    });

    it('refuses to cancel an ended contest or delete an active one', async () => {
      const ended = await createContest({ ...JULY, name: 'CONTEST-ended' });
      expect(ended.status).toBe('ended');
      const cancel = await request(app)
        .post(`/contests/${ended.id}/cancel`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(cancel.status).toBe(409);

      const active = await createContest({ name: 'CONTEST-live', startDate: dayFromToday(0), endDate: dayFromToday(0) });
      const del = await request(app).delete(`/contests/${active.id}`).set('Authorization', `Bearer ${managerToken}`);
      expect(del.status).toBe(409);
    });

    it('deletes an upcoming contest', async () => {
      const upcoming = await createContest({ name: 'CONTEST-soon', startDate: dayFromToday(3), endDate: dayFromToday(4) });
      expect(upcoming.status).toBe('upcoming');
      const del = await request(app).delete(`/contests/${upcoming.id}`).set('Authorization', `Bearer ${managerToken}`);
      expect(del.status).toBe(204);
    });
  });

  describe('GET /contests/current', () => {
    const ids: Record<string, string> = {};

    beforeAll(async () => {
      ids.active = (await createContest({ name: 'CUR-active', prizeDescription: 'Airtime', startDate: dayFromToday(-2), endDate: dayFromToday(3) })).id;
      ids.territory = (await createContest({ name: 'CUR-territory', startDate: dayFromToday(-2), endDate: dayFromToday(3), territoryId })).id;
      ids.upcoming = (await createContest({ name: 'CUR-upcoming', startDate: dayFromToday(5), endDate: dayFromToday(10) })).id;
      ids.recent = (await createContest({ name: 'CUR-recent', startDate: dayFromToday(-10), endDate: dayFromToday(-5) })).id;
      ids.old = (await createContest({ name: 'CUR-old', startDate: dayFromToday(-60), endDate: dayFromToday(-31) })).id;
      ids.cancelled = (await createContest({ name: 'CUR-cancelled', startDate: dayFromToday(-2), endDate: dayFromToday(3) })).id;
      const cancel = await request(app)
        .post(`/contests/${ids.cancelled}/cancel`)
        .set('Authorization', `Bearer ${managerToken}`);
      expect(cancel.status).toBe(200);
    });

    type Current = { id: string; status: string; daysLeft: number | null; me: { agentId: string; rank: number; points: number } | null; standings: unknown[]; participantCount: number; prizeDescription: string | null };

    async function currentFor(token: string): Promise<Current[]> {
      const res = await request(app).get('/contests/current').set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      return (res.body.data as Current[]).filter((c) => Object.values(ids).includes(c.id));
    }

    it('shows an agent active then recently ended contests, never upcoming, old or cancelled ones', async () => {
      const data = await currentFor(agentAToken);
      expect(data.map((c) => c.id)).toEqual([ids.active, ids.recent]);

      const [active, recent] = data;
      expect(active).toMatchObject({ status: 'active', daysLeft: 4, prizeDescription: 'Airtime' });
      // Today's +2 visit puts A alone at the top.
      expect(active.me).toMatchObject({ agentId: agentAId, rank: 1, points: 2 });
      expect(active.participantCount).toBe(4);
      expect(recent).toMatchObject({ status: 'ended', daysLeft: null });
      expect(recent.me).toMatchObject({ agentId: agentAId, points: 0 });
    });

    it("shows a territory contest only to that territory's agents", async () => {
      expect((await currentFor(agentTToken)).map((c) => c.id)).toEqual(
        expect.arrayContaining([ids.active, ids.territory, ids.recent]),
      );
      expect((await currentFor(agentAToken)).map((c) => c.id)).not.toContain(ids.territory);
    });

    it('managers see every current contest, unranked', async () => {
      const data = await currentFor(managerToken);
      expect(data.map((c) => c.id)).toEqual(expect.arrayContaining([ids.active, ids.territory, ids.recent]));
      expect(data.map((c) => c.id)).not.toContain(ids.cancelled);
      expect(data.every((c) => c.me === null)).toBe(true);
    });
  });
});
