import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { parsePagination } from '../../lib/pagination';
import { listSkusForClient } from './skus.service';

export const skusRouter = Router();
skusRouter.use(requireAuth);

skusRouter.get('/', async (req: AuthedRequest, res) => {
  const { outletId } = req.query;
  if (typeof outletId !== 'string' || outletId.length === 0) {
    res.status(400).json({ error: 'outletId query param is required' });
    return;
  }
  const { limit, cursor } = parsePagination(req);
  const page = await listSkusForClient({ clientId: req.user!.clientId, outletId, limit, cursor });
  res.status(200).json(page);
});
