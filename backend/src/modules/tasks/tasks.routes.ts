import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const tasksRouter = Router();
tasksRouter.use(requireAuth);
tasksRouter.get('/', () => {
  throw new NotImplementedError('Task lifecycle module (S9) is not implemented yet');
});
