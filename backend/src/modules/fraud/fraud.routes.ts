import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getVisitFraud, listAttempts, listFlagged } from './fraud.service';
import { parsePagination } from '../../lib/pagination';

const DEFAULT_MIN_SCORE = 50;

export const fraudRouter = Router();

// Fraud analytics are a supervisory concern: managers/admins only, and every
// query is scoped to the caller's own client (tenant).
fraudRouter.use(requireAuth);
fraudRouter.use(requireRole('manager', 'admin'));

// GET /fraud/visits/:visitId — score a single visit. 404 if it isn't the
// caller's tenant's visit.
fraudRouter.get('/visits/:visitId', async (req: AuthedRequest, res) => {
  const { visitId } = req.params as { visitId: string };
  const result = await getVisitFraud(visitId, req.user!.clientId);
  res.status(200).json(result);
});

// GET /fraud/attempts — list check-in attempts, optional outletId/agentId/passed.
fraudRouter.get('/attempts', async (req: AuthedRequest, res) => {
  const { outletId, agentId, passed } = req.query as {
    outletId?: unknown;
    agentId?: unknown;
    passed?: unknown;
  };

  if (outletId !== undefined && typeof outletId !== 'string') {
    res.status(400).json({ error: 'outletId must be a string' });
    return;
  }
  if (agentId !== undefined && typeof agentId !== 'string') {
    res.status(400).json({ error: 'agentId must be a string' });
    return;
  }

  let passedFilter: boolean | undefined;
  if (passed !== undefined) {
    if (passed === 'true') {
      passedFilter = true;
    } else if (passed === 'false') {
      passedFilter = false;
    } else {
      res.status(400).json({ error: "passed must be 'true' or 'false'" });
      return;
    }
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listAttempts({
    clientId: req.user!.clientId,
    outletId,
    agentId,
    passed: passedFilter,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

// GET /fraud/flagged — submitted visits scoring >= minScore (default 50).
fraudRouter.get('/flagged', async (req: AuthedRequest, res) => {
  const { minScore } = req.query as { minScore?: unknown };

  let min = DEFAULT_MIN_SCORE;
  if (minScore !== undefined) {
    if (typeof minScore !== 'string' || minScore.trim() === '' || !Number.isFinite(Number(minScore))) {
      res.status(400).json({ error: 'minScore must be a number' });
      return;
    }
    min = Number(minScore);
  }

  // The scan window. Rejected rather than coerced when malformed: a silently
  // ignored `from` would quietly widen the scan back to everything, which is
  // the exact behaviour this endpoint was changed to stop doing.
  const window: { from?: Date; to?: Date } = {};
  for (const key of ['from', 'to'] as const) {
    const raw = (req.query as Record<string, unknown>)[key];
    if (raw === undefined) continue;
    if (typeof raw !== 'string' || Number.isNaN(Date.parse(raw))) {
      res.status(400).json({ error: `${key} must be an ISO-8601 date` });
      return;
    }
    window[key] = new Date(raw);
  }

  const page = await listFlagged({ clientId: req.user!.clientId, minScore: min, ...window });
  res.status(200).json(page);
});
