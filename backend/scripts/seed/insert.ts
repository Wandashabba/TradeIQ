/**
 * Batched writes for the seed.
 *
 * Every table is written with `createMany` in fixed-size slices — never a
 * create per row. A two-year history is millions of rows; one round trip per
 * row would turn a few minutes into hours. The slice bounds a single statement
 * (Postgres caps bind parameters at 65,535, and Prisma splits long
 * statements anyway) and keeps each round trip's payload modest.
 */

export const DEFAULT_CHUNK = 4000;

export async function inChunks<T>(
  rows: readonly T[],
  write: (slice: T[]) => Promise<unknown>,
  chunk = DEFAULT_CHUNK,
): Promise<void> {
  for (let start = 0; start < rows.length; start += chunk) {
    await write(rows.slice(start, start + chunk));
  }
}

/** Wall-clock timings per phase, printed at the end of a seed. */
export class PhaseTimer {
  private readonly totals = new Map<string, number>();
  private readonly started = Date.now();

  async time<T>(phase: string, work: () => Promise<T>): Promise<T> {
    const start = Date.now();
    try {
      return await work();
    } finally {
      this.totals.set(phase, (this.totals.get(phase) ?? 0) + Date.now() - start);
    }
  }

  summary(): string {
    const lines = [...this.totals.entries()].map(
      ([phase, ms]) => `  ${phase.padEnd(28)} ${(ms / 1000).toFixed(1)}s`,
    );
    lines.push(`  ${'total'.padEnd(28)} ${((Date.now() - this.started) / 1000).toFixed(1)}s`);
    return lines.join('\n');
  }
}
