import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { mean, round2 } from '../../lib/kpiMath';
import { submitVisit } from '../visits/visits.service';
import { updateTask } from '../tasks/tasks.service';
import { generateScorecard } from '../scorecards/scorecards.service';
import { LeaderboardEntry, LeaderboardOptions, computeLeaderboard } from './gamification.service';
import { backfillPointsLedger } from './pointsLedgerBackfill';

/**
 * #124 parity: the ledger-based leaderboard must equal the board computed from
 * visits, tasks and scorecards per request, which it replaced.
 *
 * `legacyComputeLeaderboard` is that implementation, frozen verbatim (bar the
 * name) as the reference. Do not "fix" it — it is the spec being matched.
 *
 * One intended difference, pinned by its own test: the legacy board counted
 * task closures for the agent's lifetime whatever the window, because Task has
 * no closure timestamp. Ledger entries are dated, so a windowed board now counts
 * only closures in the window. Unwindowed boards, and windows containing every
 * closure, are identical.
 */
async function legacyComputeLeaderboard(
  clientId: string,
  opts: LeaderboardOptions = {},
): Promise<LeaderboardEntry[]> {
  const range =
    opts.from || opts.to
      ? { ...(opts.from ? { gte: opts.from } : {}), ...(opts.to ? { lte: opts.to } : {}) }
      : undefined;

  const agents = await prisma.user.findMany({
    where: { clientId, role: 'field_agent' },
    select: { id: true, email: true, displayName: true },
  });
  const agentIds = agents.map((a) => a.id);
  if (agentIds.length === 0) {
    return [];
  }

  const visitWhere: Prisma.VisitWhereInput = {
    clientId,
    agentId: { in: agentIds },
    status: 'submitted',
    ...(range ? { checkinTs: range } : {}),
  };
  const [visitGroups, taskGroups, scorecardRows] = await Promise.all([
    prisma.visit.groupBy({ by: ['agentId'], where: visitWhere, _count: { _all: true } }),
    prisma.task.groupBy({
      by: ['ownerId'],
      where: { ownerId: { in: agentIds }, status: 'closed', outlet: { clientId } },
      _count: { _all: true },
    }),
    prisma.scorecard.findMany({
      where: {
        visit: { clientId, agentId: { in: agentIds } },
        ...(range ? { createdAt: range } : {}),
      },
      select: { weightedTotal: true, visit: { select: { agentId: true } } },
    }),
  ]);

  const visitCount = new Map(visitGroups.map((g) => [g.agentId, g._count._all]));
  const taskCount = new Map(taskGroups.map((g) => [g.ownerId, g._count._all]));
  const scoreLists = new Map<string, number[]>();
  for (const s of scorecardRows) {
    const list = scoreLists.get(s.visit.agentId) ?? [];
    list.push(s.weightedTotal);
    scoreLists.set(s.visit.agentId, list);
  }

  const rows = agents.map((agent) => {
    const visitsSubmitted = visitCount.get(agent.id) ?? 0;
    const tasksClosed = taskCount.get(agent.id) ?? 0;
    const avgScorecard = mean(scoreLists.get(agent.id) ?? []);
    const points = round2(avgScorecard + tasksClosed * 5 + visitsSubmitted * 2);
    return {
      agentId: agent.id,
      email: agent.email,
      displayName: agent.displayName,
      visitsSubmitted,
      tasksClosed,
      avgScorecard,
      points,
    };
  });
  rows.sort((a, b) => b.points - a.points || a.email.localeCompare(b.email));
  return rows.map((row, index) => ({ ...row, rank: index + 1 }));
}

const tenants: string[] = [];

