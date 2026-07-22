import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listAgentActivity } from './agents.service';

export const agentsRouter = Router();
agentsRouter.use(requireAuth);

/** Two days. See the range-cap note below. */
const MAX_RANGE_MS = 48 * 60 * 60 * 1000;

/**
 * Where each field agent has been confirmed present in a time window.
 *
 * Takes `from`/`to` as ISO-8601 INSTANTS rather than a `date`, deliberately.
 * There is no `Client.timezone` and no timezone handling anywhere in this
 * backend, so resolving a calendar date server-side would mean UTC — which
 * cuts the day at 02:00 SAST and splits a South African field team's morning
 * across two "days". The client knows the manager's locale; it sends explicit
 * instants and the server does no timezone reasoning at all.
 */
agentsRouter.get('/activity', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { from, to, territoryId, limit, cursor } = req.query as {
    from?: string;
    to?: string;
    territoryId?: string;
    limit?: string;
    cursor?: string;
  };

  if (typeof from !== 'string' || typeof to !== 'string') {
    res.status(400).json({ error: 'from and to are required ISO-8601 instants' });
    return;
  }

  const fromDate = new Date(from);
  const toDate = new Date(to);
  if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
    res.status(400).json({ error: 'from and to must be valid ISO-8601 instants' });
    return;
  }

  if (toDate.getTime() <= fromDate.getTime()) {
    res.status(400).json({ error: 'to must be after from' });
    return;
  }

  if (toDate.getTime() - fromDate.getTime() > MAX_RANGE_MS) {
    res.status(400).json({ error: 'range must not exceed 48 hours' });
    return;
  }

  let parsedLimit: number | undefined;
  if (limit !== undefined) {
    parsedLimit = Number(limit);
    if (!Number.isInteger(parsedLimit) || parsedLimit < 1) {
      res.status(400).json({ error: 'limit must be a positive integer' });
      return;
    }
  }

  const result = await listAgentActivity({
    // Never from a parameter. The tenant comes from the token.
    clientId: req.user!.clientId,
    from: fromDate,
    to: toDate,
    territoryId: typeof territoryId === 'string' ? territoryId : undefined,
    limit: parsedLimit,
    cursor: typeof cursor === 'string' ? cursor : undefined,
  });

  res.status(200).json(result);
});
