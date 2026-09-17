import { isCollectionGloballyEnabled } from './config';
import { runCompetitorPriceCollection } from './collector';

/**
 * The daily competitor shelf-price run, on the same footing as the location
 * prune worker (#178): an in-process timer that checks every `intervalMs`
 * whether today's (UTC) run is due and runs it once from `hourUtc`.
 *
 * Started from `server.ts` only, and only when `COMPETITOR_PRICE_COLLECTION=on`.
 * Even then a run does nothing for a client whose own switch and approvals are
 * not set — see `gate.ts`.
 *
 * "Once a day" is per instance and in memory, like its sibling. N instances
 * would each run; the per-domain spacing and daily cap are per process too, so
 * run ONE instance with the switch on. The operations doc says so.
 */

export interface CompetitorPriceWorker {
  stop(): Promise<void>;
}

export interface CompetitorPriceWorkerOptions {
  intervalMs?: number;
  hourUtc?: number;
  now?: () => Date;
  run?: typeof runCompetitorPriceCollection;
}

export const DEFAULT_CHECK_INTERVAL_MS = 15 * 60_000;
/** 01:00 UTC is 03:00 in Johannesburg: the quietest hour for a retailer's site. */
export const DEFAULT_RUN_HOUR_UTC = 1;

export function competitorPriceWorkerEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  return isCollectionGloballyEnabled(env);
}

export function isRunDue(now: Date, lastRunDay: string | null, hourUtc: number): boolean {
  return now.getUTCHours() >= hourUtc && lastRunDay !== now.toISOString().slice(0, 10);
}

export function startCompetitorPriceWorker(options: CompetitorPriceWorkerOptions = {}): CompetitorPriceWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_CHECK_INTERVAL_MS;
  const hourUtc = options.hourUtc ?? DEFAULT_RUN_HOUR_UTC;
  const clock = options.now ?? (() => new Date());
  const run = options.run ?? runCompetitorPriceCollection;
  let lastRunDay: string | null = null;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    const now = clock();
    if (!isRunDue(now, lastRunDay, hourUtc)) return;
    // Marked before running: a run that fails part-way is NOT retried the same
    // day. Retrying is how a polite collector turns into a hammering one.
    lastRunDay = now.toISOString().slice(0, 10);
    try {
      const report = await run();
      const observations = report.clients.reduce((n, c) => n + c.observations, 0);
      console.log(
        `[competitor-prices] ${report.skipped ? `skipped (${report.skipped})` : `${report.clients.length} client(s), ${observations} price(s) recorded`}`,
      );
    } catch (err) {
      console.error('[competitor-prices] run failed; next attempt tomorrow:', err);
    }
  };

  const timer = setInterval(() => {
    if (stopped || current) return;
    current = tick().finally(() => {
      current = null;
    });
  }, intervalMs);
  timer.unref();

  return {
    async stop() {
      stopped = true;
      clearInterval(timer);
      if (current) await current;
    },
  };
}
