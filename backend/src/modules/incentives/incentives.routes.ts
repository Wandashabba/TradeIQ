import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  computeEarnedIncentives,
  createScheme,
  deleteScheme,
  findSchemeForClient,
  isIncentiveMetric,
  listSchemes,
  updateScheme,
} from './incentives.service';

export const incentivesRouter = Router();
incentivesRouter.use(requireAuth);

incentivesRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, metric, threshold, rewardPoints, rewardDetail } = req.body as {
    name?: unknown;
    metric?: unknown;
    threshold?: unknown;
    rewardPoints?: unknown;
    rewardDetail?: unknown;
  };

  if (
    typeof name !== 'string' ||
    name.length === 0 ||
    !isIncentiveMetric(metric) ||
    typeof threshold !== 'number' ||
    !Number.isFinite(threshold) ||
    typeof rewardPoints !== 'number' ||
    !Number.isInteger(rewardPoints) ||
    (rewardDetail !== undefined && typeof rewardDetail !== 'string')
  ) {
    res.status(400).json({
      error:
        'name (non-empty), metric (scorecard|tasks_closed|visits), threshold (number), and rewardPoints (integer) are required; rewardDetail must be a string when given',
    });
    return;
  }

  const scheme = await createScheme({
    clientId: req.user!.clientId,
    name,
    metric,
    threshold,
    rewardPoints,
    rewardDetail,
  });
  res.status(201).json(scheme);
});

incentivesRouter.get('/', async (req: AuthedRequest, res) => {
  const schemes = await listSchemes(req.user!.clientId);
  res.status(200).json(schemes);
});

incentivesRouter.get('/earned', async (req: AuthedRequest, res) => {
  const earned = await computeEarnedIncentives(req.user!.clientId);
  res.status(200).json(earned);
});

incentivesRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, threshold, rewardPoints, rewardDetail, active } = req.body as {
    name?: unknown;
    threshold?: unknown;
    rewardPoints?: unknown;
    rewardDetail?: unknown;
    active?: unknown;
  };

  if (
    (name !== undefined && (typeof name !== 'string' || name.length === 0)) ||
    (threshold !== undefined && (typeof threshold !== 'number' || !Number.isFinite(threshold))) ||
    (rewardPoints !== undefined && (typeof rewardPoints !== 'number' || !Number.isInteger(rewardPoints))) ||
    (rewardDetail !== undefined && typeof rewardDetail !== 'string') ||
    (active !== undefined && typeof active !== 'boolean')
  ) {
    res.status(400).json({
      error:
        'name must be a non-empty string, threshold a number, rewardPoints an integer, rewardDetail a string, and active a boolean',
    });
    return;
  }
  if (
    name === undefined &&
    threshold === undefined &&
    rewardPoints === undefined &&
    rewardDetail === undefined &&
    active === undefined
  ) {
    res.status(400).json({
      error: 'At least one of name, threshold, rewardPoints, rewardDetail, or active is required',
    });
    return;
  }

  const { id } = req.params as { id: string };
  const scheme = await findSchemeForClient(id, req.user!.clientId);
  const updated = await updateScheme(scheme.id, {
    name: name as string | undefined,
    threshold: threshold as number | undefined,
    rewardPoints: rewardPoints as number | undefined,
    rewardDetail: rewardDetail as string | undefined,
    active: active as boolean | undefined,
  });
  res.status(200).json(updated);
});

incentivesRouter.delete('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const scheme = await findSchemeForClient(id, req.user!.clientId);
  await deleteScheme(scheme.id);
  res.status(204).send();
});
