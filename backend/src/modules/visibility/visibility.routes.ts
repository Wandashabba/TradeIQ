import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const visibilityRouter = Router();
visibilityRouter.use(requireAuth);
visibilityRouter.get('/', () => {
  throw new NotImplementedError('Visibility/display module (S3-S4) is not implemented yet');
});
