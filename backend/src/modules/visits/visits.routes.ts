import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const visitsRouter = Router();
visitsRouter.use(requireAuth);
visitsRouter.get('/', () => {
  throw new NotImplementedError('Visits module (S1 check-in flow) is not implemented yet');
});
