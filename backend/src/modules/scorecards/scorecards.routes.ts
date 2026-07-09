import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { NotImplementedError } from '../../middleware/errorHandler';
import { generateScorecard, getScorecardByVisit } from './scorecards.service';

export const scorecardsRouter = Router();
scorecardsRouter.use(requireAuth);

scorecardsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId } = req.body as { visitId?: unknown };

  if (typeof visitId !== 'string' || visitId.length === 0) {
    res.status(400).json({ error: 'visitId is required' });
    return;
  }

  const scorecard = await generateScorecard({ visitId, clientId: req.user!.clientId });
  res.status(201).json(scorecard);
});

// Registered before '/:visitId' so the bare list route isn't shadowed.
scorecardsRouter.get('/', () => {
  throw new NotImplementedError('Scorecard listing is not implemented yet');
});

scorecardsRouter.get('/:visitId', async (req: AuthedRequest, res) => {
  const { visitId } = req.params as { visitId: string };
  const scorecard = await getScorecardByVisit(visitId, req.user!.clientId);
  res.status(200).json(scorecard);
});
