import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const scorecardsRouter = Router();
scorecardsRouter.use(requireAuth);
scorecardsRouter.get('/', () => {
  throw new NotImplementedError('Scorecard engine module (S10) is not implemented yet');
});
