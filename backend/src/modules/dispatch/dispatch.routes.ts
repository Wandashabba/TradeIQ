import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { rankAgentsForOutlet } from './dispatch.service';

export const dispatchRouter = Router();

// Predictive dispatch is a management action: only managers/admins may see the
// ranked agent recommendations for an outlet.
dispatchRouter.use(requireAuth, requireRole('manager', 'admin'));

dispatchRouter.post('/', async (req: AuthedRequest, res) => {
  const { outletId } = req.body as { outletId?: unknown };

  if (typeof outletId !== 'string') {
    res.status(400).json({ error: 'outletId is required' });
    return;
  }

  const candidates = await rankAgentsForOutlet(outletId, req.user!.clientId);
  res.status(200).json({
    outletId,
    recommended: candidates[0] ?? null,
    candidates,
  });
});

dispatchRouter.get('/agents', async (req: AuthedRequest, res) => {
  const { outletId } = req.query as { outletId?: string };

  if (typeof outletId !== 'string' || outletId.length === 0) {
    res.status(400).json({ error: 'outletId is required' });
    return;
  }

  const candidates = await rankAgentsForOutlet(outletId, req.user!.clientId);
  res.status(200).json({ outletId, candidates });
});
