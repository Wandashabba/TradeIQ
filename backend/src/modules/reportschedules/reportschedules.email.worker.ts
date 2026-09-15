import { processDueReportEmails, settleInFlightReportEmails } from './reportschedules.email';

/**
 * The in-process report email retry worker (#66): the webhook delivery worker's
 * shape and limits (webhooks.worker.ts), for `report_email_deliveries`.
 *
 * First attempts start the moment a run queues its emails; this only picks up
 * retries that fell due, and attempts that outlived their lease. It polls even
 * when SMTP is not configured — it is one small indexed query — so a row queued
 * before email was switched off still gives up with the reason instead of
 * sitting `failed_retrying` forever.
 *
 * Started from `server.ts` only, never on import.
 */
export interface ReportEmailWorker {
  /** Stops polling and waits for the current batch and any open attempts. */
  stop(): Promise<void>;
}

export interface ReportEmailWorkerOptions {
  intervalMs?: number;
  batchSize?: number;
}

/** 15s, as for webhooks: a 1-minute first retry lands within a quarter of its delay. */
export const DEFAULT_EMAIL_POLL_INTERVAL_MS = 15_000;
/** Small: an attempt may regenerate a whole report. */
export const DEFAULT_EMAIL_BATCH_SIZE = 5;

export function startReportEmailWorker(options: ReportEmailWorkerOptions = {}): ReportEmailWorker {
  const intervalMs = options.intervalMs ?? DEFAULT_EMAIL_POLL_INTERVAL_MS;
  const batchSize = options.batchSize ?? DEFAULT_EMAIL_BATCH_SIZE;
  let stopped = false;
  let current: Promise<void> | null = null;

  const tick = async () => {
    try {
      let processed: number;
      do {
        processed = await processDueReportEmails(new Date(), batchSize);
      } while (!stopped && processed === batchSize);
    } catch (err) {
      console.error('Report email worker tick failed:', err);
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
      await settleInFlightReportEmails();
    },
  };
}
