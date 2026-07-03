import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);
dashboardRouter.get('/', () => {
  throw new NotImplementedError('Dashboard KPI aggregation module is not implemented yet');
});
