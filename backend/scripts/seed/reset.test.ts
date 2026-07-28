import { PrismaClient } from '@prisma/client';
import { resetDemoData } from './reset';

const prisma = new PrismaClient();

const OTHER_CLIENT_ID = 'reset-test-other-client';
const DEMO_ID = 'reset-test-demo-client';

async function makeClient(id: string): Promise<void> {
  await prisma.client.create({
    data: {
      id,
      name: `client-${id}`,
      industry: 'FMCG',
      scorecardWeights: {},
      kpiThresholds: {},
    },
  });
}

describe('resetDemoData', () => {
  beforeEach(async () => {
    await resetDemoData(prisma, DEMO_ID);
    await resetDemoData(prisma, OTHER_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: { in: [DEMO_ID, OTHER_CLIENT_ID] } } });
    await makeClient(DEMO_ID);
    await makeClient(OTHER_CLIENT_ID);
  });

  afterAll(async () => {
    await resetDemoData(prisma, DEMO_ID);
    await resetDemoData(prisma, OTHER_CLIENT_ID);
    await prisma.client.deleteMany({ where: { id: { in: [DEMO_ID, OTHER_CLIENT_ID] } } });
    await prisma.$disconnect();
  });

  it('deletes the target client\'s rows', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-1', clientId: DEMO_ID, name: 'T', code: 'T1' },
    });
    await prisma.sku.create({
      data: { id: 'reset-s-1', clientId: DEMO_ID, name: 'S', category: 'C', minFacingsStandard: 1, rrp: 1 },
    });

    await resetDemoData(prisma, DEMO_ID);

    expect(await prisma.territory.count({ where: { clientId: DEMO_ID } })).toBe(0);
    expect(await prisma.sku.count({ where: { clientId: DEMO_ID } })).toBe(0);
  });

  // THE safety test. A bare deleteMany({}) would pass every other assertion
  // in this file and fail only this one.
  it('leaves another tenant\'s rows completely untouched', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-other', clientId: OTHER_CLIENT_ID, name: 'T', code: 'T1' },
    });
    await prisma.sku.create({
      data: { id: 'reset-s-other', clientId: OTHER_CLIENT_ID, name: 'S', category: 'C', minFacingsStandard: 1, rrp: 1 },
    });
    await prisma.user.create({
      data: { id: 'reset-u-other', clientId: OTHER_CLIENT_ID, email: 'other@reset-test.local', passwordHash: 'x', role: 'admin' },
    });

    await resetDemoData(prisma, DEMO_ID);

    expect(await prisma.territory.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
    expect(await prisma.sku.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
    expect(await prisma.user.count({ where: { clientId: OTHER_CLIENT_ID } })).toBe(1);
  });

  it('deletes visit children before visits, so no foreign key blows up', async () => {
    await prisma.territory.create({
      data: { id: 'reset-t-2', clientId: DEMO_ID, name: 'T', code: 'T2' },
    });
    const outlet = await prisma.outlet.create({
      data: { id: 'reset-o-1', clientId: DEMO_ID, name: 'O', code: 'O1', channelType: 'x', lat: 0, lng: 0, territoryId: 'reset-t-2' },
    });
    const agent = await prisma.user.create({
      data: { id: 'reset-u-1', clientId: DEMO_ID, email: 'agent@reset-test.local', passwordHash: 'x', role: 'field_agent' },
    });
    const visit = await prisma.visit.create({
      data: { id: 'reset-v-1', clientId: DEMO_ID, outletId: outlet.id, agentId: agent.id, checkinTs: new Date(), checkinLat: 0, checkinLng: 0, geofencePass: true, status: 'submitted' },
    });
    await prisma.scorecard.create({
      data: { visitId: visit.id, dimensionScores: {}, weightedTotal: 80, ratingBand: 'green' },
    });
    await prisma.photo.create({
      data: { visitId: visit.id, section: 'visibility', url: 'data:image/jpeg;base64,AA==', gpsTag: {}, timestamp: new Date() },
    });

    await expect(resetDemoData(prisma, DEMO_ID)).resolves.not.toThrow();
    expect(await prisma.visit.count({ where: { clientId: DEMO_ID } })).toBe(0);
    expect(await prisma.scorecard.count({ where: { visit: { clientId: DEMO_ID } } })).toBe(0);
  });

  it('is safe to run against a client that has no data', async () => {
    await expect(resetDemoData(prisma, 'reset-test-nonexistent')).resolves.not.toThrow();
  });
});
