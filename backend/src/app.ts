import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { authRouter } from './modules/auth/auth.routes';
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
import { trendsRouter } from './modules/trends/trends.routes';
import { fraudRouter } from './modules/fraud/fraud.routes';
import { dispatchRouter } from './modules/dispatch/dispatch.routes';
import { forecastRouter } from './modules/forecast/forecast.routes';
import { ordersRouter } from './modules/orders/orders.routes';
import { collaborationRouter } from './modules/collaboration/collaboration.routes';
import { webhooksRouter } from './modules/webhooks/webhooks.routes';
import { gamificationRouter } from './modules/gamification/gamification.routes';
import { reportsRouter } from './modules/reports/reports.routes';
import { clientsRouter } from './modules/clients/clients.routes';
import { usersRouter } from './modules/users/users.routes';
import { incentivesRouter } from './modules/incentives/incentives.routes';
import { reportSchedulesRouter } from './modules/reportschedules/reportschedules.routes';
import { errorHandler } from './middleware/errorHandler';

export const app = express();

// Baseline security headers (nosniff, frameguard, HSTS, etc.).
app.use(helmet());

// CORS: in production set CORS_ORIGINS to a comma-separated allowlist of
// frontend origins. When it's unset (local dev) we fall back to an open
// policy — the Flutter web dev server has no fixed port (`flutter run -d
// chrome` picks one dynamically) and there's no deployed origin yet. Auth
// uses a Bearer token (not cookies), so the open dev policy carries no CSRF
// risk.
const corsOrigins = process.env.CORS_ORIGINS
  ?.split(',')
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);
app.use(cors(corsOrigins && corsOrigins.length > 0 ? { origin: corsOrigins } : {}));

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
app.use('/campaigns', campaignsRouter);
app.use('/beatplans', beatplansRouter);
app.use('/alerts', alertsRouter);
app.use('/templates', templatesRouter);
app.use('/trends', trendsRouter);
app.use('/fraud', fraudRouter);
app.use('/dispatch', dispatchRouter);
app.use('/forecast', forecastRouter);
app.use('/orders', ordersRouter);
app.use('/', collaborationRouter);
app.use('/webhooks', webhooksRouter);
app.use('/gamification', gamificationRouter);
app.use('/reports', reportsRouter);
app.use('/clients', clientsRouter);
app.use('/users', usersRouter);
app.use('/incentives', incentivesRouter);
app.use('/report-schedules', reportSchedulesRouter);

app.use(errorHandler);
