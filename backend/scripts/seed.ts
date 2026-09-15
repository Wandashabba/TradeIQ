// backend/scripts/seed.ts
import { PrismaClient } from '@prisma/client';
import { prisma as appPrisma } from '../src/lib/prisma';
import { seedDemoData } from './seed/index';

const prisma = new PrismaClient();

seedDemoData(prisma)
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    // The fraud scoring the seed runs (#236) goes through the app's own client.
    await appPrisma.$disconnect();
  });
