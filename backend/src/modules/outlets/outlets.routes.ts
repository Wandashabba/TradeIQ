import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  OUTLET_STATUSES,
  createOutlet,
  getOutletDetail,
  listOutletsForClient,
  listPinDisputes,
  updateOutlet,
} from './outlets.service';

export const outletsRouter = Router();

// All authenticated roles can read outlets (field agents pick one to visit),
// but provisioning an outlet is a management action.
outletsRouter.use(requireAuth);

outletsRouter.get('/', async (req: AuthedRequest, res) => {
  // `?mine=true` narrows to the caller's assigned territories. Opt-in on
  // purpose: the app asks for it as a default view, but any client can still
  // see every outlet in the tenant, because being unable to check in at a
  // store you are standing in is a worse failure than a long list.
  const mine = req.query.mine === 'true';
  const { limit, cursor } = parsePagination(req);
  const page = await listOutletsForClient({
    clientId: req.user!.clientId,
    assignedTo: mine ? req.user!.userId : undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

outletsRouter.post('/', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { name, code, channelType, lat, lng, territoryId, teamProfile } = req.body as {
    name?: string;
    code?: string;
    channelType?: string;
    lat?: number;
    lng?: number;
    territoryId?: string;
    teamProfile?: unknown;
  };

  if (!name || !code || !channelType || lat === undefined || lng === undefined || !territoryId) {
    res.status(400).json({ error: 'name, code, channelType, lat, lng, and territoryId are required' });
    return;
  }

  try {
    const outlet = await createOutlet({
      name,
      code,
      channelType,
      lat,
      lng,
      territoryId,
      teamProfile: teamProfile as Prisma.InputJsonValue,
      clientId: req.user!.clientId,
    });
    res.status(201).json(outlet);
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      res.status(409).json({ error: 'An outlet with this code already exists' });
      return;
    }
    throw err;
  }
});

// ── The repair path (#386) ────────────────────────────────────────────────

// The zod issue list the 400 envelope carries, as competitorPrices.routes.ts
// spells it: `{ error, issues }`, one line per failed field path.
function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

/**
 * GET /outlets/pin-disputes — the manager's queue of "the pin is wrong" claims.
 *
 * Registered BEFORE `/:id`, or Express reads "pin-disputes" as an outlet id and
 * this route is unreachable.
 *
 * Supervisory, so managers/admins only. An agent reading the queue would be
 * reading colleagues' positions and the notes they wrote about them.
 */
outletsRouter.get('/pin-disputes', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { status, outletId } = req.query as { status?: unknown; outletId?: unknown };

  // Rejected rather than coerced, like GET /fraud/flagged's `reviewed`: a
  // silently ignored `status=pending` would hand back the open queue while the
  // caller believed they were reading something else.
  if (
    status !== undefined &&
    (typeof status !== 'string' || !['open', 'applied', 'rejected', 'all'].includes(status))
  ) {
    res.status(400).json({ error: "status must be 'open', 'applied', 'rejected' or 'all'" });
    return;
  }
  if (outletId !== undefined && typeof outletId !== 'string') {
    res.status(400).json({ error: 'outletId must be a string' });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  res.status(200).json(
    await listPinDisputes({
      clientId: req.user!.clientId,
      status: status as string | undefined,
      outletId: outletId as string | undefined,
      limit,
      cursor,
    }),
  );
});

/**
 * GET /outlets/:id — one outlet, with the evidence about its pin (#386).
 *
 * Managers/admins: the body carries agents' recorded positions and the notes
 * they wrote, which is supervisory data, not reference data. Agents keep the
 * list at GET /outlets, which is unchanged.
 *
 * 404 for another tenant's id, never 403 — a 403 confirms the id exists
 * somewhere, which is an existence oracle across tenants.
 */
outletsRouter.get('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  res.status(200).json(await getOutletDetail(id, req.user!.clientId));
});

/**
 * PATCH /outlets/:id — correct a wrongly pinned outlet (#386).
 *
 * The missing half of the product. `POST /outlets` took the phone's current
 * position as the only possible source of an outlet's coordinates, so forty
 * stores onboarded at the depot were forty stores pinned to the depot car park,
 * and no screen or endpoint anywhere could change the number afterwards.
 *
 * Coordinates come from exactly one of two places, and the request must say
 * which:
 *
 *  - `lat` + `lng` — a manager typing the real numbers in;
 *  - `fromAttemptId` — "use the agent's recorded position", where the numbers
 *    are read out of that CheckInAttempt row SERVER-SIDE. Sending both is a 400
 *    rather than a precedence rule, because a body carrying both could make the
 *    ledger say "moved to the agent's recorded position" beside coordinates
 *    that were never any agent's position.
 *
 * `.strict()`, so a manager whose client misspells `lng` as `long` is told,
 * rather than silently having the outlet left where it was and being shown a
 * 200 that reads like success.
 *
 * Management action, like POST. Field agents are deliberately excluded: an
 * agent who could both file a pin dispute and grant it would be able to move
 * any outlet's fence to wherever they happen to be standing, which is the whole
 * check-in control, deleted.
 */
const patchBody = z
  .object({
    name: z.string().trim().min(1).max(200).optional(),
    lat: z.number().finite().min(-90).max(90).optional(),
    lng: z.number().finite().min(-180).max(180).optional(),
    status: z.enum(OUTLET_STATUSES).optional(),
    fromAttemptId: z.string().min(1).max(64).optional(),
    disputeId: z.string().min(1).max(64).optional(),
    resolutionNote: z.string().trim().max(2000).optional(),
  })
  .strict();

outletsRouter.patch('/:id', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const parsed = patchBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({
      error:
        'name, lat, lng, status (active|closed), fromAttemptId, disputeId and ' +
        'resolutionNote are the only accepted fields',
      issues: issues(parsed.error),
    });
    return;
  }

  const body = parsed.data;

  // lat and lng move together or not at all. Accepting one alone would write a
  // coordinate pair half of which is the old pin — a point that is not the
  // store and was never anybody's intention.
  if ((body.lat === undefined) !== (body.lng === undefined)) {
    res.status(400).json({ error: 'lat and lng must be given together' });
    return;
  }
  if (body.lat !== undefined && body.fromAttemptId !== undefined) {
    res.status(400).json({
      error:
        'Give either lat/lng or fromAttemptId, not both — the pin has one source ' +
        'and the audit trail records which it was',
    });
    return;
  }
  if (Object.keys(body).length === 0) {
    res.status(400).json({ error: 'Nothing to change' });
    return;
  }

  const result = await updateOutlet({
    outletId: (req.params as { id: string }).id,
    clientId: req.user!.clientId,
    userId: req.user!.userId,
    name: body.name,
    status: body.status,
    lat: body.lat,
    lng: body.lng,
    fromAttemptId: body.fromAttemptId,
    disputeId: body.disputeId,
    // Trimmed to nothing is nothing — the wire never says "there is a note"
    // about a blank string.
    resolutionNote: body.resolutionNote && body.resolutionNote.length > 0 ? body.resolutionNote : undefined,
  });

  res.status(200).json({ ...result.outlet, dispute: result.dispute });
});
