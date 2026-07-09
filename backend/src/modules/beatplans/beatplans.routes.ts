import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  BeatPlanStatus,
  createBeatPlan,
  getBeatPlan,
  listBeatPlans,
  updateBeatPlanStatus,
  updateStop,
} from './beatplans.service';

const BEAT_PLAN_STATUSES = ['planned', 'in_progress', 'completed'] as const;

function isBeatPlanStatus(value: string): value is BeatPlanStatus {
  return (BEAT_PLAN_STATUSES as readonly string[]).includes(value);
}

export const beatplansRouter = Router();
beatplansRouter.use(requireAuth);

// Planning is a manager/admin action. A field_agent executes plans (marks
// stops visited) but does not author them.
beatplansRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { agentId, name, scheduledDate, territoryId, outletIds } = req.body as {
    agentId?: unknown;
    name?: unknown;
    scheduledDate?: unknown;
    territoryId?: unknown;
    outletIds?: unknown;
  };

  const outletIdsValid =
    Array.isArray(outletIds) &&
    outletIds.length > 0 &&
    outletIds.every((id) => typeof id === 'string');

  if (
    typeof agentId !== 'string' ||
    typeof name !== 'string' ||
    name.length === 0 ||
    typeof scheduledDate !== 'string' ||
    Number.isNaN(Date.parse(scheduledDate)) ||
    (territoryId !== undefined && typeof territoryId !== 'string') ||
    !outletIdsValid
  ) {
    res.status(400).json({
      error:
        'agentId, name, scheduledDate (ISO) and a non-empty outletIds string array are required; territoryId must be a string when given',
    });
    return;
  }

  const plan = await createBeatPlan({
    clientId: req.user!.clientId,
    agentId,
    name,
    scheduledDate,
    territoryId,
    // Validated as a non-empty array of strings above.
    outletIds: outletIds as string[],
  });
  res.status(201).json(plan);
});

// Any authenticated role may list. A field_agent is scoped to their own plans;
// managers/admins see the whole client's plans (optionally filtered by agent).
beatplansRouter.get('/', async (req: AuthedRequest, res) => {
  const { agentId, status } = req.query as { agentId?: unknown; status?: unknown };

  if (agentId !== undefined && typeof agentId !== 'string') {
    res.status(400).json({ error: 'agentId must be a string' });
    return;
  }
  if (status !== undefined && (typeof status !== 'string' || !isBeatPlanStatus(status))) {
    res.status(400).json({ error: "status must be 'planned', 'in_progress' or 'completed'" });
    return;
  }

  const plans = await listBeatPlans({
    clientId: req.user!.clientId,
    role: req.user!.role,
    callerUserId: req.user!.userId,
    agentId,
    status,
  });
  res.status(200).json(plans);
});

beatplansRouter.get('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const plan = await getBeatPlan({
    id,
    clientId: req.user!.clientId,
    role: req.user!.role,
    callerUserId: req.user!.userId,
  });
  res.status(200).json(plan);
});

// A field_agent marks their own stops visited; managers/admins may update any
// stop within the client.
beatplansRouter.patch(
  '/:id/stops/:stopId',
  requireRole('field_agent', 'manager', 'admin'),
  async (req: AuthedRequest, res) => {
    const { visited } = req.body as { visited?: unknown };
    if (typeof visited !== 'boolean') {
      res.status(400).json({ error: 'visited must be a boolean' });
      return;
    }

    const { id, stopId } = req.params as { id: string; stopId: string };
    const stop = await updateStop({
      planId: id,
      stopId,
      clientId: req.user!.clientId,
      role: req.user!.role,
      callerUserId: req.user!.userId,
      visited,
    });
    res.status(200).json(stop);
  },
);

beatplansRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { status } = req.body as { status?: unknown };
  if (typeof status !== 'string' || !isBeatPlanStatus(status)) {
    res.status(400).json({ error: "status must be 'planned', 'in_progress' or 'completed'" });
    return;
  }

  const { id } = req.params as { id: string };
  const plan = await updateBeatPlanStatus({
    id,
    clientId: req.user!.clientId,
    status,
  });
  res.status(200).json(plan);
});
