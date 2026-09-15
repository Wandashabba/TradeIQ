import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parseIsoInstant } from '../../lib/parseIsoInstant';
import { parsePagination } from '../../lib/pagination';
import { listAgentActivity } from './agents.service';
import { listAgentLocations } from './agentLocations.service';

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

  // parseIsoInstant requires a full instant (Z or numeric offset) and
  // rejects well-formed-but-impossible dates (e.g. Feb 31) — see its
  // comment for why a naive date/datetime can't be allowed here.
  const fromDate = parseIsoInstant(from);
  const toDate = parseIsoInstant(to);
  if (fromDate === undefined || toDate === undefined) {
    res.status(400).json({
      error: 'from and to must be full ISO-8601 instants with a Z or numeric offset',
    });
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

/**
 * Each field agent's latest foreground location (#153 T1), with its age and a
 * derived state: at_store, in_transit, stale or offline. See
 * `agentLocations.service.ts` and `locations/locationPolicy.ts` for the rules.
 *
 * Paged by agent with the shared `limit`/`cursor` contract (#141). Carries
 * `serverTime` so a client measures age against the clock that measured it,
 * not a phone or laptop clock that may be minutes out.
 */
agentsRouter.get('/locations', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const { territoryId } = req.query as { territoryId?: unknown };
  const page = await listAgentLocations({
    // Never from a parameter. The tenant comes from the token.
    clientId: req.user!.clientId,
    territoryId: typeof territoryId === 'string' ? territoryId : undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});
