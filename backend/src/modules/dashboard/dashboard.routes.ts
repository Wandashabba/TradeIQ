import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getDashboardSummary } from './dashboard.service';

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

dashboardRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const territoryId = queryString(req.query.territoryId);
  const outletId = queryString(req.query.outletId);
  const fromRaw = queryString(req.query.from);
  const toRaw = queryString(req.query.to);

  let from: Date | undefined;
  if (fromRaw !== undefined) {
    from = new Date(fromRaw);
    if (Number.isNaN(from.getTime())) {
      res.status(400).json({ error: 'from must be a valid ISO date' });
      return;
    }
  }
  let to: Date | undefined;
  if (toRaw !== undefined) {
    to = new Date(toRaw);
    if (Number.isNaN(to.getTime())) {
      res.status(400).json({ error: 'to must be a valid ISO date' });
      return;
    }
  }

  const summary = await getDashboardSummary({
    clientId: req.user!.clientId,
    territoryId,
    outletId,
    from,
    to,
  });
  res.status(200).json(summary);
});
