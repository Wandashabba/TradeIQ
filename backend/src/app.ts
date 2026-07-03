import cors from 'cors';
import express from 'express';
import { authRouter } from './modules/auth/auth.routes';
import { outletsRouter } from './modules/outlets/outlets.routes';
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
import { errorHandler } from './middleware/errorHandler';

export const app = express();

// Open CORS policy: the Flutter web dev server runs on a different port
// than this API, and there's no fixed dev port (`flutter run -d chrome`
// picks one dynamically) or deployed origin yet in Phase 1. Auth uses a
// Bearer token (not cookies), so an open policy carries no CSRF risk.
// Revisit with an explicit origin allowlist once there's a real deployed
// frontend origin to pin to.
app.use(cors());

app.use(express.json());

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/auth', authRouter);
app.use('/outlets', outletsRouter);
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

app.use(errorHandler);