async function tenant(name: string) {
  const client = await prisma.client.create({
    data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
  });
  tenants.push(client.id);
  const outlet = await prisma.outlet.create({
    data: {
      name: `${name} outlet`,
      code: name,
      channelType: 'spaza',
      lat: -26.2,
      lng: 28.0,
      territoryId: 't1',
      clientId: client.id,
    },
  });
  const user = (email: string, role: 'field_agent' | 'manager' = 'field_agent', displayName?: string) =>
    prisma.user.create({
      data: { email, displayName, passwordHash: 'x', role, clientId: client.id },
    });
  const visit = async (
    agentId: string,
    day: string,
    status: 'submitted' | 'in_progress',
    score?: number,
  ) => {
    const at = new Date(`2026-07-${day}T09:00:00.000Z`);
    const v = await prisma.visit.create({
      data: {
        outletId: outlet.id,
        agentId,
        clientId: client.id,
        checkinTs: at,
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status,
      },
    });
    if (score !== undefined) {
      await prisma.scorecard.create({
        data: { visitId: v.id, dimensionScores: {}, weightedTotal: score, ratingBand: 'amber', createdAt: at },
      });
    }
    return v;
  };
  const task = (ownerId: string, status: 'open' | 'closed' | 'in_progress', day = '10') =>
    prisma.task.create({
      data: {
        outletId: outlet.id,
        findingType: 'oos',
        requiredFix: 'restock',
        priority: 'normal',
        slaDueAt: new Date('2026-07-20T00:00:00.000Z'),
        ownerId,
        status,
        createdAt: new Date(`2026-07-${day}T12:00:00.000Z`),
      },
    });
  return { clientId: client.id, outletId: outlet.id, user, visit, task };
}

afterAll(async () => {
  const where = { clientId: { in: tenants } };
  await prisma.pointsLedgerEntry.deleteMany({ where });
  await prisma.task.deleteMany({ where: { outlet: where } });
  await prisma.scorecard.deleteMany({ where: { visit: where } });
  await prisma.visitCapability.deleteMany({ where: { visit: where } });
  await prisma.alert.deleteMany({ where });
  await prisma.visit.deleteMany({ where });
  await prisma.outlet.deleteMany({ where });
  await prisma.user.deleteMany({ where });
  await prisma.client.deleteMany({ where: { id: { in: tenants } } });
  await prisma.$disconnect();
});

