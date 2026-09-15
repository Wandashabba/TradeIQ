import 'dotenv/config';
import { app } from './app';
import { assertJwtSecretUsable } from './modules/auth/auth.service';
import { startReportScheduleWorker } from './modules/reportschedules/reportschedules.worker';
import { startWebhookDeliveryWorker } from './modules/webhooks/webhooks.worker';

// Fail fast and loudly: a published or weak JWT_SECRET must stop the process
// here, not surface later as unexplainable 401s.
assertJwtSecretUsable();

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

const server = app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});

// Webhook retries (#100) and scheduled reports (#66). Started here and only
// here: `app.ts` is imported by every route test, and a poller started on import
// would run in all of them.
const webhookWorker = startWebhookDeliveryWorker();
const reportScheduleWorker = startReportScheduleWorker();

let shuttingDown = false;
function shutdown(signal: string): void {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received — stopping workers and closing server`);
  // Schedules first: a run in progress queues webhook deliveries, which the
  // webhook worker then lets finish. Anything cut off is not lost — a schedule
  // claim and a delivery lease both run out, and the next instance retries.
  void reportScheduleWorker
    .stop()
    .catch((err) => console.error('Report schedule worker did not stop cleanly:', err))
    .then(() => webhookWorker.stop())
    .catch((err) => console.error('Webhook worker did not stop cleanly:', err))
    .finally(() => server.close(() => process.exit(0)));
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
