import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { getVisitFraud } from './fraud.service';
import { rescoreFraudScores } from './fraudRescore';

/**
 * #236 — the stored fraud score is backfilled and rescored by
 * scripts/rescore-fraud.ts. It walks every submitted visit in production, so it
 * must be safe to re-run, to kill and resume, and to run while agents submit.
 */
describe('rescoreFraudScores (#236)', () => {
  const DAY_MS = 24 * 60 * 60 * 1000;
  const daysAgo = (n: number): Date => new Date(Date.now() - n * DAY_MS);
  let clientId: string;
  let otherClientId: string;
  const ids: Record<string, string> = {};

  const seedTenant = async (name: string) => {
    const client = await prisma.client.create({
      data: { name, industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const agent = await prisma.user.create({
      data: { email: `${name}-agent@example.test`, passwordHash: 'x', role: 'field_agent', clientId: client.id },
    });
    const outlet = await prisma.outlet.create({
      data: { name, code: name, channelType: 'spaza', lat: -26.2, lng: 28.0, territoryId: 't1', clientId: client.id },
    });
    const visit = (
      days: number,
      options: { status?: 'submitted' | 'in_progress'; distanceM?: number; captured?: boolean } = {},
    ) =>
      prisma.visit
        .create({
          data: {
            outletId: outlet.id,
            agentId: agent.id,
            clientId: client.id,
            checkinTs: daysAgo(days),
            checkinLat: -26.2,
            checkinLng: 28.0,
            geofencePass: true,
            checkinDistanceM: options.distanceM ?? 5,
            status: options.status ?? 'submitted',
            ...(options.captured
              ? { capability: { create: { staffHeadcountConfirmed: 2, repTrainingStatus: {}, quizScore: 80 } } }
              : {}),
          },
        })
        .then((v) => v.id);
    return { clientId: client.id, visit };
  };

  const stored = (id: string) =>
    prisma.visit.findUniqueOrThrow({
      where: { id },
      select: { riskScore: true, fraudSignals: true, fraudScoredAt: true },
    });

  const scoredCount = () =>
    prisma.visit.count({ where: { clientId, riskScore: { not: null } } });

  beforeAll(async () => {
    const a = await seedTenant('RESCORE-A');
    clientId = a.clientId;
    // Fence edge (20) + nothing captured (30) = 50.
    ids.suspicious = await a.visit(2, { distanceM: 45 });
    // Captured, inside the fence: 0.
    ids.clean = await a.visit(3, { captured: true });
    // Nothing captured (30), and older than a --since of 30 days.
    ids.old = await a.visit(40);
    // A draft is never scored.
    ids.draft = await a.visit(1, { status: 'in_progress' });

    const b = await seedTenant('RESCORE-B');
    otherClientId = b.clientId;
    ids.otherTenant = await b.visit(2);
  });

  beforeEach(async () => {
    await prisma.visit.updateMany({
      where: { clientId: { in: [clientId, otherClientId] } },
      data: { riskScore: null, fraudSignals: Prisma.DbNull, fraudScoredAt: null },
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(async () => {
    for (const cid of [clientId, otherClientId]) {
      await prisma.visitCapability.deleteMany({ where: { visit: { clientId: cid } } });
      await prisma.visit.deleteMany({ where: { clientId: cid } });
      await prisma.outlet.deleteMany({ where: { clientId: cid } });
      await prisma.user.deleteMany({ where: { clientId: cid } });
      await prisma.client.delete({ where: { id: cid } });
    }
    await prisma.$disconnect();
  });

  it('scores every unscored submitted visit of the client, exactly as the live endpoint does', async () => {
    const result = await rescoreFraudScores({ clientId });

    expect(result).toEqual(expect.objectContaining({ scanned: 3, written: 3, kept: 0 }));
    for (const id of [ids.suspicious, ids.clean, ids.old]) {
      const [row, live] = await Promise.all([stored(id), getVisitFraud(id, clientId)]);
      expect(row.riskScore).toBe(live.riskScore);
      expect(row.fraudSignals).toEqual(live.signals);
      expect(row.fraudScoredAt!.getTime()).toBeGreaterThanOrEqual(result.startedAt.getTime());
    }
    expect((await stored(ids.suspicious)).riskScore).toBe(50);
    expect((await stored(ids.draft)).riskScore).toBeNull();
    // --client scopes the run.
    expect((await stored(ids.otherTenant)).riskScore).toBeNull();
  });

  it('is idempotent: a second default run reads nothing and rewrites nothing', async () => {
    await rescoreFraudScores({ clientId });
    const before = await stored(ids.suspicious);

    const again = await rescoreFraudScores({ clientId });

    expect(again).toEqual(expect.objectContaining({ scanned: 0, written: 0 }));
    expect(await stored(ids.suspicious)).toEqual(before);
  });

  it('walks every client when none is named', async () => {
    await rescoreFraudScores({});

    expect((await stored(ids.otherTenant)).riskScore).toBe(30);
    expect(await scoredCount()).toBe(3);
  });

  it('limits the run to visits checked in at or after --since', async () => {
    const result = await rescoreFraudScores({ clientId, since: daysAgo(30) });

    expect(result.written).toBe(2);
    expect((await stored(ids.old)).riskScore).toBeNull();
  });

  it('leaves already-scored visits alone by default, and rescores them with --all', async () => {
    await rescoreFraudScores({ clientId });
    // A score from before a threshold change, say.
    await prisma.visit.update({
      where: { id: ids.clean },
      data: { riskScore: 99, fraudScoredAt: daysAgo(1) },
    });

    await rescoreFraudScores({ clientId });
    expect((await stored(ids.clean)).riskScore).toBe(99);

    const result = await rescoreFraudScores({ clientId, all: true });
    expect(result).toEqual(expect.objectContaining({ scanned: 3, written: 3 }));
    expect((await stored(ids.clean)).riskScore).toBe(0);
  });

  it('works in batches, and a stopped default run resumes where it left off', async () => {
    const commit = prisma.$transaction.bind(prisma);
    jest
      .spyOn(prisma, '$transaction')
      .mockImplementationOnce(((queries: Prisma.PrismaPromise<unknown>[]) => commit(queries)) as never)
      .mockImplementationOnce((() => Promise.reject(new Error('killed'))) as never);

    await expect(rescoreFraudScores({ clientId, batchSize: 1 })).rejects.toThrow('killed');
    expect(await scoredCount()).toBe(1);
    jest.restoreAllMocks();

    const lines: string[] = [];
    const resumed = await rescoreFraudScores({ clientId, batchSize: 1, log: (line) => lines.push(line) });

    expect(resumed).toEqual(expect.objectContaining({ scanned: 2, written: 2 }));
    expect(await scoredCount()).toBe(3);
    // A heading, then one progress line per batch of one.
    expect(lines).toHaveLength(3);
  });

  it('resumes a stopped --all run from its cutoff without redoing what it finished', async () => {
    await rescoreFraudScores({ clientId });
    await prisma.visit.updateMany({ where: { clientId, riskScore: { not: null } }, data: { fraudScoredAt: daysAgo(1) } });

    const lines: string[] = [];
    const commit = prisma.$transaction.bind(prisma);
    jest
      .spyOn(prisma, '$transaction')
      .mockImplementationOnce(((queries: Prisma.PrismaPromise<unknown>[]) => commit(queries)) as never)
      .mockImplementationOnce((() => Promise.reject(new Error('killed'))) as never);
    await expect(
      rescoreFraudScores({ clientId, all: true, batchSize: 1, log: (line) => lines.push(line) }),
    ).rejects.toThrow('killed');
    jest.restoreAllMocks();

    // The heading names the cutoff to resume from.
    const cutoff = /--scored-before (\S+)/.exec(lines[0])![1];
    const resumed = await rescoreFraudScores({ clientId, all: true, batchSize: 1, scoredBefore: new Date(cutoff) });

    expect(resumed).toEqual(expect.objectContaining({ scanned: 2, written: 2 }));
    const scoredAts = await prisma.visit.findMany({
      where: { clientId, riskScore: { not: null } },
      select: { fraudScoredAt: true },
    });
    expect(scoredAts).toHaveLength(3);
    expect(scoredAts.every((v) => v.fraudScoredAt!.getTime() >= Date.parse(cutoff))).toBe(true);
  });

  it('never overwrites a score taken after the run started', async () => {
    await rescoreFraudScores({ clientId });
    await prisma.visit.updateMany({ where: { clientId }, data: { fraudScoredAt: daysAgo(1) } });

    // The visit is submitted again (an outbox retry) while the batch is being
    // scored: its newer score lands between the batch's read and its write.
    const newer = new Date(Date.now() + 60_000);
    const read = prisma.visit.findMany.bind(prisma.visit);
    jest.spyOn(prisma.visit, 'findMany').mockImplementationOnce(((args: Prisma.VisitFindManyArgs) =>
      read(args).then(async (rows) => {
        await prisma.visit.update({ where: { id: ids.suspicious }, data: { riskScore: 77, fraudScoredAt: newer } });
        return rows;
      })) as never);

    const result = await rescoreFraudScores({ clientId, all: true });

    expect(result).toEqual(expect.objectContaining({ scanned: 3, written: 2, kept: 1 }));
    const row = await stored(ids.suspicious);
    expect(row.riskScore).toBe(77);
    expect(row.fraudScoredAt!.getTime()).toBe(newer.getTime());
  });
});
