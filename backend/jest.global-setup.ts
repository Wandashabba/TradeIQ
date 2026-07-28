import { PrismaClient } from '@prisma/client';
import { execSync } from 'child_process';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { databaseNameOf, workerDatabaseUrl } from './jest.worker-db';

/**
 * Builds one migrated database per jest worker (#186).
 *
 * Suites used to share a single `tradeiq_test`, so a suite asserting on global
 * counts, "newest first", or "then it is gone" could see rows another suite was
 * concurrently creating or deleting. The result was a random single failure
 * about one run in three — a different test each time, since the casualty was
 * whichever suite lost that particular race.
 *
 * The base database is migrated once and then used as a Postgres TEMPLATE, so
 * each worker database is a cheap file copy rather than a fresh
 * `prisma migrate deploy`. Dropping and recreating per run also removes the
 * need to truncate: every worker starts from a guaranteed-empty schema.
 */
export default async function globalSetup(globalConfig?: {
  maxWorkers?: number;
}): Promise<void> {
  dotenv.config({ path: path.resolve(__dirname, '.env.test'), override: true });

  const baseUrl = process.env.DATABASE_URL;
  if (!baseUrl) {
    throw new Error('DATABASE_URL not set after loading .env.test');
  }

  const baseName = databaseNameOf(baseUrl);
  const workerCount = Math.max(1, globalConfig?.maxWorkers ?? 1);

  const adminUrl = new URL(baseUrl);
  adminUrl.pathname = '/postgres';
  const adminPrisma = new PrismaClient({ datasources: { db: { url: adminUrl.toString() } } });

  try {
    // The template database. Created once per machine, migrated every run so
    // the schema is current.
    const existing = await adminPrisma.$queryRawUnsafe<Array<{ exists: boolean }>>(
      `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1) as exists`,
      baseName,
    );
    if (!existing[0]?.exists) {
      // CREATE DATABASE cannot be parameterised or run inside a transaction;
      // baseName comes from our own .env.test, not user input.
      await adminPrisma.$executeRawUnsafe(`CREATE DATABASE "${baseName}"`);
    }

    execSync('npx prisma migrate deploy', {
      cwd: path.resolve(__dirname),
      env: { ...process.env, DATABASE_URL: baseUrl },
      stdio: 'inherit',
    });

    for (let worker = 1; worker <= workerCount; worker += 1) {
      const workerName = databaseNameOf(workerDatabaseUrl(baseUrl, String(worker)));

      // A previous run that was killed mid-suite can leave connections open,
      // and Postgres refuses to drop a database that anything is attached to.
      await adminPrisma.$executeRawUnsafe(
        `SELECT pg_terminate_backend(pid) FROM pg_stat_activity
         WHERE datname = $1 AND pid <> pg_backend_pid()`,
        workerName,
      );
      await adminPrisma.$executeRawUnsafe(`DROP DATABASE IF EXISTS "${workerName}"`);

      // TEMPLATE copies the migrated schema without re-running migrations.
      // Postgres requires the template to have no other connections, which is
      // why prisma migrate deploy above runs as a subprocess that has exited.
      await adminPrisma.$executeRawUnsafe(
        `CREATE DATABASE "${workerName}" TEMPLATE "${baseName}"`,
      );
    }
  } finally {
    await adminPrisma.$disconnect();
  }
}
