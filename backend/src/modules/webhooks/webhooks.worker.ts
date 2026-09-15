import { processDueDeliveries, settleInFlightDeliveries } from './webhooks.service';

/**
 * The in-process webhook retry worker (#100).
 *
 * Every `intervalMs` it claims deliveries whose `nextAttemptAt` has come and
 * attempts them, draining batch after batch while batches come back full.
 *
 * Honest limits, since there is no job infrastructure yet (cron is #66, durable
 * streaming #62):
 *
 * - It runs inside the API process. Retries only happen while some backend
 *   instance is up; a scale-to-zero deploy with no traffic sends nothing until
 *   an instance starts again. Nothing is lost meanwhile — rows are durable, and
 *   the first poll after start picks up everything that fell due.
 * - Timing is coarse: a retry fires up to one interval after it is due.
 * - Each instance polls, so N instances make N small claim queries per
 *   interval. The claim (`FOR UPDATE SKIP LOCKED` plus a lease) keeps them from
 *   sending the same delivery twice; it does not make polling free.
 * - A row whose attempt outlives the lease (a process frozen mid-attempt) can
 *   be attempted again. Receivers de-duplicate on `X-TradeIQ-Delivery`, which
 *   is why the header exists.
 *
 * Started from `server.ts` only — never on import — so tests and scripts that
 * load the app do not start polling a database behind their backs.
 */
export interface WebhookDeliveryWorker {
  /** Stops polling and waits for the current batch and any open attempts. */
  stop(): Promise<void>;
}

export interface WebhookDeliveryWorkerOptions {
  intervalMs?: number;
  batchSize?: number;
}

/** 15s: a 1-minute first retry lands within a quarter of its delay. */
export const DEFAULT_POLL_INTERVAL_MS = 15_000;
export const DEFAULT_BATCH_SIZE = 20;

export function startWebhookDeliveryWorker(
  options: WebhookDeliveryWorkerOptions = {},
): WebhookDeliveryWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_POLL_INTERVAL_MS;
  const batchSize = options.batchSize ?? DEFAULT_BATCH_SIZE;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    try {
      let processed: number;
      do {
        processed = await processDueDeliveries(new Date(), batchSize);
      } while (!stopped && processed === batchSize);
    } catch (err) {
      console.error('Webhook delivery worker tick failed:', err);
    }
  };

  const timer = setInterval(() => {
    // One tick at a time: a slow batch must not stack another claim on top.
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
      await settleInFlightDeliveries();
    },
  };
}
