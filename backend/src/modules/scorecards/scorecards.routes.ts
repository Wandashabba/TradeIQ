import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  generateScorecard,
  getScorecardByVisit,
  listScorecardHistory,
  listScorecardsForClient,
  SCORECARD_HISTORY_DEFAULT_LIMIT,
} from './scorecards.service';
import { parsePagination } from '../../lib/pagination';

export const scorecardsRouter = Router();
scorecardsRouter.use(requireAuth);

function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

/**
 * The device's own score, sent alongside the finalize marker (#390, #399).
 *
 * Optional at every level: an older app build sends `{ visitId }` alone and
 * everything works exactly as it did. `.strict()` on both objects so a client
 * that misspells `ratingBnd` is told, instead of having half a score silently
 * stored — a total with no band is not a score anyone saw, and the service
 * would have to discard it.
 */
const provisionalBody = z
  .object({
    weightedTotal: z.number().min(0).max(100),
    ratingBand: z.enum(['green', 'amber', 'red']),
    computedAt: z.string().datetime({ offset: true }).optional(),
  })
  .strict();

const createScorecardBody = z
  .object({
    visitId: z.string().min(1),
    provisional: provisionalBody.optional(),
  })
  .strict();

scorecardsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const parsed = createScorecardBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: 'visitId is required', issues: issues(parsed.error) });
    return;
  }

  const scorecard = await generateScorecard({
    visitId: parsed.data.visitId,
    // What the agent SAW on the device. Recorded, never scored against: see
    // generateScorecard.
    provisional: parsed.data.provisional,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(201).json(scorecard);
});

// Registered before '/:visitId' so the bare list route isn't shadowed.
scorecardsRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  const page = await listScorecardsForClient({
    clientId: req.user!.clientId,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

// Also registered before '/:visitId', which would otherwise swallow the word
// 'history' as a visit id.
scorecardsRouter.get('/history', async (req: AuthedRequest, res) => {
  const { outletId } = req.query as { outletId?: unknown };
  if (typeof outletId !== 'string' || outletId.length === 0) {
    res.status(400).json({ error: 'outletId is required' });
    return;
  }

  // An agent's history at an outlet is their own. Scoping it here rather than
  // trusting a query param means an agent cannot ask for a colleague's scores.
  // Defaults to the last handful, which is what this endpoint has always
  // meant; an explicit ?limit= overrides it like any other list.
  const { limit, cursor } = parsePagination(req, SCORECARD_HISTORY_DEFAULT_LIMIT);
  const page = await listScorecardHistory({
    clientId: req.user!.clientId,
    outletId,
    agentId: req.user!.role === 'field_agent' ? req.user!.userId : undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

scorecardsRouter.get('/:visitId', async (req: AuthedRequest, res) => {
  const { visitId } = req.params as { visitId: string };
  const scorecard = await getScorecardByVisit(visitId, req.user!.clientId);
  res.status(200).json(scorecard);
});
