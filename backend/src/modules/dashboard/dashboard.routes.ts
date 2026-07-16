import { Response, Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getDashboardByTerritory, getDashboardSummary } from './dashboard.service';

export const dashboardRouter = Router();
dashboardRouter.use(requireAuth);

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

/** Parses `from`/`to` query params into Dates, or responds 400 and returns null. */
function parseDateRange(req: AuthedRequest, res: Response): { from?: Date; to?: Date } | null {
  const fromRaw = queryString(req.query.from);
  const toRaw = queryString(req.query.to);

  let from: Date | undefined;
  if (fromRaw !== undefined) {
    from = new Date(fromRaw);
    if (Number.isNaN(from.getTime())) {
      res.status(400).json({ error: 'from must be a valid ISO date' });
      return null;
    }
  }
  let to: Date | undefined;
  if (toRaw !== undefined) {
    to = new Date(toRaw);
    if (Number.isNaN(to.getTime())) {
      res.status(400).json({ error: 'to must be a valid ISO date' });
      return null;
    }
  }
  return { from, to };
}

dashboardRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const territoryId = queryString(req.query.territoryId);
  const outletId = queryString(req.query.outletId);

  const range = parseDateRange(req, res);
  if (range === null) return;

  const summary = await getDashboardSummary({
    clientId: req.user!.clientId,
    territoryId,
    outletId,
    from: range.from,
    to: range.to,
  });
  res.status(200).json(summary);
});

// One query pair for every territory, instead of one `GET /dashboard` call
// per territory (#97) — see getDashboardByTerritory for the id/code join.
dashboardRouter.get(
  '/by-territory',
  requireRole('manager', 'admin'),
  async (req: AuthedRequest, res) => {
    const range = parseDateRange(req, res);
    if (range === null) return;

    const summaries = await getDashboardByTerritory({
      clientId: req.user!.clientId,
      from: range.from,
      to: range.to,
    });
    res.status(200).json(summaries);
  },
);
