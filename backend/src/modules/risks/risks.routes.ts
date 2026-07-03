import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const risksRouter = Router();
risksRouter.use(requireAuth);
risksRouter.get('/', () => {
  throw new NotImplementedError('Opportunities/risks module (S8) is not implemented yet');
});
