import { prisma } from '../../lib/prisma';
import { refreshEconomicData } from './economic.refresh';

/**
 * The in-process economic-context refresh, on the same footing as the report
 * schedule (#66) and location prune (#178) workers.
 *
 * Every `intervalMs` it asks the database when a refresh was last ATTEMPTED;
 * when that was more than {@link REFRESH_EVERY_MS} ago it runs
 * {@link refreshEconomicData}. Keying on the database rather than on memory
 * means a restart, or N instances, do not each re-download Stats SA's files:
 * the first instance to run records its attempt and the rest see it. Two that
 * race both refresh, which is harmless — every write is an idempotent upsert.
 *
 * Daily is plenty: Stats SA releases monthly and fuel prices change monthly.
 * A failed source is recorded and retried the next day; the tool reports how
 * stale each source is, so a long outage shows up in answers, not only in logs.
 *
 * Started from `server.ts` only, never on import.
 * `ECONOMIC_REFRESH_ENABLED=false` turns it off.
 */
export interface EconomicRefreshWorker {
  stop(): Promise<void>;
}

export const DEFAULT_CHECK_INTERVAL_MS = 30 * 60_000;
export const REFRESH_EVERY_MS = 20 * 60 * 60_000;

export function economicRefreshEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.ECONOMIC_REFRESH_ENABLED?.trim().toLowerCase() !== 'false';
}

/** Whether a refresh is due, given the newest recorded attempt. */
export function isRefreshDue(now: Date, lastAttemptAt: Date | null): boolean {
  return lastAttemptAt === null || now.getTime() - lastAttemptAt.getTime() >= REFRESH_EVERY_MS;
}

export function startEconomicRefreshWorker(
  options: { intervalMs?: number; now?: () => Date; refresh?: typeof refreshEconomicData } = {},
): EconomicRefreshWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_CHECK_INTERVAL_MS;
  const clock = options.now ?? (() => new Date());
  const refresh = options.refresh ?? refreshEconomicData;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    try {
      const now = clock();
      const latest = await prisma.economicSourceRefresh.aggregate({ _max: { lastAttemptAt: true } });
      if (!isRefreshDue(now, latest._max.lastAttemptAt)) return;
      const results = await refresh({ now });
      console.log(
        '[economic-refresh] ' +
          results.map((r) => `${r.source}: ${r.ok ? `${r.written} figure(s), ${r.detail}` : `failed (${r.detail})`}`).join('; '),
      );
    } catch (err) {
      console.error('[economic-refresh] run failed; retrying on the next check:', err);
    }
  };

  const run = () => {
    if (stopped || current) return;
    current = tick().finally(() => {
      current = null;
    });
  };

  const timer = setInterval(run, intervalMs);
  timer.unref();
  // A fresh deployment should not wait half an hour for its first figures.
  const first = setTimeout(run, 10_000);
  first.unref();

  return {
    async stop() {
      stopped = true;
      clearInterval(timer);
      clearTimeout(first);
      if (current) await current;
    },
  };
}
