import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  MAX_CLIENT_VISIT_ID_LENGTH,
  MAX_PIN_DISPUTE_NOTE_LENGTH,
  checkIn,
  getVisitDetail,
  listMyVisits,
  listVisits,
  submitVisit,
} from './visits.service';

/** "The last month of my work" — the window My visits opens on. An explicit
 *  ?limit= overrides it like any other list. */
const MY_VISITS_DEFAULT_LIMIT = 30;

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
  const { outletId, lat, lng, checkinTs, clientVisitId, resumed, pinDispute, accuracyM, isMocked } =
    req.body as {
      outletId?: string;
      lat?: number;
      lng?: number;
      checkinTs?: string;
      clientVisitId?: unknown;
      resumed?: unknown;
      pinDispute?: unknown;
      accuracyM?: unknown;
      isMocked?: unknown;
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

  // What the device says about the fix it just sent (#386 follow-up). Recorded,
  // never obeyed: neither value can make a failing check-in pass, and both are
  // optional so an older build is unaffected. A negative accuracy is not a
  // reading, and a non-finite one is not a number.
  if (
    accuracyM !== undefined &&
    (typeof accuracyM !== 'number' || !Number.isFinite(accuracyM) || accuracyM < 0)
  ) {
    res.status(400).json({ error: 'accuracyM must be a non-negative number of metres when given' });
    return;
  }
  if (isMocked !== undefined && typeof isMocked !== 'boolean') {
    res.status(400).json({ error: 'isMocked must be a boolean when given' });
    return;
  }

  // "The pin is wrong" (#386). Omitted by every older app build and by every
  // ordinary check-in, so nothing about this route's existing behaviour moves.
  //
  // Validated here rather than coerced: a client that sends `pinDispute: true`
  // meaning "yes, dispute it" must be told, not silently answered with an
  // ordinary rejection it will read as the app being broken.
  let pinDisputeInput: { note?: string } | undefined;
  if (pinDispute !== undefined) {
    if (typeof pinDispute !== 'object' || pinDispute === null || Array.isArray(pinDispute)) {
      res.status(400).json({
        error: 'pinDispute must be an object ({ note?: string }) when given',
      });
      return;
    }
    const { note } = pinDispute as { note?: unknown };
    if (
      note !== undefined &&
      note !== null &&
      (typeof note !== 'string' || note.trim().length > MAX_PIN_DISPUTE_NOTE_LENGTH)
    ) {
      res.status(400).json({
        error: `pinDispute.note must be a string of at most ${MAX_PIN_DISPUTE_NOTE_LENGTH} characters`,
      });
      return;
    }
    const trimmed = typeof note === 'string' ? note.trim() : '';
    // Trimmed to nothing is nothing: the row says null rather than claiming
    // there is a note when the agent typed only whitespace.
    pinDisputeInput = { note: trimmed.length > 0 ? trimmed : undefined };
  }

  const { visit, deduplicated } = await checkIn({
    outletId,
    lat,
    lng,
    checkinTs,
    clientVisitId: clientVisitId as string | undefined,
    resumed: resumed as boolean | undefined,
    pinDispute: pinDisputeInput,
    accuracyM: accuracyM as number | undefined,
    isMocked: isMocked as boolean | undefined,
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

// The caller's OWN visits (#383): where they were, when, how far from the
// door, how long, how much they captured, and what it scored.
//
// Self-scoped by construction. The agent id comes off the token and is not a
// parameter, so there is no query string that turns this into somebody else's
// record — which is the whole reason it is a separate route rather than a
// relaxed `?agentId=` on the list below. Open to every signed-in role because
// "my own work" is a coherent question for any of them; a manager with no
// visits gets an empty page rather than a 403.
//
// Registered BEFORE '/:id', which would otherwise read the word 'me' as a
// visit id and bounce a field agent off a manager-only guard.
visitsRouter.get('/me', async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req, MY_VISITS_DEFAULT_LIMIT);
  const page = await listMyVisits({
    clientId: req.user!.clientId,
    agentId: req.user!.userId,
    limit,
    cursor,
  });
  res.status(200).json(page);
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
