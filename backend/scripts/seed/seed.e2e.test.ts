import { PrismaClient } from '@prisma/client';
import { getThumbnailForPhoto } from '../../src/modules/photos/thumbnails';
import {
  getAvailabilityTrend,
  getScorecardsTrend,
} from '../../src/modules/trends/trends.service';
import { DEMO_CLIENT_ID } from './catalog';
import { seedDemoData } from './index';
import { resetDemoData } from './reset';

const prisma = new PrismaClient();

// Seeding writes several thousand rows; the default 20s timeout is not enough.
jest.setTimeout(180_000);

describe('seedDemoData (end to end)', () => {
  beforeAll(async () => {
    await seedDemoData(prisma);
  });

  afterAll(async () => {
    await resetDemoData(prisma, DEMO_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: DEMO_CLIENT_ID } });
    await prisma.$disconnect();
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

  it('trends climb from the first bucket to the last', async () => {
    const scorecards = await getScorecardsTrend({
      clientId: DEMO_CLIENT_ID,
      interval: 'week',
    });
    const points = scorecards.points;
    const first = points[0]!.value;
    const last = points[points.length - 1]!.value;
    expect(last).toBeGreaterThan(first);
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

  it('is safe to run twice — the second run replaces rather than duplicates', async () => {
    const before = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    await seedDemoData(prisma);
    const after = await prisma.visit.count({ where: { clientId: DEMO_CLIENT_ID } });
    expect(after).toBe(before);
  });
});
