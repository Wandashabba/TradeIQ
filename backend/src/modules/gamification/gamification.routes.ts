import { Response, Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import {
  LeaderboardOptions,
  computeLeaderboard,
  getAgentLeaderboardEntry,
} from './gamification.service';

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

gamificationRouter.get('/me', async (req: AuthedRequest, res: Response) => {
  const window = parseWindow(req, res);
  if (window === null) {
    return;
  }
  const entry = await getAgentLeaderboardEntry(req.user!.clientId, req.user!.userId, window);
  res.status(200).json(entry);
});
