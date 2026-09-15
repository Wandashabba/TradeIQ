import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  BENCHMARK_METRICS,
  TrendFilters,
  TrendInterval,
  getAvailabilityTrend,
  getPerfectStoreTrend,
  getScorecardsTrend,
  getShareOfShelfTrend,
  getTerritoryBenchmark,
  isBenchmarkMetric,
} from './trends.service';

export const trendsRouter = Router();
trendsRouter.use(requireAuth);

function queryString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

type ParseResult =
  | { ok: true; value: Omit<TrendFilters, 'clientId'> }
  | { ok: false; error: string };

function parseQuery(req: AuthedRequest): ParseResult {
  const intervalRaw = queryString(req.query.interval) ?? 'week';
  if (intervalRaw !== 'day' && intervalRaw !== 'week') {
    return { ok: false, error: "interval must be 'day' or 'week'" };
  }
  const interval: TrendInterval = intervalRaw;

  const fromRaw = queryString(req.query.from);
  let from: Date | undefined;
  if (fromRaw !== undefined) {
    from = new Date(fromRaw);
    if (Number.isNaN(from.getTime())) {
      return { ok: false, error: 'from must be a valid ISO date' };
    }
  }

  const toRaw = queryString(req.query.to);
  let to: Date | undefined;
  if (toRaw !== undefined) {
    to = new Date(toRaw);
    if (Number.isNaN(to.getTime())) {
      return { ok: false, error: 'to must be a valid ISO date' };
    }
  }

  // A Territory.id; the service resolves it to the code outlets carry.
  const territoryId = queryString(req.query.territoryId);

  return { ok: true, value: { interval, from, to, territoryId } };
}

type TrendHandler = (filters: TrendFilters) => Promise<unknown>;

/** Wire a trend endpoint: manager/admin only, scoped to the caller's client. */
function trendRoute(path: string, handler: TrendHandler): void {
  trendsRouter.get(path, requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
    const parsed = parseQuery(req);
    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error });
      return;
    }
    const series = await handler({ clientId: req.user!.clientId, ...parsed.value });
    res.status(200).json(series);
  });
}

trendRoute('/scorecards', getScorecardsTrend);
trendRoute('/availability', getAvailabilityTrend);
trendRoute('/perfect-store', getPerfectStoreTrend);
trendRoute('/share-of-shelf', getShareOfShelfTrend);

// Every territory of the caller's client against the client-wide line (#123).
trendsRouter.get('/benchmark', requireRole('manager', 'admin'), async (req: AuthedRequest, res) => {
  const metric = queryString(req.query.metric);
  if (metric === undefined || !isBenchmarkMetric(metric)) {
    res.status(400).json({ error: `metric must be one of ${BENCHMARK_METRICS.join(', ')}` });
    return;
  }
  const parsed = parseQuery(req);
  if (!parsed.ok) {
    res.status(400).json({ error: parsed.error });
    return;
  }
  if (parsed.value.territoryId !== undefined) {
    // The benchmark is every territory by definition; a filter here would be
    // silently ignored, so refuse it instead.
    res.status(400).json({ error: 'territoryId is not supported on /trends/benchmark' });
    return;
  }
  const { interval, from, to } = parsed.value;
  const report = await getTerritoryBenchmark({
    clientId: req.user!.clientId,
    metric,
    interval,
    from,
    to,
  });
  res.status(200).json(report);
});
