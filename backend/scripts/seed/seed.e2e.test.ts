import { PrismaClient } from '@prisma/client';
import { prisma as appPrisma } from '../../src/lib/prisma';
import { getVisitFraud, listFlagged } from '../../src/modules/fraud/fraud.service';
import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import {
  getAvailabilityTrend,
  getScorecardsTrend,
} from '../../src/modules/trends/trends.service';
import { addDays } from './calendar';
import { DEMO_CLIENT_ID } from './catalog';
import { seedDemoData } from './index';
import { resetDemoData } from './reset';

const prisma = new PrismaClient();

// The `test` profile is the full world cut to three months and a sixth of the
// outlets — still tens of thousands of rows, so the default 20s is not enough.
jest.setTimeout(300_000);

describe('seedDemoData (end to end)', () => {
  beforeAll(async () => {
    await seedDemoData(prisma, { profile: 'test' });
  });

  afterAll(async () => {
    await resetDemoData(prisma, DEMO_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: DEMO_CLIENT_ID } });
    await prisma.$disconnect();
    await appPrisma.$disconnect();
  });

  it('writes the expected shape of dataset', async () => {
    expect(await prisma.outlet.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(25);
    expect(await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(250);
    expect(await prisma.scorecard.count({ where: { visit: { clientId: DEMO_CLIENT_ID } } })).toBeGreaterThan(250);
  });

  // #204: the dashboard hero showed "Not enough data to plot" because every
  // scorecard landed in one weekly bucket. LineChart needs >= 2 points.
  it('produces many weekly trend buckets, not one', async () => {
    const filters = { clientId: DEMO_CLIENT_ID, interval: 'week' as const };
    const scorecards = await getScorecardsTrend(filters);
    const availability = await getAvailabilityTrend(filters);
    expect(scorecards.points.length).toBeGreaterThanOrEqual(3);
    expect(availability.points.length).toBeGreaterThanOrEqual(3);
  });

  it('fills the tables the Ask TradeIQ questions read', async () => {
    expect(await prisma.salesTarget.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.contest.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.campaign.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(1);
    expect(await prisma.orderLine.count({ where: { order: { clientId: DEMO_CLIENT_ID } } })).toBeGreaterThan(0);
    expect(await prisma.pointsLedgerEntry.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
  });

  // #236 via #244: the ghost-visit agent reuses photos, and the stored scores see it.
  it('flags the planted fraud pattern with a stored duplicate-photo signal', async () => {
    const flagged = await prisma.visit.findMany({
      where: { clientId: DEMO_CLIENT_ID, riskScore: { gte: 50 } },
      select: { agentId: true, fraudSignals: true },
    });
    expect(flagged.length).toBeGreaterThan(0);
    const ghost = flagged.filter((v) => v.agentId === 'demo-user-agent-14').length;
    expect(ghost / flagged.length).toBeGreaterThan(0.9);
    const codes = new Set(flagged.flatMap((v) => (v.fraudSignals as Array<{ code: string }>).map((s) => s.code)));
    expect(codes.has('duplicate_photo')).toBe(true);
    expect(codes.has('fast_completion')).toBe(true);
  });

  // #209: seeded photos rendered as grey boxes because the stored URLs 422'd.
  it('stores photos the thumbnail endpoint can actually decode', async () => {
    const photos = await prisma.photo.findMany({
      where: { visit: { clientId: DEMO_CLIENT_ID } },
      take: 5,
      select: { id: true, url: true },
    });
    expect(photos.length).toBe(5);

    for (const photo of photos) {
      const thumb = await getThumbnailForPhoto(photo.id, async () => photo.url);
      expect(thumb.length).toBeGreaterThan(0);
      expect(thumb[0]).toBe(0xff);
      expect(thumb[1]).toBe(0xd8);
    }
  });

  it('leaves open alerts and overdue tasks for the demo to act on', async () => {
    expect(await prisma.alert.count({ where: { clientId: DEMO_CLIENT_ID, acknowledged: false } })).toBeGreaterThan(0);
    expect(await prisma.task.count({
      where: { outlet: { clientId: DEMO_CLIENT_ID }, status: 'open', slaDueAt: { lt: new Date() } },
    })).toBeGreaterThan(0);
  });

  it('gives today a beat plan with stops', async () => {
    const plan = await prisma.beatPlan.findFirst({
      where: { clientId: DEMO_CLIENT_ID },
      include: { stops: true },
    });
    expect(plan).not.toBeNull();
    expect(plan!.stops.length).toBeGreaterThan(0);
  });

  it('fills every screen the walkthrough visits', async () => {
    expect(await prisma.message.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.announcement.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.order.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.incentiveScheme.count({ where: { clientId: DEMO_CLIENT_ID } })).toBeGreaterThan(0);
    expect(await prisma.checkInAttempt.count({ where: { clientId: DEMO_CLIENT_ID, passed: false } })).toBeGreaterThan(0);
    expect(await prisma.visitTemplateResponse.count({ where: { visit: { clientId: DEMO_CLIENT_ID } } })).toBeGreaterThan(0);
  });

  // #236: the seed writes visits directly, never through submitVisit, so it must
  // store their fraud scores itself — or the flagged list, which reads only the
  // stored column, would have nothing to show and the fraud screen would go empty.
  it('stores a fraud score on every seeded visit, equal to the live score', async () => {
    expect(await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID, riskScore: null } })).toBe(0);

    const page = await listFlagged({
      clientId: DEMO_CLIENT_ID,
      minScore: 0,
      from: addDays(new Date(), -120),
      limit: 200,
    });
    expect(page.unscored).toBe(0);
    expect(page.data.length).toBeGreaterThan(0);

    for (const row of page.data.slice(0, 5)) {
      const live = await getVisitFraud(row.visitId, DEMO_CLIENT_ID);
      expect(row.riskScore).toBe(live.riskScore);
      expect(row.signals).toEqual(live.signals);
    }
  });

  it('is safe to run twice — the second run replaces rather than duplicates', async () => {
    const before = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    await seedDemoData(prisma, { profile: 'test' });
    const after = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    expect(after).toBe(before);
  });
});
