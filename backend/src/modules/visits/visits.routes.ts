import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  MAX_CLIENT_VISIT_ID_LENGTH,
  checkIn,
  getVisitDetail,
  listVisits,
  submitVisit,
} from './visits.service';

const VISIT_STATUSES = ['in_progress', 'submitted'] as const;
type VisitStatusFilter = (typeof VISIT_STATUSES)[number];

function isVisitStatus(value: string): value is VisitStatusFilter {
  return (VISIT_STATUSES as readonly string[]).includes(value);
}

export const visitsRouter = Router();
visitsRouter.use(requireAuth);

// The same shape `POST /messages` accepts for `clientMessageId` (#308), and for
// the same reason: the key is a device-minted uuid, and anything that is not
// one is a client bug worth surfacing rather than storing.
const CLIENT_VISIT_ID_RE = /^[A-Za-z0-9._:-]+$/;

// Check-in is a field-agent action. Relax this guard if managers/admins ever
// need to record visits directly.
//
// Idempotency (#379, #385) rides in the body as `clientVisitId`, not an
// `Idempotency-Key` header: the key is stored on the visit and belongs to it,
// and the app already builds this body. 201 when this request created the
// visit; 200 with the ORIGINAL visit (plus `deduplicated: true` and an
// `Idempotent-Replayed` header) when an earlier request already had. Both
// bodies are a visit with an `id`, so an older client — which sends no key and
// only reads `id` — is unaffected in either direction.
visitsRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { outletId, lat, lng, checkinTs, clientVisitId, resumed } = req.body as {
    outletId?: string;
    lat?: number;
    lng?: number;
    checkinTs?: string;
    clientVisitId?: unknown;
    resumed?: unknown;
  };

  if (!outletId || lat === undefined || lng === undefined) {
    res.status(400).json({ error: 'outletId, lat, and lng are required' });
    return;
  }

  if (
    clientVisitId !== undefined &&
    (typeof clientVisitId !== 'string' ||
      clientVisitId.length === 0 ||
      clientVisitId.length > MAX_CLIENT_VISIT_ID_LENGTH ||
      !CLIENT_VISIT_ID_RE.test(clientVisitId))
  ) {
    res.status(400).json({
      error:
        `clientVisitId must be 1-${MAX_CLIENT_VISIT_ID_LENGTH} characters of ` +
        'letters, digits, ".", "_", ":" or "-" (a UUID works) when given',
    });
    return;
  }

  if (resumed !== undefined && typeof resumed !== 'boolean') {
    res.status(400).json({ error: 'resumed must be a boolean when given' });
    return;
  }

  const { visit, deduplicated } = await checkIn({
    outletId,
    lat,
    lng,
    checkinTs,
    clientVisitId: clientVisitId as string | undefined,
    resumed: resumed as boolean | undefined,
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
  });
  if (deduplicated) {
    res.set('Idempotent-Replayed', 'true');
  }
  res.status(deduplicated ? 200 : 201).json({ ...visit, deduplicated });
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
