import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import type { Recurrence } from './recurrence';
import { parsePagination } from '../../lib/pagination';
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
  const { agentId, name, scheduledDate, territoryId, outletIds, recurrence } = req.body as {
    agentId?: unknown;
    name?: unknown;
    scheduledDate?: unknown;
    territoryId?: unknown;
    outletIds?: unknown;
    recurrence?: unknown;
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

  // A recurrence is optional, but a MALFORMED one is a 400 rather than a
  // silently-dropped field: quietly creating a one-off when the manager asked
  // for a weekly series is the failure they would not notice until the week
  // they expected a route and got none. The date arithmetic itself validates
  // interval/daysOfWeek/until and throws ValidationError — see recurrence.ts.
  let parsedRecurrence: Recurrence | undefined;
  if (recurrence !== undefined) {
    if (typeof recurrence !== 'object' || recurrence === null || Array.isArray(recurrence)) {
      res.status(400).json({ error: 'recurrence must be an object when given' });
      return;
    }
    const r = recurrence as Record<string, unknown>;
    if (r.frequency !== 'daily' && r.frequency !== 'weekly') {
      res.status(400).json({ error: "recurrence.frequency must be 'daily' or 'weekly'" });
      return;
    }
    if (typeof r.until !== 'string' || Number.isNaN(Date.parse(r.until))) {
      res.status(400).json({ error: 'recurrence.until must be an ISO-8601 date' });
      return;
    }
    if (r.interval !== undefined && typeof r.interval !== 'number') {
      res.status(400).json({ error: 'recurrence.interval must be a number when given' });
      return;
    }
    if (
      r.daysOfWeek !== undefined &&
      (!Array.isArray(r.daysOfWeek) || r.daysOfWeek.some((d) => typeof d !== 'number'))
    ) {
      res.status(400).json({ error: 'recurrence.daysOfWeek must be an array of numbers when given' });
      return;
    }
    parsedRecurrence = {
      frequency: r.frequency,
      // Defaulting to 1 rather than requiring it: "weekly" already means
      // "every 1 week" to everyone who is not writing an rrule.
      interval: (r.interval as number | undefined) ?? 1,
      daysOfWeek: r.daysOfWeek as number[] | undefined,
      until: new Date(r.until),
    };
  }

  const plan = await createBeatPlan({
    clientId: req.user!.clientId,
    agentId,
    name,
    scheduledDate,
    territoryId,
    // Validated as a non-empty array of strings above.
    outletIds: outletIds as string[],
    recurrence: parsedRecurrence,
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

  const { limit, cursor } = parsePagination(req);
  const page = await listBeatPlans({
    clientId: req.user!.clientId,
    role: req.user!.role,
    callerUserId: req.user!.userId,
    agentId,
    status,
    limit,
    cursor,
  });
  res.status(200).json(page);
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
