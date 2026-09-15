import { PrismaClient } from '@prisma/client';
import { prisma as sharedPrisma } from '../../lib/prisma';
import {
  LedgerEvent,
  scorecardEvent,
  taskClosedEvent,
  visitSubmittedEvent,
} from './pointsLedger';

/**
 * Builds points-ledger entries (#124) from history that predates the ledger:
 * submitted visits, closed tasks and scorecards. The CLI is
 * scripts/backfill-points-ledger.ts; the loop lives here so it is built,
 * typechecked and tested with the code that writes the same entries live.
 *
 * - Idempotent: every write is `createMany … skipDuplicates` against the unique
 *   (sourceType, sourceId, reason), so a re-run, or a run racing the live
 *   hooks, inserts nothing that already exists.
 * - Batched: each phase walks its source table by `id` ascending, `batchSize`
 *   rows per read and one insert per batch.
 * - Resumable: every progress line names the phase and last id; pass it back as
 *   `resumeFrom` (CLI: `--resume visits:<id>`) to skip what is done. Re-running
 *   from the start is also safe, only slower.
 *
 * Dating: visits by checkinTs and scorecards by createdAt, as the board always
 * windowed them. Task has no closure timestamp, so a backfilled closure is
 * dated by the task's createdAt — the earliest it can have been closed. Live
 * closures are dated when they happen.
 *
 * Existing entries are never rewritten, so a scorecard regenerated while its
 * live hook was failing keeps its old score here; the next regenerate fixes it.
 */

export const BACKFILL_PHASES = ['visits', 'tasks', 'scorecards'] as const;
export type BackfillPhase = (typeof BACKFILL_PHASES)[number];

export interface PointsLedgerBackfillOptions {
  /** Source rows read per query. Default 500. */
  batchSize?: number;
  /** Only this tenant's history. */
  clientId?: string;
  /** Skip the phases before this one, and this phase's rows up to `afterId`. */
  resumeFrom?: { phase: BackfillPhase; afterId: string };
  /** Progress lines. Default: silent. */
  log?: (line: string) => void;
}

export interface PhaseResult {
  /** Source rows examined. */
  scanned: number;
  /** Ledger entries this run inserted (already-recorded events are not counted). */
  written: number;
}

export type PointsLedgerBackfillResult = Record<BackfillPhase, PhaseResult>;

export const DEFAULT_POINTS_BACKFILL_BATCH_SIZE = 500;

/** Parses `phase:id` (the form the progress lines print) into `resumeFrom`. */
export function parseResumePoint(raw: string): { phase: BackfillPhase; afterId: string } {
  const at = raw.indexOf(':');
  const phase = raw.slice(0, at);
  const afterId = raw.slice(at + 1);
  if (at < 1 || afterId.length === 0 || !(BACKFILL_PHASES as readonly string[]).includes(phase)) {
    throw new Error(`--resume must be <${BACKFILL_PHASES.join('|')}>:<id>, got "${raw}"`);
  }
  return { phase: phase as BackfillPhase, afterId };
}

type BatchReader = (afterId: string | undefined, take: number) => Promise<{
  lastId: string | undefined;
  events: LedgerEvent[];
  scanned: number;
}>;

/**
 * `db` lets the demo seed pass its own client. The default is the app's shared
 * client, whose type differs only in omitting password/photo-hash columns this
 * function never reads — hence the cast.
 */
export async function backfillPointsLedger(
  options: PointsLedgerBackfillOptions = {},
  db: PrismaClient = sharedPrisma as unknown as PrismaClient,
): Promise<PointsLedgerBackfillResult> {
  const batchSize = Math.max(
    1,
    Math.floor(options.batchSize ?? DEFAULT_POINTS_BACKFILL_BATCH_SIZE),
  );
  const { clientId } = options;
  const after = (afterId: string | undefined) => (afterId ? { id: { gt: afterId } } : {});

  const readers: Record<BackfillPhase, BatchReader> = {
    visits: async (afterId, take) => {
      const rows = await db.visit.findMany({
        where: { status: 'submitted', ...(clientId ? { clientId } : {}), ...after(afterId) },
        orderBy: { id: 'asc' },
        take,
        select: { id: true, clientId: true, agentId: true, checkinTs: true },
      });
      return { lastId: rows.at(-1)?.id, scanned: rows.length, events: rows.map(visitSubmittedEvent) };
    },
    tasks: async (afterId, take) => {
      const rows = await db.task.findMany({
        where: {
          status: 'closed',
          ...(clientId ? { outlet: { clientId } } : {}),
          ...after(afterId),
        },
        orderBy: { id: 'asc' },
        take,
        select: { id: true, ownerId: true, createdAt: true, outlet: { select: { clientId: true } } },
      });
      return {
        lastId: rows.at(-1)?.id,
        scanned: rows.length,
        events: rows.map((t) => taskClosedEvent(t, t.outlet.clientId, t.createdAt)),
      };
    },
    scorecards: async (afterId, take) => {
      const rows = await db.scorecard.findMany({
        where: { ...(clientId ? { visit: { clientId } } : {}), ...after(afterId) },
        orderBy: { id: 'asc' },
        take,
        select: {
          id: true,
          weightedTotal: true,
          createdAt: true,
          visit: { select: { clientId: true, agentId: true } },
        },
      });
      return {
        lastId: rows.at(-1)?.id,
        scanned: rows.length,
        events: rows.map((s) => scorecardEvent(s, s.visit)),
      };
    },
  };

  const result = Object.fromEntries(
    BACKFILL_PHASES.map((phase) => [phase, { scanned: 0, written: 0 }]),
  ) as PointsLedgerBackfillResult;

  const firstPhase = options.resumeFrom ? BACKFILL_PHASES.indexOf(options.resumeFrom.phase) : 0;
  for (const phase of BACKFILL_PHASES.slice(firstPhase)) {
    let afterId =
      options.resumeFrom?.phase === phase ? options.resumeFrom.afterId : undefined;
    for (;;) {
      const batch = await readers[phase](afterId, batchSize);
      if (batch.scanned === 0) {
        break;
      }
      const { count } = await db.pointsLedgerEntry.createMany({
        data: batch.events,
        skipDuplicates: true,
      });
      result[phase].scanned += batch.scanned;
      result[phase].written += count;
      afterId = batch.lastId;
      options.log?.(
        `${phase}: scanned ${result[phase].scanned}, wrote ${result[phase].written} ` +
          `(resume with --resume ${phase}:${afterId})`,
      );
    }
  }

  return result;
}
