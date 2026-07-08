import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { NotImplementedError } from '../../middleware/errorHandler';
import { checkIn, submitVisit } from './visits.service';

export const visitsRouter = Router();
visitsRouter.use(requireAuth);

// Check-in is a field-agent action. Relax this guard if managers/admins ever
// need to record visits directly.
visitsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { outletId, lat, lng, checkinTs } = req.body as {
    outletId?: string;
    lat?: number;
    lng?: number;
    checkinTs?: string;
  };

  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }

  const visit = await checkIn({
    outletId,
    lat,
    lng,
    checkinTs,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(201).json(visit);
});

visitsRouter.post('/:id/submit', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const visit = await submitVisit({
    visitId: id,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(200).json(visit);
});

visitsRouter.get('/', () => {
  throw new NotImplementedError('Visit listing is not implemented yet');
});
