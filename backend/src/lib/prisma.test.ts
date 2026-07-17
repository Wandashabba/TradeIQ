import { prisma } from './prisma';

describe('global passwordHash omit', () => {
  it('omits passwordHash from a default user query', async () => {
    const client = await prisma.client.create({
      data: { name: 'OMIT-Client', industry: 'FMCG', scorecardWeights: {}, kpiThresholds: {} },
    });
    const user = await prisma.user.create({
      data: { email: 'omit-test@example.com', passwordHash: 'SHOULD-NOT-APPEAR', role: 'manager', clientId: client.id },
    });

    const fetched = await prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    expect((fetched as Record<string, unknown>).passwordHash).toBeUndefined();

    await prisma.user.deleteMany({ where: { clientId: client.id } });
    await prisma.client.delete({ where: { id: client.id } });
  });
});
