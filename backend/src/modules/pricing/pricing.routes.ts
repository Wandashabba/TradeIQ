import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';

export const pricingRouter = Router();
pricingRouter.use(requireAuth);
pricingRouter.get('/', () => {
  throw new NotImplementedError('Pricing/promotions module (S5) is not implemented yet');
});
