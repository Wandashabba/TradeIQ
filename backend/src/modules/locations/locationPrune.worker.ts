import { pruneLocationPings } from './locationRetention';

/**
 * The in-process location retention worker (#178), on the same footing as the
 * report schedule worker (#66) and the webhook worker (#100).
 *
 * Every `intervalMs` it checks whether today's (UTC) prune has run; from the
 * quiet hour onwards it runs {@link pruneLocationPings} once, then waits for
 * the next day. Honest limits, the same as its siblings:
 *
 * - It runs inside the API process, so it only prunes while some instance is
 *   up. Nothing is lost meanwhile: pings past retention simply wait, and the
 *   first check after the quiet hour on a day an instance is up catches up.
 * - "Once a day" is per instance and remembered in memory. N instances, or a
 *   restart, can each run it that day. That is safe rather than wasteful:
 *   pruning is idempotent (a folded day has no raw pings left) and each
 *   agent-day fold holds an advisory lock, so concurrent runs never double-count
 *   a summary — the second run just finds nothing to do.
 * - A run that throws is retried on the next check.
 * - `LOCATION_PRUNE_ENABLED=false` turns it off (e.g. while running the
 *   `npm run prune-location-pings` script by hand).
 *
 * Started from `server.ts` only — never on import — so tests and scripts that
 * load the app do not start deleting rows behind their backs.
 */
export interface LocationPruneWorker {
  /** Stops checking and waits for a prune in progress. */
  stop(): Promise<void>;
}

export interface LocationPruneWorkerOptions {
  intervalMs?: number;
  /** UTC hour from which the day's prune may run. */
  hourUtc?: number;
  now?: () => Date;
  prune?: typeof pruneLocationPings;
}

/** 15 minutes: a daily job needs no finer timing, and a check is one clock read. */
export const DEFAULT_PRUNE_CHECK_INTERVAL_MS = 15 * 60_000;

/**
 * 00:00 UTC is 02:00 in Johannesburg, where this product's field teams are:
 * after the last shift and before the first, when nobody is pinging.
 */
export const DEFAULT_PRUNE_HOUR_UTC = 0;

export function locationPruneEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.LOCATION_PRUNE_ENABLED?.trim().toLowerCase() !== 'false';
}

/** The UTC day `at` falls on, as `YYYY-MM-DD`. */
function utcDay(at: Date): string {
  return at.toISOString().slice(0, 10);
}

/** Whether a prune should run now, given the UTC day of the last one. */
export function isPruneDue(now: Date, lastRunDay: string | null, hourUtc: number): boolean {
  return now.getUTCHours() >= hourUtc && lastRunDay !== utcDay(now);
}

export function startLocationPruneWorker(options: LocationPruneWorkerOptions = {}): LocationPruneWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_PRUNE_CHECK_INTERVAL_MS;
  const hourUtc = options.hourUtc ?? DEFAULT_PRUNE_HOUR_UTC;
  const clock = options.now ?? (() => new Date());
  const prune = options.prune ?? pruneLocationPings;
  let lastRunDay: string | null = null;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    const now = clock();
    if (!isPruneDue(now, lastRunDay, hourUtc)) return;
    const started = Date.now();
    try {
      const result = await prune({ now });
      lastRunDay = utcDay(now);
      console.log(
        `[location-prune] summarised ${result.agentDaysSummarised} agent-day(s), deleted ` +
          `${result.pingsDeleted} ping(s), purged ${result.deactivatedAgentsPurged} deactivated agent(s) ` +
          `in ${Math.round((Date.now() - started) / 1000)}s`,
      );
    } catch (err) {
      // Not marked as run: the next check tries again.
      console.error('[location-prune] run failed; retrying on the next check:', err);
    }
  };

  const timer = setInterval(() => {
    // One run at a time: a long first catch-up must not stack another on top.
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
