import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { NotImplementedError } from '../../middleware/errorHandler';
import { checkIn } from './visits.service';

export const visitsRouter = Router();
visitsRouter.use(requireAuth);

visitsRouter.post('/', async (req: AuthedRequest, res) => {
  const { outletId, lat, lng } = req.body as { outletId?: string; lat?: number; lng?: number };

  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }

  const visit = await checkIn({
    outletId,
    lat,
    lng,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(201).json(visit);
});

visitsRouter.get('/', () => {
  throw new NotImplementedError('Visit listing is not implemented yet');
});
