/**
 * Shared guards for the benchmark scripts in scripts/bench (#311). They write
 * tens of thousands of rows or print query plans, so they only ever run against
 * a scratch database whose name says so.
 */

/** Throws unless DATABASE_URL names a database containing "bench". */
export function assertBenchDatabase(): void {
  const raw = process.env.DATABASE_URL;
  if (!raw) {
    throw new Error('DATABASE_URL is not set');
  }
  const name = new URL(raw).pathname.replace(/^\//, '');
  if (!name.includes('bench')) {
    throw new Error(`refusing to run against "${name}": benchmark scripts need a database named *bench*`);
  }
}

/** `--name <positive int>` from argv, or the default. */
export function intFlag(name: string, fallback: number): number {
  const args = process.argv.slice(2);
  const i = args.indexOf(`--${name}`);
  if (i < 0) {
    return fallback;
  }
  const value = Number(args[i + 1]);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`--${name} must be a positive integer, got "${args[i + 1]}"`);
  }
  return value;
}
