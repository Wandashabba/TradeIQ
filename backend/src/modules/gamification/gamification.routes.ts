import { Response, Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import {
  LeaderboardOptions,
  RECENT_ENTRIES_LIMIT,
  computeLeaderboard,
  getAgentLeaderboardEntry,
  getAgentPointsHistory,
} from './gamification.service';
import { listLedgerEntries } from './pointsLedger';

export const gamificationRouter = Router();
gamificationRouter.use(requireAuth);

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

/**
 * Parse optional `from`/`to` ISO query params into a leaderboard window.
 * Returns null and sends a 400 when a supplied value is not a valid date.
 */
function parseWindow(req: AuthedRequest, res: Response): LeaderboardOptions | null {
  const window: LeaderboardOptions = {};

  const fromRaw = queryString(req.query.from);
  if (fromRaw !== undefined) {
    const from = new Date(fromRaw);
    if (Number.isNaN(from.getTime())) {
      res.status(400).json({ error: 'from must be a valid ISO date' });
      return null;
    }
    window.from = from;
  }

  const toRaw = queryString(req.query.to);
  if (toRaw !== undefined) {
    const to = new Date(toRaw);
    if (Number.isNaN(to.getTime())) {
      res.status(400).json({ error: 'to must be a valid ISO date' });
      return null;
    }
    window.to = to;
  }

  return window;
}

gamificationRouter.get('/leaderboard', async (req: AuthedRequest, res: Response) => {
  const window = parseWindow(req, res);
  if (window === null) {
    return;
  }
  const leaderboard = await computeLeaderboard(req.user!.clientId, window);
  res.status(200).json(leaderboard);
});

/**
 * The caller's leaderboard entry plus `recentEntries`: the latest ledger rows
 * in the window — "how I earned these". Callers who are not field agents are
 * never ranked, so they get an empty history to match their zeroed entry.
 */
gamificationRouter.get('/me', async (req: AuthedRequest, res: Response) => {
  const window = parseWindow(req, res);
  if (window === null) {
    return;
  }
  const { clientId, userId, role } = req.user!;
  const [entry, recent] = await Promise.all([
    getAgentLeaderboardEntry(clientId, userId, window),
    role === 'field_agent'
      ? listLedgerEntries({ clientId, agentId: userId, ...window, limit: RECENT_ENTRIES_LIMIT })
      : Promise.resolve({ data: [] }),
  ]);
  res.status(200).json({ ...entry, recentEntries: recent.data });
});

/** One field agent's ledger entries, newest first, for the leaderboard drill-down. */
gamificationRouter.get(
  '/agents/:agentId/points',
  requireRole('manager', 'admin'),
  async (req: AuthedRequest, res: Response) => {
    const window = parseWindow(req, res);
    if (window === null) {
      return;
    }
    const { limit, cursor } = parsePagination(req, RECENT_ENTRIES_LIMIT);
    const { agentId } = req.params as { agentId: string };
    const history = await getAgentPointsHistory({
      clientId: req.user!.clientId,
      agentId,
      ...window,
      limit,
      cursor,
    });
    res.status(200).json(history);
  },
);
