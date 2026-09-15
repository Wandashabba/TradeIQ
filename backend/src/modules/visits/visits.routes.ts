import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import { checkIn, getVisitDetail, listVisits, submitVisit } from './visits.service';

const VISIT_STATUSES = ['in_progress', 'submitted'] as const;
type VisitStatusFilter = (typeof VISIT_STATUSES)[number];

function isVisitStatus(value: string): value is VisitStatusFilter {
  return (VISIT_STATUSES as readonly string[]).includes(value);
}

export const visitsRouter = Router();
visitsRouter.use(requireAuth);

// Check-in is a field-agent action. Relax this guard if managers/admins ever
// need to record visits directly.
visitsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { outletId, lat, lng, checkinTs } = req.body as {
    outletId?: string;
    lat?: number;
    lng?: number;
    checkinTs?: string;
  };

  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }

  const visit = await checkIn({
    outletId,
    lat,
    lng,
    checkinTs,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  res.status(201).json(visit);
});

visitsRouter.post('/:id/submit', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const { submittedAtClient } = (req.body ?? {}) as { submittedAtClient?: unknown };
  const visit = await submitVisit({
    visitId: id,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    // The device's own completion time, so dwell can be measured on one clock (#101).
    submittedAtClient:
      typeof submittedAtClient === 'string' ? submittedAtClient : undefined,
  });
  res.status(200).json(visit);
});

// The manager's review of one visit (#208): outlet, agent, score, section
// summaries, photo metadata (never bytes) and fraud signals. A supervisory
// read, so managers/admins only; tenant-scoped, 404 for another client's visit.
// Registered as GET only, so it cannot shadow POST /:id/submit.
visitsRouter.get('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  const detail = await getVisitDetail(id, req.user!.clientId);
  res.status(200).json(detail);
});

// Any authenticated role may list visits. A field_agent is scoped to their own
// visits; managers/admins see the whole client's visits.
visitsRouter.get('/', async (req: AuthedRequest, res) => {
  const { outletId, status } = req.query as { outletId?: unknown; status?: unknown };

  if (outletId !== undefined && typeof outletId !== 'string') {
    res.status(400).json({ error: 'outletId must be a string' });
    return;
  }
  if (status !== undefined && (typeof status !== 'string' || !isVisitStatus(status))) {
    res.status(400).json({ error: "status must be 'in_progress' or 'submitted'" });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listVisits({
    clientId: req.user!.clientId,
    role: req.user!.role,
    agentId: req.user!.userId,
    outletId,
    status,
    limit,
    cursor,
  });
  res.status(200).json(page);
});