describe('ledger leaderboard parity with the computed board (#124)', () => {
  let clientId: string;

  beforeAll(async () => {
    const t = await tenant('PARITY-A');
    clientId = t.clientId;

    // b: a non-terminating mean (70, 80, 85 -> 78.33), one closed and one open task.
    const b = await t.user('par-b@example.test', 'field_agent', 'Busi Dlamini');
    await t.visit(b.id, '01', 'submitted', 70);
    await t.visit(b.id, '03', 'submitted', 80);
    await t.visit(b.id, '05', 'submitted', 85);
    await t.task(b.id, 'closed');
    await t.task(b.id, 'open');

    // a: an in-progress visit earns no visit points, but its scorecard still
    // counts toward the mean — the legacy board never filtered scorecards by
    // visit status.
    const a = await t.user('par-a@example.test');
    await t.visit(a.id, '02', 'submitted', 60.33);
    await t.visit(a.id, '04', 'in_progress', 90);
    await t.task(a.id, 'in_progress');

    // c and d tie on 62 points: email decides, c first.
    const d = await t.user('par-d@example.test');
    await t.visit(d.id, '07', 'submitted', 55);
    await t.task(d.id, 'closed');
    const c = await t.user('par-c@example.test');
    await t.visit(c.id, '06', 'submitted', 60);

    // e: no activity at all.
    await t.user('par-e@example.test');

    // A manager's closed task and visit are not on a field-agent board.
    const manager = await t.user('par-manager@example.test', 'manager');
    await t.task(manager.id, 'closed');
    await t.visit(manager.id, '03', 'submitted', 99);

    // Another tenant's activity must not leak into either board.
    const other = await tenant('PARITY-OTHER');
    const stranger = await other.user('par-stranger@example.test');
    await other.visit(stranger.id, '03', 'submitted', 100);
    await other.task(stranger.id, 'closed');

    await backfillPointsLedger({ batchSize: 3 });
  });

  it('equals the computed board with no window', async () => {
    const legacy = await legacyComputeLeaderboard(clientId);
    const ledger = await computeLeaderboard(clientId);

    expect(ledger).toEqual(legacy);
    // Guard against a vacuous pass: the fixture exercises what it claims to.
    expect(legacy.map((r) => [r.email, r.points])).toEqual([
      ['par-b@example.test', 89.33],
      // mean(60.33, 90) = 75.165 sits on a round2 boundary: 75.16 in JS doubles.
      ['par-a@example.test', 77.16],
      ['par-c@example.test', 62],
      ['par-d@example.test', 62],
      ['par-e@example.test', 0],
    ]);
  });

  it.each([
    ['a window containing every closure', '2026-07-02T00:00:00.000Z', '2026-07-12T00:00:00.000Z'],
    ['an open-ended window', '2026-07-04T00:00:00.000Z', undefined],
    ['inclusive bounds on an exact timestamp', '2026-07-05T09:00:00.000Z', '2026-07-10T12:00:00.000Z'],
  ])('equals the computed board for %s', async (_label, from, to) => {
    const opts = { from: new Date(from), ...(to ? { to: new Date(to) } : {}) };
    expect(await computeLeaderboard(clientId, opts)).toEqual(
      await legacyComputeLeaderboard(clientId, opts),
    );
  });

  it('intended difference: a window now counts only the task closures inside it', async () => {
    // Closures are dated 07-10; this window ends before them.
    const opts = {
      from: new Date('2026-07-01T00:00:00.000Z'),
      to: new Date('2026-07-05T23:59:59.000Z'),
    };
    const legacy = await legacyComputeLeaderboard(clientId, opts);
    expect(legacy.some((r) => r.tasksClosed > 0)).toBe(true);

    const expected = legacy
      // `rank` is carried along here and reassigned after the re-sort below.
      .map((row) => ({
        ...row,
        tasksClosed: 0,
        points: round2(row.points - row.tasksClosed * 5),
      }))
      .sort((x, y) => y.points - x.points || x.email.localeCompare(y.email))
      .map((row, index) => ({ ...row, rank: index + 1 }));

    expect(await computeLeaderboard(clientId, opts)).toEqual(expected);
  });
});

describe('ledger written by the live hooks matches the computed board (#124)', () => {
  it('after submits, re-submits, scorecards, closes and a reopen', async () => {
    const t = await tenant('PARITY-LIVE');
    const x = await t.user('live-x@example.test');
    const y = await t.user('live-y@example.test');

    for (const [agentId, quizScores] of [
      [x.id, [80, 55]],
      [y.id, [90]],
    ] as const) {
      for (const quizScore of quizScores) {
        const visit = await t.visit(agentId, '08', 'in_progress');
        await prisma.visitCapability.create({
          data: { visitId: visit.id, staffHeadcountConfirmed: 1, repTrainingStatus: {}, quizScore },
        });
        await submitVisit({ visitId: visit.id, clientId: t.clientId, agentId });
        await generateScorecard({ visitId: visit.id, clientId: t.clientId, agentId });
        // A re-submit and a regenerate change nothing on the board.
        await submitVisit({ visitId: visit.id, clientId: t.clientId, agentId });
        await generateScorecard({ visitId: visit.id, clientId: t.clientId, agentId });
      }
    }

    const kept = await t.task(x.id, 'open');
    const reopened = await t.task(x.id, 'open');
    const yTask = await t.task(y.id, 'open');
    await updateTask(kept.id, { status: 'closed' });
    await updateTask(reopened.id, { status: 'closed' });
    await updateTask(reopened.id, { status: 'open' });
    await updateTask(yTask.id, { status: 'closed' });
    await updateTask(yTask.id, { status: 'closed' });

    const legacy = await legacyComputeLeaderboard(t.clientId);
    expect(await computeLeaderboard(t.clientId)).toEqual(legacy);
    expect(legacy.map((r) => [r.email, r.visitsSubmitted, r.tasksClosed])).toEqual(
      expect.arrayContaining([
        ['live-x@example.test', 2, 1],
        ['live-y@example.test', 1, 1],
      ]),
    );
  });
});
