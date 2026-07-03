// backend/scripts/seed.ts
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/auth.service';

const prisma = new PrismaClient();

async function main() {
  const client = await prisma.client.upsert({
    where: { id: 'demo-fmcg-client' },
    update: {},
    create: {
      id: 'demo-fmcg-client',
      name: 'Demo FMCG Brand',
      industry: 'FMCG',
      scorecardWeights: {
        availability: 0.3,
        visibility: 0.25,
        display: 0.15,
        pricing: 0.1,
        salesCapability: 0.1,
        competitive: 0.1,
      },
      kpiThresholds: { excellent: 90, good: 70, needsImprovement: 50 },
    },
  });

  const manager = await prisma.user.upsert({
    where: { email: 'manager@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'manager@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'manager',
      clientId: client.id,
    },
  });

  await prisma.user.upsert({
    where: { email: 'agent@demo-fmcg.tradeiq.com' },
    update: {},
    create: {
      email: 'agent@demo-fmcg.tradeiq.com',
      passwordHash: await hashPassword('demo-password-123'),
      role: 'field_agent',
      clientId: client.id,
    },
  });

  const outlets = [
    { name: 'Sandton Hypermarket', code: 'SAN-001', channelType: 'hypermarket', lat: -26.1076, lng: 28.0567 },
    { name: 'Rosebank Supermarket', code: 'ROS-002', channelType: 'supermarket', lat: -26.1467, lng: 28.0436 },
    { name: 'Fourways Convenience', code: 'FOU-003', channelType: 'convenience', lat: -26.0164, lng: 28.0122 },
  ];

  for (const outlet of outlets) {
    await prisma.outlet.upsert({
      where: { code: outlet.code },
      update: {},
      create: {
        ...outlet,
        territoryId: 'gauteng-north',
        teamProfile: { headcount: 4 },
        clientId: client.id,
      },
    });
  }

  await prisma.sku.upsert({
    where: { id: 'demo-sku-1' },
    update: {},
    create: {
      id: 'demo-sku-1',
      clientId: client.id,
      name: 'Demo Brand 500ml',
      category: 'Beverages',
      minFacingsStandard: 4,
      rrp: 24.99,
    },
  });

  console.log(`Seeded client ${client.name}, manager ${manager.email}, ${outlets.length} outlets, 1 SKU`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
