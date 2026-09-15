import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { authRouter } from './modules/auth/auth.routes';
import { agentsRouter } from './modules/agents/agents.routes';
import { outletsRouter } from './modules/outlets/outlets.routes';
import { skusRouter } from './modules/skus/skus.routes';
import { visitsRouter } from './modules/visits/visits.routes';
import { stockRouter } from './modules/stock/stock.routes';
import { visibilityRouter } from './modules/visibility/visibility.routes';
import { pricingRouter } from './modules/pricing/pricing.routes';
import { competitiveRouter } from './modules/competitive/competitive.routes';
import { capabilityRouter } from './modules/capability/capability.routes';
import { risksRouter } from './modules/risks/risks.routes';
import { tasksRouter } from './modules/tasks/tasks.routes';
import { scorecardsRouter } from './modules/scorecards/scorecards.routes';
import { dashboardRouter } from './modules/dashboard/dashboard.routes';
import { photosRouter } from './modules/photos/photos.routes';
import { territoriesRouter } from './modules/territories/territories.routes';
import { campaignsRouter } from './modules/campaigns/campaigns.routes';
import { beatplansRouter } from './modules/beatplans/beatplans.routes';
import { alertsRouter } from './modules/alerts/alerts.routes';
import { templatesRouter } from './modules/templates/templates.routes';
import { templateResponsesRouter } from './modules/templateResponses/templateResponses.routes';
import { trendsRouter } from './modules/trends/trends.routes';
import { fraudRouter } from './modules/fraud/fraud.routes';
import { dispatchRouter } from './modules/dispatch/dispatch.routes';
import { forecastRouter } from './modules/forecast/forecast.routes';
import { ordersRouter } from './modules/orders/orders.routes';
import {
  announcementsRouter,
  messagesRouter,
} from './modules/collaboration/collaboration.routes';
import {
  webhookDeliveriesRouter,
  webhooksRouter,
} from './modules/webhooks/webhooks.routes';
import { gamificationRouter } from './modules/gamification/gamification.routes';
import { contestsRouter } from './modules/contests/contests.routes';
import { reportsRouter } from './modules/reports/reports.routes';
import { clientsRouter } from './modules/clients/clients.routes';
import { usersRouter } from './modules/users/users.routes';
import { locationsRouter } from './modules/locations/locations.routes';
import { incentivesRouter } from './modules/incentives/incentives.routes';
import { reportSchedulesRouter } from './modules/reportschedules/reportschedules.routes';
import { reportDownloadsRouter } from './modules/reportschedules/reportschedules.downloads.routes';
import { salesTargetsRouter } from './modules/salesTargets/salesTargets.routes';
import { assistantRouter } from './modules/assistant/assistant.routes';
import { pushRouter } from './modules/push/push.routes';
import { errorHandler } from './middleware/errorHandler';

export const app = express();

// Baseline security headers (nosniff, frameguard, HSTS, etc.).
app.use(helmet());

// CORS: set CORS_ORIGINS to a comma-separated allowlist of frontend origins.
//
// The open fallback is now conditioned on NODE_ENV, not merely on the variable
// being absent. It used to key off absence alone, and its own comment called
// that "local dev" — but a production deploy that simply never set the variable
// got the open policy too, silently. That is what happened: the live backend
// ran with an open policy because nobody had set CORS_ORIGINS yet.
//
// The dev fallback is still open on purpose: `flutter run -d chrome` picks a
// port dynamically, so there is no fixed origin to allowlist.
//
// In production an unset variable now fails CLOSED — no cross-origin browser
// access — rather than open. It does not throw, unlike the JWT secret: mobile
// clients send no Origin header and are unaffected, so refusing to boot would
// take down a working API over a setting none of its current callers use. The
// warning is loud instead, because a silently restrictive policy is its own
// kind of trap once a web console does exist.
const corsOrigins = process.env.CORS_ORIGINS?.split(',')
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

const isProduction = process.env.NODE_ENV === 'production';

if (corsOrigins && corsOrigins.length > 0) {
  app.use(cors({ origin: corsOrigins }));
} else if (isProduction) {
  // `origin: false` reflects no Access-Control-Allow-Origin at all, so browsers
  // refuse cross-origin reads. Native clients are untouched.
  console.warn(
    '[cors] CORS_ORIGINS is not set in production — cross-origin browser ' +
      'requests will be refused. Set it to the web console origin before ' +
      'deploying one.',
  );
  app.use(cors({ origin: false }));
} else {
  app.use(cors());
}

// Raised from the 100kb default so base64 photo data URLs (POST /photos, capped
// at ~8MB of base64 in the route) fit. Real object storage is a later phase.
app.use(express.json({ limit: '12mb' }));

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/auth', authRouter);
app.use('/outlets', outletsRouter);
app.use('/skus', skusRouter);
app.use('/visits', visitsRouter);
app.use('/stock', stockRouter);
app.use('/visibility', visibilityRouter);
app.use('/pricing', pricingRouter);
app.use('/competitive', competitiveRouter);
app.use('/capability', capabilityRouter);
app.use('/risks', risksRouter);
app.use('/tasks', tasksRouter);
app.use('/scorecards', scorecardsRouter);
app.use('/dashboard', dashboardRouter);
app.use('/photos', photosRouter);
app.use('/territories', territoriesRouter);
app.use('/agents', agentsRouter);
app.use('/campaigns', campaignsRouter);
app.use('/beatplans', beatplansRouter);
app.use('/alerts', alertsRouter);
app.use('/templates', templatesRouter);
app.use('/template-responses', templateResponsesRouter);
app.use('/trends', trendsRouter);
app.use('/fraud', fraudRouter);
app.use('/dispatch', dispatchRouter);
app.use('/forecast', forecastRouter);
app.use('/orders', ordersRouter);
// Mounted at the two real prefixes rather than at '/'. A root mount made
// collaboration's own `requireAuth` run for EVERY path that reached it, so an
// unknown route answered 401 instead of 404 and anything mounted below
// inherited auth. The Flutter client calls /messages and /announcements, so
// those paths must not change.
app.use('/messages', messagesRouter);
app.use('/announcements', announcementsRouter);
app.use('/webhooks', webhooksRouter);
app.use('/webhook-deliveries', webhookDeliveriesRouter);
app.use('/gamification', gamificationRouter);
app.use('/contests', contestsRouter);
app.use('/reports', reportsRouter);
app.use('/clients', clientsRouter);
app.use('/users', usersRouter);
app.use('/locations', locationsRouter);
app.use('/push', pushRouter);
app.use('/incentives', incentivesRouter);
app.use('/report-schedules', reportSchedulesRouter);
// Signed CSV links (#66). No bearer token: the signed token in the path is the
// credential, so this must not sit under the report-schedules router's auth.
app.use('/report-downloads', reportDownloadsRouter);
app.use('/sales-targets', salesTargetsRouter);
// Every route below /assistant is gated on the per-client rollout flag, which
// 404s a tenant outside the rollout. The kill switch is therefore
// indistinguishable from the feature never having shipped.
app.use('/assistant', assistantRouter);

// Every route is mounted above. Anything reaching here does not exist — say so,
// rather than letting it fall through to a misleading 401.
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(errorHandler);
