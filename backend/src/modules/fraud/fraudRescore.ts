import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { fraudVisitInclude, scoreFraudBatch, storeFraudScores } from './fraud.service';

/**
 * Backfills and rescores the stored fraud score on submitted visits (#236). The
 * CLI is scripts/rescore-fraud.ts; the loop lives here so it is built,
 * typechecked and tested with the scorer it calls, and so the demo seed can run
 * it too.
 *
 * `Visit.riskScore` is written when a visit is submitted, and it is a snapshot:
 * several signals read history that changes afterwards (earlier visits' stock
 * and photos, rejected check-in attempts) and the client's kpiThresholds. Two
 * situations need this routine:
 *
 *   - backfill: visits submitted before #236, or written straight to the table
 *     (the demo seed), have no score. GET /fraud/flagged cannot list them and
 *     reports them as `unscored`. The default run scores exactly those.
 *   - rescore: a client changed a fraud threshold, or a deploy changed the
 *     engine. `all` rescores visits that already have a score.
 *
 * - Batched: `batchSize` visits per read, scored by scoreFraudBatch in a fixed
 *   number of queries per batch (never per visit), written in one transaction.
 * - Idempotent: the default run only reads visits whose riskScore is null, so a
 *   second run writes nothing. `all` recomputes the same values from the same
 *   data.
 * - Resumable: batches walk `id` upward per client, and a finished row leaves
 *   the selection (it is no longer null; under `all`, its fraudScoredAt is no
 *   longer before the cutoff). A stopped default run resumes by running it
 *   again. A stopped `all` run resumes by passing its cutoff as `scoredBefore`
 *   (logged when it starts), so what it already rescored is not redone.
 * - Never overwrites newer: every write is guarded on fraudScoredAt being null
 *   or before the cutoff, which is the run's start unless `scoredBefore` names an
 *   earlier one. A visit submitted, or rescored by another run, after that
 *   moment keeps its newer score and is counted as `kept`.
 *
 * Only submitted visits are scored: a draft's capture is not final, submit
 * scores it, and the flagged list only reads submitted visits.
 */
export interface RescoreFraudOptions {
  /** Only this tenant. Default: every client, one at a time. */
  clientId?: string;
  /** Only visits checked in (device `checkinTs`) at or after this. */
  since?: Date;
  /** Rescore visits that already have a score, not only unscored ones. */
  all?: boolean;
  /**
   * With `all`: rescore only visits scored before this, and never overwrite a
   * score from after it. Default: the run's start. Pass a stopped run's cutoff
   * to resume it.
   */
  scoredBefore?: Date;
  /** Visits read, scored and written per batch. Default 100. */
  batchSize?: number;
  /** Progress lines. Default: silent. */
  log?: (line: string) => void;
}

export interface RescoreFraudResult {
  startedAt: Date;
  /** Scores from this moment on are never overwritten by the run. */
  cutoff: Date;
  /** Visits read and scored. */
  scanned: number;
  /** Scores this run stored. */
  written: number;
  /** Scored, but a newer score had landed first and was kept. */
  kept: number;
}

export const DEFAULT_RESCORE_BATCH_SIZE = 100;

export async function rescoreFraudScores(options: RescoreFraudOptions = {}): Promise<RescoreFraudResult> {
  const startedAt = new Date();
  const cutoff = options.scoredBefore ?? startedAt;
  const batchSize = Math.max(1, Math.floor(options.batchSize ?? DEFAULT_RESCORE_BATCH_SIZE));
  const result: RescoreFraudResult = { startedAt, cutoff, scanned: 0, written: 0, kept: 0 };

  options.log?.(
    options.all
      ? `Rescoring submitted visits scored before ${cutoff.toISOString()}. ` +
          `If this run stops, resume it with --all --scored-before ${cutoff.toISOString()}`
      : 'Scoring submitted visits that have no stored fraud score',
  );

  const selection: Prisma.VisitWhereInput = options.all
    ? { OR: [{ fraudScoredAt: null }, { fraudScoredAt: { lt: cutoff } }] }
    : { riskScore: null };
  const clientIds = options.clientId
    ? [options.clientId]
    : (await prisma.client.findMany({ select: { id: true }, orderBy: { id: 'asc' } })).map((c) => c.id);

  for (const clientId of clientIds) {
    let afterId: string | undefined;
    for (;;) {
      // The snapshot's time: before anything it is computed from is read.
      const scoredAt = new Date();
      const visits = await prisma.visit.findMany({
        where: {
          ...selection,
          clientId,
          status: 'submitted',
          ...(options.since ? { checkinTs: { gte: options.since } } : {}),
          ...(afterId ? { id: { gt: afterId } } : {}),
        },
        include: fraudVisitInclude,
        orderBy: { id: 'asc' },
        take: batchSize,
      });
      if (visits.length === 0) {
        break;
      }

      const scores = await scoreFraudBatch(clientId, visits);
      const written = await storeFraudScores(scores, scoredAt, cutoff);
      result.scanned += visits.length;
      result.written += written;
      result.kept += visits.length - written;
      afterId = visits[visits.length - 1].id;
      options.log?.(
        `client ${clientId}: scanned ${result.scanned}, written ${result.written}, ` +
          `kept newer ${result.kept} (through ${afterId})`,
      );
    }
  }

  return result;
}
