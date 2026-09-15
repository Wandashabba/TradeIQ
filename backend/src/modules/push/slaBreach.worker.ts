import { getPushSender } from './push.sender';
import { SLA_BREACH_BATCH_SIZE, sweepSlaBreaches } from './slaBreach';

/**
 * The in-process SLA-breach sweep (#67), on the same footing as the webhook,
 * report-schedule and location-prune workers.
 *
 * Every `intervalMs` it announces tasks whose SLA has just passed (see
 * `slaBreach.ts`). Honest limits, the same as its siblings: it runs inside the
 * API process, so a scale-to-zero deploy with no traffic announces nothing
 * until an instance starts — and then only breaches within the lookback.
 *
 * It does nothing while push is unconfigured: no query, and no task marked as
 * announced, so switching push on later still announces the last day's
 * breaches. `SLA_BREACH_SWEEP_ENABLED=false` turns it off outright.
 *
 * Started from `server.ts` only — never on import.
 */
export interface SlaBreachWorker {
  stop(): Promise<void>;
}

export interface SlaBreachWorkerOptions {
  intervalMs?: number;
  now?: () => Date;
  sweep?: typeof sweepSlaBreaches;
  isPushEnabled?: () => boolean;
}

/** Five minutes: a breach push that is a few minutes late is still news. */
export const DEFAULT_SLA_SWEEP_INTERVAL_MS = 5 * 60_000;

export function slaBreachSweepEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.SLA_BREACH_SWEEP_ENABLED?.trim().toLowerCase() !== 'false';
}

export function startSlaBreachWorker(options: SlaBreachWorkerOptions = {}): SlaBreachWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_SLA_SWEEP_INTERVAL_MS;
  const clock = options.now ?? (() => new Date());
  const sweep = options.sweep ?? sweepSlaBreaches;
  const isPushEnabled = options.isPushEnabled ?? (() => getPushSender().enabled);
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    if (!isPushEnabled()) return;
    try {
      let claimed: number;
      do {
        ({ claimed } = await sweep(clock(), SLA_BREACH_BATCH_SIZE));
      } while (!stopped && claimed === SLA_BREACH_BATCH_SIZE);
    } catch (err) {
      console.error('[sla-breach] sweep failed; retrying on the next check:', err);
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
