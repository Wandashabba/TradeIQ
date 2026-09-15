import { prisma } from '../../lib/prisma';
import { submitVisit } from '../visits/visits.service';
import { updateTask } from '../tasks/tasks.service';
import { generateScorecard } from '../scorecards/scorecards.service';
import * as ledger from './pointsLedger';

/**
 * #124 — points are written to the ledger where they are earned: visit submit,
 * task close (and reopen), scorecard generation. Each write is idempotent and
 * best-effort: it never fails the action that earned the points.
 */
describe('points ledger write hooks (#124)', () => {
  let clientId: string;
  let agentId: string;
  let outletId: string;
  const checkinTs = new Date('2026-08-01T09:00:00.000Z');

  const newVisit = () =>
    prisma.visit.create({
      data: {
        outletId,
        agentId,
        clientId,
        checkinTs,
        checkinLat: -26.2,
        checkinLng: 28.0,
        geofencePass: true,
        status: 'in_progress',
      },
    });

  const newTask = () =>
    prisma.task.create({
      data: {
        outletId,
        findingType: 'oos',
        requiredFix: 'restock',
        priority: 'normal',
        slaDueAt: new Date('2026-08-02T00:00:00.000Z'),
        ownerId: agentId,
      },
    });

  const entriesFor = (sourceId: string) =>
    prisma.pointsLedgerEntry.findMany({ where: { sourceId } });

  beforeAll(async () => {
    const client = await prisma.client.create({
      data: { name: 'PLH-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    clientId = client.id;
    const agent = await prisma.user.create({
      data: { email: 'plh-agent@example.test', passwordHash: 'x', role: 'field_agent', clientId },
    });
    agentId = agent.id;
    const outlet = await prisma.outlet.create({
      data: {
        name: 'PLH Outlet',
        code: 'PLH-1',
        channelType: 'spaza',
        lat: -26.2,
        lng: 28.0,
        territoryId: 't1',
        clientId,
      },
    });
    outletId = outlet.id;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(async () => {
    await prisma.pointsLedgerEntry.deleteMany({ where: { clientId } });
    await prisma.task.deleteMany({ where: { outlet: { clientId } } });
    await prisma.scorecard.deleteMany({ where: { visit: { clientId } } });
    await prisma.visitCapability.deleteMany({ where: { visit: { clientId } } });
    await prisma.alert.deleteMany({ where: { clientId } });
    await prisma.visit.deleteMany({ where: { clientId } });
    await prisma.outlet.deleteMany({ where: { clientId } });
    await prisma.user.deleteMany({ where: { clientId } });
    await prisma.client.deleteMany({ where: { id: clientId } });
    await prisma.$disconnect();
  });

  it('submitVisit records +2 dated by check-in, once however often it is submitted', async () => {
    const visit = await newVisit();

    await submitVisit({ visitId: visit.id, clientId, agentId });
    await submitVisit({ visitId: visit.id, clientId, agentId });

    const rows = await entriesFor(visit.id);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      clientId,
      agentId,
      points: 2,
      reason: 'visit_submitted',
      sourceType: 'visit',
      score: null,
      occurredAt: checkinTs,
    });
  });

  it('closing a task records +5 once; a reopen removes it; closing again records it afresh', async () => {
    const task = await newTask();

    await updateTask(task.id, { status: 'in_progress' });
    expect(await entriesFor(task.id)).toHaveLength(0);

    await updateTask(task.id, { status: 'closed' });
    const [first] = await entriesFor(task.id);
    expect(first).toMatchObject({ agentId, clientId, points: 5, reason: 'task_closed' });

    // Re-closing (or verifying) a closed task adds nothing and keeps the date.
    await updateTask(task.id, { status: 'closed' });
    await updateTask(task.id, { closureVerified: true });
    const afterReclose = await entriesFor(task.id);
    expect(afterReclose).toHaveLength(1);
    expect(afterReclose[0].occurredAt).toEqual(first.occurredAt);

    await updateTask(task.id, { status: 'open' });
    expect(await entriesFor(task.id)).toHaveLength(0);

    await updateTask(task.id, { status: 'closed' });
    expect(await entriesFor(task.id)).toHaveLength(1);
  });

  it('generateScorecard records the score (0 points) and follows a regenerate', async () => {
    const visit = await newVisit();
    await prisma.visitCapability.create({
      data: { visitId: visit.id, staffHeadcountConfirmed: 2, repTrainingStatus: {}, quizScore: 80 },
    });

    const scorecard = await generateScorecard({ visitId: visit.id, clientId, agentId });
    let rows = await entriesFor(scorecard.id);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      agentId,
      points: 0,
      reason: 'scorecard',
      sourceType: 'scorecard',
      score: scorecard.weightedTotal,
      occurredAt: scorecard.createdAt,
    });

    await prisma.visitCapability.update({ where: { visitId: visit.id }, data: { quizScore: 30 } });
    const regenerated = await generateScorecard({ visitId: visit.id, clientId, agentId });
    expect(regenerated.weightedTotal).not.toBe(scorecard.weightedTotal);

    rows = await entriesFor(scorecard.id);
    expect(rows).toHaveLength(1);
    expect(rows[0].score).toBe(regenerated.weightedTotal);
  });

  it('a failed ledger write is logged and never fails the action', async () => {
    const boom = new Error('ledger unavailable');
    jest.spyOn(ledger, 'recordVisitSubmitted').mockRejectedValue(boom);
    jest.spyOn(ledger, 'recordTaskClosed').mockRejectedValue(boom);
    jest.spyOn(ledger, 'voidTaskClosed').mockRejectedValue(boom);
    jest.spyOn(ledger, 'recordScorecard').mockRejectedValue(boom);
    const logged = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    const visit = await newVisit();
    await expect(submitVisit({ visitId: visit.id, clientId, agentId })).resolves.toMatchObject({
      status: 'submitted',
    });
    const task = await newTask();
    await expect(updateTask(task.id, { status: 'closed' })).resolves.toMatchObject({
      status: 'closed',
    });
    await expect(updateTask(task.id, { status: 'open' })).resolves.toMatchObject({
      status: 'open',
    });
    await expect(
      generateScorecard({ visitId: visit.id, clientId, agentId }),
    ).resolves.toHaveProperty('weightedTotal');

    const ledgerLogs = logged.mock.calls.filter((call) =>
      String(call[0]).startsWith('Points ledger write failed'),
    );
    expect(ledgerLogs).toHaveLength(4);
    expect(ledgerLogs.every((call) => call[1] === boom)).toBe(true);
  });
});
