import { prisma } from '../../lib/prisma';
import { writeLedgerEvents, visitSubmittedEvent } from './pointsLedger';
import { backfillPointsLedger, parseResumePoint } from './pointsLedgerBackfill';

/**
 * #124 — history recorded before the ledger existed is written into it by
 * scripts/backfill-points-ledger.ts. It must be safe to re-run, to kill and
 * resume, and to run alongside the live hooks.
 */
describe('backfillPointsLedger (#124)', () => {
  const tenants: string[] = [];
  let clientId: string;
  let otherClientId: string;
  let agentId: string;
  let submittedVisitId: string;
  let inProgressVisitId: string;
  let closedTaskId: string;
  const taskCreatedAt = new Date('2026-06-10T08:00:00.000Z');
  const checkinTs = new Date('2026-06-11T09:00:00.000Z');

  const seedTenant = async (name: string) => {
    const client = await prisma.client.create({
      data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    tenants.push(client.id);
    const agent = await prisma.user.create({
      data: {
        email: `${name.toLowerCase()}-agent@example.test`,
        passwordHash: 'x',
        role: 'field_agent',
        clientId: client.id,
      },
    });
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
    const visit = (status: 'submitted' | 'in_progress') =>
      prisma.visit.create({
        data: {
          outletId: outlet.id,
          agentId: agent.id,
          clientId: client.id,
          checkinTs,
          checkinLat: -26.2,
          checkinLng: 28.0,
          geofencePass: true,
          status,
        },
      });
    return { client, agent, outlet, visit };
  };

  const entriesFor = (id: string) =>
    prisma.pointsLedgerEntry.findMany({ where: { clientId: id }, orderBy: { reason: 'asc' } });

  beforeAll(async () => {
    const a = await seedTenant('PLB-A');
    clientId = a.client.id;
    agentId = a.agent.id;
    const submitted = await a.visit('submitted');
    const inProgress = await a.visit('in_progress');
    submittedVisitId = submitted.id;
    inProgressVisitId = inProgress.id;
    // Scorecards count toward the board whatever the visit's status.
    for (const [visitId, weightedTotal] of [
      [submitted.id, 72.5],
      [inProgress.id, 40],
    ] as const) {
      await prisma.scorecard.create({
        data: {
          visitId,
          dimensionScores: {},
          weightedTotal,
          ratingBand: 'amber',
          createdAt: new Date('2026-06-11T10:00:00.000Z'),
        },
      });
    }
    const taskData = {
      outletId: a.outlet.id,
      findingType: 'oos',
      requiredFix: 'restock',
      priority: 'normal' as const,
      slaDueAt: new Date('2026-06-12T00:00:00.000Z'),
      ownerId: agentId,
      createdAt: taskCreatedAt,
    };
    closedTaskId = (await prisma.task.create({ data: { ...taskData, status: 'closed' } })).id;
    await prisma.task.create({ data: { ...taskData, status: 'open' } });

    const b = await seedTenant('PLB-B');
    otherClientId = b.client.id;
    await b.visit('submitted');
  });

  afterAll(async () => {
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.task.deleteMany({ where: { outlet: { clientId: { in: tenants } } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId: { in: tenants } } } });
    await prisma.visit.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.outlet.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.user.deleteMany({ where: { clientId: { in: tenants } } });
    await prisma.client.deleteMany({ where: { id: { in: tenants } } });
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId: { in: tenants } } });
  });

  it('writes one entry per submitted visit, closed task and scorecard, one tenant only', async () => {
    const result = await backfillPointsLedger({ clientId, batchSize: 1 });

    expect(result).toEqual({
      visits: { scanned: 1, written: 1 },
      tasks: { scanned: 1, written: 1 },
      scorecards: { scanned: 2, written: 2 },
    });

    const rows = await entriesFor(clientId);
    expect(rows).toHaveLength(4);
    const visit = rows.find((r) => r.reason === 'visit_submitted')!;
    expect(visit).toMatchObject({
      agentId,
      points: 2,
      sourceType: 'visit',
      sourceId: submittedVisitId,
      score: null,
      occurredAt: checkinTs,
    });
    expect(rows.some((r) => r.sourceId === inProgressVisitId)).toBe(false);
    // No closure timestamp on Task: dated by createdAt, the earliest possible.
    expect(rows.find((r) => r.reason === 'task_closed')).toMatchObject({
      points: 5,
      sourceType: 'task',
      sourceId: closedTaskId,
      occurredAt: taskCreatedAt,
    });
    const scores = rows
      .filter((r) => r.reason === 'scorecard')
      .map((r) => [r.points, r.score])
      .sort();
    expect(scores).toEqual([
      [0, 40],
      [0, 72.5],
    ]);

    expect(await entriesFor(otherClientId)).toHaveLength(0);
  });

  it('is idempotent: a re-run writes nothing new', async () => {
    await backfillPointsLedger({ clientId });
    const again = await backfillPointsLedger({ clientId, batchSize: 2 });

    expect(again.visits.written + again.tasks.written + again.scorecards.written).toBe(0);
    expect(again.scorecards.scanned).toBe(2);
    expect(await entriesFor(clientId)).toHaveLength(4);
  });

  it('skips events a live hook already recorded, keeping that entry as written', async () => {
    const liveDate = new Date('2026-06-11T09:00:00.000Z');
    const visit = await prisma.visit.findUniqueOrThrow({ where: { id: submittedVisitId } });
    await writeLedgerEvents([visitSubmittedEvent({ ...visit, checkinTs: liveDate })]);

    const result = await backfillPointsLedger({ clientId });

    expect(result.visits).toEqual({ scanned: 1, written: 0 });
    expect(await entriesFor(clientId)).toHaveLength(4);
  });

  it('resumes from a printed point, skipping the phases before it', async () => {
    const lines: string[] = [];
    await backfillPointsLedger({ clientId, log: (l) => lines.push(l) });
    expect(lines.some((l) => l.includes(`--resume visits:${submittedVisitId}`))).toBe(true);
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });

    const result = await backfillPointsLedger({
      clientId,
      resumeFrom: parseResumePoint('tasks:00000000-0000-0000-0000-000000000000'),
    });

    expect(result.visits).toEqual({ scanned: 0, written: 0 });
    expect(result.tasks.written).toBe(1);
    expect(result.scorecards.written).toBe(2);
    const reasons = (await entriesFor(clientId)).map((r) => r.reason);
    expect(reasons).not.toContain('visit_submitted');
  });

  it('covers every tenant when no client is given', async () => {
    await backfillPointsLedger({ batchSize: 50 });

    expect(await entriesFor(clientId)).toHaveLength(4);
    expect(await entriesFor(otherClientId)).toHaveLength(1);
  });

  it('parses --resume points and rejects malformed ones', () => {
    expect(parseResumePoint('scorecards:abc:def')).toEqual({
      phase: 'scorecards',
      afterId: 'abc:def',
    });
    expect(() => parseResumePoint('orders:abc')).toThrow('--resume');
    expect(() => parseResumePoint('visits:')).toThrow('--resume');
    expect(() => parseResumePoint('visits')).toThrow('--resume');
  });
});
