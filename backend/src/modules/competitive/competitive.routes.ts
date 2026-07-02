import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const competitiveRouter = Router();
competitiveRouter.use(requireAuth);
competitiveRouter.get('/', () => {
  throw new NotImplementedError('Competitive intelligence module (S6) is not implemented yet');
});
