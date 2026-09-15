import { Response, Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import { CONTEST_EVENT_TYPES, isContestEventType, parseCalendarDate } from './contestRules';
import {
  ContestPatch,
  cancelContest,
  createContest,
  deleteContest,
  getContest,
  getContestStandings,
  listContests,
  listCurrentContests,
  updateContest,
} from './contests.service';

/**
 * Time-boxed contests over the points ledger (#124).
 *
 * `GET /contests/current` is the agent's view and open to every signed-in
 * user, like the leaderboard. Everything else — the list, CRUD, cancel and
 * full standings — is manager/admin.
 */
export const contestsRouter = Router();
contestsRouter.use(requireAuth);

const managerOnly = requireRole('manager', 'admin');

export const CONTEST_NAME_MAX = 120;
export const CONTEST_TEXT_MAX = 2000;

type Parsed = { value: ContestPatch } | { error: string };

/**
 * Shape-checks a create (`partial` false) or edit (`partial` true) body.
 * Blank description/prize strings become null. Duplicate event types collapse
 * and keep the canonical order. Business rules — dates in order after a
 * merge, the territory belonging to the tenant — are the service's.
 */
function parseContestBody(raw: unknown, partial: boolean): Parsed {
  const body = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const value: ContestPatch = {};

  if (!partial || body.name !== undefined) {
    if (typeof body.name !== 'string' || body.name.trim().length === 0) {
      return { error: partial ? 'name must be a non-empty string' : 'name is required' };
    }
    if (body.name.trim().length > CONTEST_NAME_MAX) {
      return { error: `name must be at most ${CONTEST_NAME_MAX} characters` };
    }
    value.name = body.name.trim();
  }

  for (const key of ['description', 'prizeDescription'] as const) {
    const field = body[key];
    if (field === undefined) {
      continue;
    }
    if (field !== null && typeof field !== 'string') {
      return { error: `${key} must be a string or null` };
    }
    if (typeof field === 'string' && field.length > CONTEST_TEXT_MAX) {
      return { error: `${key} must be at most ${CONTEST_TEXT_MAX} characters` };
    }
    const trimmed = typeof field === 'string' ? field.trim() : '';
    value[key] = trimmed.length > 0 ? trimmed : null;
  }

  for (const key of ['startDate', 'endDate'] as const) {
    if (partial && body[key] === undefined) {
      continue;
    }
    const date = parseCalendarDate(body[key]);
    if (!date) {
      return { error: `${key} must be a calendar date (YYYY-MM-DD)` };
    }
    value[key] = date;
  }

  if (body.territoryId !== undefined) {
    const territoryId = body.territoryId;
    if (territoryId !== null && (typeof territoryId !== 'string' || territoryId.length === 0)) {
      return { error: 'territoryId must be a territory id or null' };
    }
    value.territoryId = territoryId;
  }

  if (body.eventTypes !== undefined) {
    const eventTypes = body.eventTypes === null ? [] : body.eventTypes;
    if (!Array.isArray(eventTypes) || !eventTypes.every(isContestEventType)) {
      return { error: `eventTypes must be an array of: ${CONTEST_EVENT_TYPES.join(', ')}` };
    }
    value.eventTypes = CONTEST_EVENT_TYPES.filter((type) => eventTypes.includes(type));
  }

  if (partial && Object.keys(value).length === 0) {
    return { error: 'at least one updatable field is required' };
  }
  return { value };
}

function send400(res: Response, parsed: Parsed): parsed is { error: string } {
  if ('error' in parsed) {
    res.status(400).json({ error: parsed.error });
    return true;
  }
  return false;
}

// Declared before `/:id` so `current` is never read as an id.
contestsRouter.get('/current', async (req: AuthedRequest, res) => {
  const { clientId, userId, role } = req.user!;
  res.status(200).json(await listCurrentContests({ clientId, userId, role }));
});

contestsRouter.get('/', managerOnly, async (req: AuthedRequest, res) => {
  const { limit, cursor } = parsePagination(req);
  res.status(200).json(await listContests({ clientId: req.user!.clientId, limit, cursor }));
});

contestsRouter.post('/', managerOnly, async (req: AuthedRequest, res) => {
  const parsed = parseContestBody(req.body, false);
  if (send400(res, parsed)) {
    return;
  }
  const v = parsed.value;
  const contest = await createContest(req.user!.clientId, req.user!.userId, {
    name: v.name!,
    description: v.description ?? null,
    prizeDescription: v.prizeDescription ?? null,
    startDate: v.startDate!,
    endDate: v.endDate!,
    territoryId: v.territoryId ?? null,
    eventTypes: v.eventTypes ?? [],
  });
  res.status(201).json(contest);
});

contestsRouter.get('/:id', managerOnly, async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  res.status(200).json(await getContest(id, req.user!.clientId));
});

contestsRouter.patch('/:id', managerOnly, async (req: AuthedRequest, res) => {
  const parsed = parseContestBody(req.body, true);
  if (send400(res, parsed)) {
    return;
  }
  const { id } = req.params as { id: string };
  res.status(200).json(await updateContest(id, req.user!.clientId, parsed.value));
});

contestsRouter.delete('/:id', managerOnly, async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  await deleteContest(id, req.user!.clientId);
  res.status(204).send();
});

contestsRouter.post('/:id/cancel', managerOnly, async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  res.status(200).json(await cancelContest(id, req.user!.clientId));
});

contestsRouter.get('/:id/standings', managerOnly, async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  res.status(200).json(await getContestStandings(id, req.user!.clientId));
});
