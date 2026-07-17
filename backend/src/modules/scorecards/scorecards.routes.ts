import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  generateScorecard,
  getScorecardByVisit,
  listScorecardHistory,
  listScorecardsForClient,
} from './scorecards.service';

export const scorecardsRouter = Router();
scorecardsRouter.use(requireAuth);

scorecardsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId } = req.body as { visitId?: unknown };

  if (typeof visitId !== 'string' || visitId.length === 0) {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const scorecard = await generateScorecard({ visitId, clientId: req.user!.clientId, agentId: req.user!.userId });
  res.status(201).json(scorecard);
});

// Registered before '/:visitId' so the bare list route isn't shadowed.
scorecardsRouter.get('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const scorecards = await listScorecardsForClient(req.user!.clientId);
  res.status(200).json(scorecards);
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
  const scorecards = await listScorecardHistory({
    clientId: req.user!.clientId,
    outletId,
    agentId: req.user!.role === 'field_agent' ? req.user!.userId : undefined,
  });
  res.status(200).json(scorecards);
});

scorecardsRouter.get('/:visitId', async (req: AuthedRequest, res) => {
  const { visitId } = req.params as { visitId: string };
  const scorecard = await getScorecardByVisit(visitId, req.user!.clientId);
  res.status(200).json(scorecard);
});
