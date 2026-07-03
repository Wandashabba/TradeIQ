import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const stockRouter = Router();
stockRouter.use(requireAuth);
stockRouter.get('/', () => {
  throw new NotImplementedError('Stock module (S2) is not implemented yet');
});
