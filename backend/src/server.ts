import 'dotenv/config';
import { app } from './app';
import { assertJwtSecretUsable } from './modules/auth/auth.service';
import { startWebhookDeliveryWorker } from './modules/webhooks/webhooks.worker';

// Fail fast and loudly: a published or weak JWT_SECRET must stop the process
// here, not surface later as unexplainable 401s.
assertJwtSecretUsable();

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

const server = app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});

// Webhook retries (#100). Started here and only here: `app.ts` is imported by
// every route test, and a poller started on import would run in all of them.
const webhookWorker = startWebhookDeliveryWorker();

let shuttingDown = false;
function shutdown(signal: string): void {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received — stopping webhook worker and closing server`);
  // Let an in-flight attempt record its outcome. One that is cut off anyway is
  // not lost: its lease runs out and the next instance attempts it again.
  void webhookWorker
    .stop()
    .catch((err) => console.error('Webhook worker did not stop cleanly:', err))
    .finally(() => server.close(() => process.exit(0)));
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
