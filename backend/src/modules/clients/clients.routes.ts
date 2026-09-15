import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { isValidTimeZone } from '../../lib/clientTime';
import { getClientConfig, updateClientConfig, type UpdateClientConfigInput } from './clients.service';

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

// Managers reach this route for `timezone` only; the scoring config stays
// admin-only (checked per field below). A timezone is a fact about where the
// team works — the manager who runs the team is the one who knows it — while
// weights and thresholds are scoring policy.
clientsRouter.patch('/me', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { scorecardWeights, kpiThresholds, timezone } = req.body as {
    scorecardWeights?: unknown;
    kpiThresholds?: unknown;
    timezone?: unknown;
  };

  if (scorecardWeights === undefined && kpiThresholds === undefined && timezone === undefined) {
    res
      .status(400)
      .json({ error: 'At least one of scorecardWeights, kpiThresholds or timezone is required' });
    return;
  }

  // Before any validation, so a manager learns "not yours" rather than being
  // coached through a payload they could never save.
  if ((scorecardWeights !== undefined || kpiThresholds !== undefined) && req.user!.role !== 'admin') {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }

  // Exact canonical IANA names only (see isValidTimeZone): an offset like
  // "+02:00" has no DST rules, and a lower-cased or aliased name would be
  // stored as something no other system reads back as the same zone.
  if (timezone !== undefined && !isValidTimeZone(timezone)) {
    res.status(400).json({
      error: 'timezone must be an IANA timezone name, e.g. Africa/Johannesburg',
    });
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

  if (kpiThresholds !== undefined) {
    if (!isPlainObject(kpiThresholds)) {
      res.status(400).json({ error: 'kpiThresholds must be a non-null, non-array object' });
      return;
    }
    // Every consumer (kpiThreshold(), the scorecard RAG bands) reads these as
    // numbers and silently falls back to a default on anything else — so a
    // non-numeric threshold would look accepted while doing nothing. Reject it.
    const allThresholdsValid = Object.values(kpiThresholds).every(
      (threshold) => typeof threshold === 'number' && Number.isFinite(threshold),
    );
    if (!allThresholdsValid) {
      res.status(400).json({ error: 'kpiThresholds values must be finite numbers' });
      return;
    }
  }

  const data: UpdateClientConfigInput = {};
  if (scorecardWeights !== undefined) {
    data.scorecardWeights = scorecardWeights as Prisma.InputJsonValue;
  }
  if (kpiThresholds !== undefined) {
    data.kpiThresholds = kpiThresholds as Prisma.InputJsonValue;
  }
  if (timezone !== undefined) {
    data.timezone = timezone;
  }

  const client = await updateClientConfig(req.user!.clientId, data);
  res.status(200).json(client);
});
