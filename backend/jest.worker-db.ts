/**
 * Per-worker test database naming (#186).
 *
 * Every jest worker gets its own database, so parallel suites cannot see or
 * race each other's rows. Before this, all suites shared one `tradeiq_test`
 * and a random single test failed about one run in three — a *different* test
 * each time, because the casualty was whichever suite happened to race another
 * that round. That trains people to re-run until green, which is exactly how a
 * real regression slips through.
 *
 * Shared by `jest.global-setup.ts` (which creates the databases) and
 * `jest.setup-env.ts` (which points each worker at its own). They must agree on
 * the name, so the rule lives here rather than being spelled twice.
 */

/** Postgres identifiers here are interpolated, not parameterised — keep them boring. */
const SAFE_WORKER_ID = /^[A-Za-z0-9_]+$/;

export function workerDatabaseUrl(baseUrl: string, workerId: string): string {
  if (!SAFE_WORKER_ID.test(workerId)) {
    throw new Error(
      `Refusing to build a database name from worker id "${workerId}": ` +
        'a worker id must be alphanumeric/underscore.',
    );
  }

  const url = new URL(baseUrl);
  const name = url.pathname.replace(/^\//, '');
  if (!name) {
    throw new Error(`DATABASE_URL has no database name: ${baseUrl}`);
  }

  url.pathname = `/${name}_${workerId}`;
  return url.toString();
}

/** The database name only, for CREATE/DROP statements. */
export function databaseNameOf(url: string): string {
  const name = new URL(url).pathname.replace(/^\//, '');
  if (!name) {
    throw new Error(`DATABASE_URL has no database name: ${url}`);
  }
  return name;
}
