import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const capabilityRouter = Router();
capabilityRouter.use(requireAuth);
capabilityRouter.get('/', () => {
  throw new NotImplementedError('Sales capability module (S7) is not implemented yet');
});
