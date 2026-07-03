import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { listSkusForClient } from './skus.service';

export const skusRouter = Router();
skusRouter.use(requireAuth);

skusRouter.get('/', async (req: AuthedRequest, res) => {
  const skus = await listSkusForClient(req.user!.clientId);
  res.status(200).json(skus);
});
