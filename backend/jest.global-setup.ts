import { PrismaClient } from '@prisma/client';
import { execSync } from 'child_process';
import * as dotenv from 'dotenv';
import * as path from 'path';

export default async function globalSetup(): Promise<void> {
  dotenv.config({ path: path.resolve(__dirname, '.env.test'), override: true });

  const testDatabaseUrl = process.env.DATABASE_URL;
  if (!testDatabaseUrl) {
    throw new Error('DATABASE_URL not set after loading .env.test');
  }

  const url = new URL(testDatabaseUrl);
  const testDbName = url.pathname.replace(/^\//, '');

  // Connect to Postgres's default maintenance database to create the test
  // database if it doesn't exist yet (first run on this machine/container).
  const adminUrl = new URL(testDatabaseUrl);
  adminUrl.pathname = '/postgres';
  const adminPrisma = new PrismaClient({ datasources: { db: { url: adminUrl.toString() } } });
  try {
    const existing = await adminPrisma.$queryRawUnsafe<Array<{ exists: boolean }>>(
      `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1) as exists`,
      testDbName,
    );
    if (!existing[0]?.exists) {
      // CREATE DATABASE cannot be parameterized or run inside a transaction;
      // testDbName comes from our own .env.test, not user input.
      await adminPrisma.$executeRawUnsafe(`CREATE DATABASE "${testDbName}"`);
    }
  } finally {
    await adminPrisma.$disconnect();
  }

  // Ensure the schema is current.
  execSync('npx prisma migrate deploy', {
    cwd: path.resolve(__dirname),
    env: { ...process.env, DATABASE_URL: testDatabaseUrl },
    stdio: 'inherit',
  });

  // Truncate every table so this run starts from a guaranteed-clean slate,
  // regardless of whether a previous run's afterAll cleanup completed.
  const testPrisma = new PrismaClient({ datasources: { db: { url: testDatabaseUrl } } });
  try {
    const tables = await testPrisma.$queryRawUnsafe<Array<{ tablename: string }>>(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('_prisma_migrations')`,
    );
    if (tables.length > 0) {
      const tableList = tables.map((t) => `"${t.tablename}"`).join(', ');
      await testPrisma.$executeRawUnsafe(`TRUNCATE TABLE ${tableList} RESTART IDENTITY CASCADE`);
    }
  } finally {
    await testPrisma.$disconnect();
  }
}
