// backend/scripts/seed.ts
import { PrismaClient } from '@prisma/client';
import { seedDemoData } from './seed/index';

const prisma = new PrismaClient();

seedDemoData(prisma)
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
