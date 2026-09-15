import 'dotenv/config';
import { Prisma } from '@prisma/client';
import { prisma } from '../../src/lib/prisma';
import { fraudVisitInclude, scoreFraudBatch } from '../../src/modules/fraud/fraud.service';
import { assertBenchDatabase, intFlag } from './benchDb';

/**
 * EXPLAIN (ANALYZE, BUFFERS) the duplicate-photo lookup exactly as the fraud
 * service sends it (#311). NOT run in CI; bench databases only (see benchDb.ts).
 *
 *   npx ts-node scripts/bench/explain-duplicate-photo.ts
 *   npx ts-node scripts/bench/explain-duplicate-photo.ts --sizes 1,16,100 --runs 7
 *
 *   --sizes  comma-separated visit batch sizes (default 1,16,100): 1 is
 *            GET /fraud/visits/:id and the submit hook, 16 a small rescore,
 *            100 the rescore-fraud default batch
 *   --runs   timed executions per size, median reported (default 5)
 *
 * It does not copy the SQL. It runs the real scoreFraudBatch() with
 * `prisma.$queryRaw` wrapped: the one statement that mentions
 * perceptual_hash_bands is sent as `EXPLAIN (ANALYZE, BUFFERS) <same text>` with
 * the same bound parameters, so a change to the service query is measured as
 * shipped. Visits are the newest submitted ones of the first client — the
 * worst case, since every lookup only matches EARLIER visits.
 */

type RawFn = (query: Prisma.Sql) => Promise<unknown>;

async function main(): Promise<void> {
  assertBenchDatabase();
  const sizesArg = process.argv.includes('--sizes') ? process.argv[process.argv.indexOf('--sizes') + 1] : '1,16,100';
  const sizes = sizesArg.split(',').map((s) => Number(s));
  const runs = intFlag('runs', 5);

  const client = await prisma.client.findFirstOrThrow({ orderBy: { name: 'asc' }, select: { id: true } });
  const original = prisma.$queryRaw.bind(prisma) as unknown as RawFn;
  const isLookup = (query: Prisma.Sql) => query.sql.includes('perceptual_hash_bands');
  let mode: 'explain' | 'time' = 'explain';
  let captured: { plan: string; ms: number; rows: number; photos: number; probeKeys: number } | null = null;

  const patched: RawFn = async (query) => {
    if (!isLookup(query)) {
      return original(query);
    }
    const values = query.values as unknown[];
    if (mode === 'explain') {
      const plan = await prisma.$queryRawUnsafe<Array<{ 'QUERY PLAN': string }>>(
        `EXPLAIN (ANALYZE, BUFFERS) ${query.text}`,
        ...values,
      );
      captured = {
        plan: plan.map((line) => line['QUERY PLAN']).join('\n'),
        ms: 0,
        rows: 0,
        photos: (values[0] as unknown[]).length,
        probeKeys: (values.find((v, i) => i > 5 && Array.isArray(v) && typeof v[0] === 'number') as unknown[] | undefined)
          ?.length ?? 0,
      };
      return [];
    }
    const started = process.hrtime.bigint();
    const rows = (await original(query)) as unknown[];
    const ms = Number(process.hrtime.bigint() - started) / 1e6;
    captured = { plan: '', ms, rows: rows.length, photos: (values[0] as unknown[]).length, probeKeys: 0 };
    return rows;
  };
  (prisma as unknown as { $queryRaw: RawFn }).$queryRaw = patched;

  for (const size of sizes) {
    const visits = await prisma.visit.findMany({
      where: { clientId: client.id, status: 'submitted' },
      orderBy: [{ checkinTs: 'desc' }, { id: 'desc' }],
      take: size,
      include: fraudVisitInclude,
    });

    mode = 'explain';
    captured = null;
    await scoreFraudBatch(client.id, visits);
    const explained = captured as { plan: string; photos: number; probeKeys: number } | null;

    mode = 'time';
    const timings: number[] = [];
    let rows = 0;
    for (let i = 0; i < runs; i += 1) {
      captured = null;
      await scoreFraudBatch(client.id, visits);
      const timed = captured as { ms: number; rows: number } | null;
      if (timed) {
        timings.push(timed.ms);
        rows = timed.rows;
      }
    }
    timings.sort((a, b) => a - b);
    const median = timings.length ? timings[Math.floor(timings.length / 2)] : NaN;

    console.log(`\n=== ${size} visit(s): ${explained?.photos ?? 0} source photos, ${explained?.probeKeys ?? 0} probe keys ===`);
    console.log(`round trip via Prisma: median ${median.toFixed(1)} ms over ${runs} runs, ${rows} matched photos`);
    console.log(explained?.plan ?? '(no lookup: no hashed photos in batch)');
  }
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
