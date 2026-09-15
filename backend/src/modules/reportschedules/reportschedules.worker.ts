import { processDueSchedules } from './reportschedules.service';

/**
 * The in-process report schedule worker (#66).
 *
 * Every `intervalMs` it claims schedules whose `nextRunAt` has come, generates
 * each report and delivers it (reportschedules.delivery.ts), draining batch
 * after batch while batches come back full.
 *
 * Same shape and the same honest limits as the webhook delivery worker:
 *
 * - It runs inside the API process, so schedules only fire while some backend
 *   instance is up. Nothing is lost meanwhile: when an instance starts, every
 *   schedule that fell due fires ONCE, and its next run is the next slot still
 *   to come (reportschedules.cadence.ts) — a week of downtime is one report,
 *   not seven.
 * - Timing is coarse: a schedule fires up to one interval after it is due.
 * - N instances make N small claim queries per interval. The claim
 *   (`FOR UPDATE SKIP LOCKED` plus a lease) keeps them from firing the same
 *   schedule together, and a unique (schedule, due time) run record stops a
 *   run that outlived its lease from being delivered a second time.
 * - A run that throws is retried when its lease lapses (10 minutes).
 *
 * Started from `server.ts` only — never on import — so tests and scripts that
 * load the app do not start firing schedules behind their backs.
 */
export interface ReportScheduleWorker {
  /** Stops polling and waits for the batch in progress. */
  stop(): Promise<void>;
}

export interface ReportScheduleWorkerOptions {
  intervalMs?: number;
  batchSize?: number;
}

/** 60s: schedules are daily or weekly, so a minute late is on time. */
export const DEFAULT_SCHEDULE_POLL_INTERVAL_MS = 60_000;
export const DEFAULT_SCHEDULE_BATCH_SIZE = 5;

export function startReportScheduleWorker(
  options: ReportScheduleWorkerOptions = {},
): ReportScheduleWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_SCHEDULE_POLL_INTERVAL_MS;
  const batchSize = options.batchSize ?? DEFAULT_SCHEDULE_BATCH_SIZE;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    try {
      let processed: number;
      do {
        processed = await processDueSchedules(new Date(), batchSize);
      } while (!stopped && processed === batchSize);
    } catch (err) {
      console.error('Report schedule worker tick failed:', err);
    }
  };

  const timer = setInterval(() => {
    // One tick at a time: a slow report must not stack another claim on top.
    if (stopped || current) return;
    current = tick().finally(() => {
      current = null;
    });
  }, intervalMs);
  // Never the reason a process stays alive; `stop()` is the orderly exit.
  timer.unref();

  return {
    async stop() {
      stopped = true;
      clearInterval(timer);
      if (current) await current;
    },
  };
}
