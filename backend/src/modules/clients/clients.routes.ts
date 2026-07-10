import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { getClientConfig, updateClientConfig } from './clients.service';

export const clientsRouter = Router();
clientsRouter.use(requireAuth);

// A non-null, non-array plain object — the shape both Json config columns must
// take, and the only thing Prisma's Json input accepts for a nested record.
function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

clientsRouter.get('/me', async (req: AuthedRequest, res) => {
  const client = await getClientConfig(req.user!.clientId);
  res.status(200).json(client);
});

clientsRouter.patch('/me', requireRole('admin'), async (req: AuthedRequest, res) => {
  const { scorecardWeights, kpiThresholds } = req.body as {
    scorecardWeights?: unknown;
    kpiThresholds?: unknown;
  };

  if (scorecardWeights === undefined && kpiThresholds === undefined) {
    res.status(400).json({ error: 'At least one of scorecardWeights or kpiThresholds is required' });
    return;
  }

  if (scorecardWeights !== undefined) {
    if (!isPlainObject(scorecardWeights)) {
      res.status(400).json({ error: 'scorecardWeights must be a non-null, non-array object' });
      return;
    }
    const allWeightsValid = Object.values(scorecardWeights).every(
      (weight) => typeof weight === 'number' && Number.isFinite(weight) && weight >= 0,
    );
    if (!allWeightsValid) {
      res.status(400).json({ error: 'scorecardWeights values must be finite numbers >= 0' });
      return;
    }
  }

  if (kpiThresholds !== undefined && !isPlainObject(kpiThresholds)) {
    res.status(400).json({ error: 'kpiThresholds must be a non-null, non-array object' });
    return;
  }

  const data: {
    scorecardWeights?: Prisma.InputJsonValue;
    kpiThresholds?: Prisma.InputJsonValue;
  } = {};
  if (scorecardWeights !== undefined) {
    data.scorecardWeights = scorecardWeights as Prisma.InputJsonValue;
  }
  if (kpiThresholds !== undefined) {
    data.kpiThresholds = kpiThresholds as Prisma.InputJsonValue;
  }

  const client = await updateClientConfig(req.user!.clientId, data);
  res.status(200).json(client);
});
