import 'dotenv/config';
import { app } from './app';
import {
  competitorPriceWorkerEnabled,
  startCompetitorPriceWorker,
} from './modules/competitorPrices/collector.worker';
import { assertJwtSecretUsable } from './modules/auth/auth.service';
import { locationPruneEnabled, startLocationPruneWorker } from './modules/locations/locationPrune.worker';
import { logReportEmailConfig } from './modules/reportschedules/reportschedules.email';
import { startReportEmailWorker } from './modules/reportschedules/reportschedules.email.worker';
import { startReportScheduleWorker } from './modules/reportschedules/reportschedules.worker';
import { startWebhookDeliveryWorker } from './modules/webhooks/webhooks.worker';
import { settleInFlightPushes } from './modules/push/push.notify';
import { slaBreachSweepEnabled, startSlaBreachWorker } from './modules/push/slaBreach.worker';

// Fail fast and loudly: a published or weak JWT_SECRET must stop the process
// here, not surface later as unexplainable 401s.
assertJwtSecretUsable();

// Report email is optional (#66), so a missing or broken SMTP config does not
// stop the process — it is logged here, without secrets, and every run records
// email as not_configured with the reason.
logReportEmailConfig();

const port = process.env.PORT ? Number(process.env.PORT) : 4000;

const server = app.listen(port, () => {
  console.log(`TradeIQ backend listening on port ${port}`);
});

// Webhook retries (#100) and scheduled reports (#66). Started here and only
// here: `app.ts` is imported by every route test, and a poller started on import
// would run in all of them.
const webhookWorker = startWebhookDeliveryWorker();
const reportScheduleWorker = startReportScheduleWorker();
const reportEmailWorker = startReportEmailWorker();
// Daily location-ping retention (#178). LOCATION_PRUNE_ENABLED=false opts out.
const locationPruneWorker = locationPruneEnabled() ? startLocationPruneWorker() : null;
// SLA-breach pushes (#67). Idle while FIREBASE_SERVICE_ACCOUNT is unset;
// SLA_BREACH_SWEEP_ENABLED=false opts out.
const slaBreachWorker = slaBreachSweepEnabled() ? startSlaBreachWorker() : null;
// Competitor shelf prices from retailer websites. Not even started unless
// COMPETITOR_PRICE_COLLECTION=on, and then only collects for clients whose own
// legal gate is open (docs/operations/competitor-price-collection.md).
const competitorPriceWorker = competitorPriceWorkerEnabled() ? startCompetitorPriceWorker() : null;

let shuttingDown = false;
function shutdown(signal: string): void {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received — stopping workers and closing server`);
  // Schedules first: a run in progress queues webhook and email deliveries,
  // which their workers then let finish. Anything cut off is not lost — a
  // schedule claim and a delivery lease both run out, and the next instance
  // retries. A prune cut off mid-run loses nothing either: each agent-day is
  // one transaction, and the next run carries on.
  void reportScheduleWorker
    .stop()
    .catch((err) => console.error('Report schedule worker did not stop cleanly:', err))
    .then(() => reportEmailWorker.stop())
    .catch((err) => console.error('Report email worker did not stop cleanly:', err))
    .then(() => webhookWorker.stop())
    .catch((err) => console.error('Webhook worker did not stop cleanly:', err))
    .then(() => locationPruneWorker?.stop())
    .catch((err) => console.error('Location prune worker did not stop cleanly:', err))
    .then(() => slaBreachWorker?.stop())
    .catch((err) => console.error('SLA breach worker did not stop cleanly:', err))
    .then(() => competitorPriceWorker?.stop())
    .catch((err) => console.error('Competitor price worker did not stop cleanly:', err))
    // Pushes already on their way to FCM are let finish, not cut off.
    .then(() => settleInFlightPushes())
    .finally(() => server.close(() => process.exit(0)));
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
