import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { parsePagination } from '../../lib/pagination';
import { parseMonth } from './salesMonth';
import {
  MAX_TARGET_UNITS,
  SALES_TARGET_SCOPES,
  SalesTargetScope,
  deleteSalesTarget,
  getSalesAttainment,
  importSalesTargets,
  listSalesTargets,
  upsertSalesTarget,
} from './salesTargets.service';

export const salesTargetsRouter = Router();
salesTargetsRouter.use(requireAuth);

// Targets are a planning construct and attainment is a management view, so the
// whole router is manager/admin. A field agent gets 403 on every route —
// including the read-only ones — rather than a partial view of quotas.
salesTargetsRouter.use(requireRole('manager', 'admin'));

function optionalString(value: unknown): string | undefined | null {
  if (value === undefined) return undefined;
  return typeof value === 'string' && value.length > 0 ? value : null;
}

salesTargetsRouter.get('/', async (req: AuthedRequest, res) => {
  const { month: monthRaw, skuId, territoryId, outletId, scope } = req.query as Record<string, unknown>;

  const month = monthRaw === undefined ? undefined : parseMonth(monthRaw);
  if (monthRaw !== undefined && month === undefined) {
    res.status(400).json({ error: 'month must be YYYY-MM' });
    return;
  }
  const filters = { skuId: optionalString(skuId), territoryId: optionalString(territoryId), outletId: optionalString(outletId) };
  if (Object.values(filters).some((value) => value === null)) {
    res.status(400).json({ error: 'skuId, territoryId and outletId must be non-empty strings when given' });
    return;
  }
  if (scope !== undefined && !SALES_TARGET_SCOPES.includes(scope as SalesTargetScope)) {
    res.status(400).json({ error: `scope must be one of ${SALES_TARGET_SCOPES.join(', ')}` });
    return;
  }

  const { limit, cursor } = parsePagination(req);
  const page = await listSalesTargets({
    clientId: req.user!.clientId,
    month,
    skuId: filters.skuId ?? undefined,
    territoryId: filters.territoryId ?? undefined,
    outletId: filters.outletId ?? undefined,
    scope: scope as SalesTargetScope | undefined,
    limit,
    cursor,
  });
  res.status(200).json(page);
});

// Registered before nothing that could shadow it, but kept above the `:id`
// route anyway so a future `GET /:id` cannot swallow the word.
salesTargetsRouter.get('/attainment', async (req: AuthedRequest, res) => {
  // No `month` asks for the current one, and whose "current" it is matters: the
  // service reads it off the client's own wall clock (#339), never the calling
  // device's. The dashboard omits it for exactly that reason; the Sales targets
  // screen, which has a month picker, always sends one. A month that *is* sent
  // still has to be well formed — a typo should not silently become this month.
  const monthRaw = req.query.month;
  const month = monthRaw === undefined ? undefined : parseMonth(monthRaw);
  if (monthRaw !== undefined && month === undefined) {
    res.status(400).json({ error: 'month must be YYYY-MM' });
    return;
  }
  const skuId = optionalString(req.query.skuId);
  if (skuId === null) {
    res.status(400).json({ error: 'skuId must be a non-empty string when given' });
    return;
  }

  const report = await getSalesAttainment({ clientId: req.user!.clientId, month, skuId });
  res.status(200).json(report);
});

salesTargetsRouter.put('/', async (req: AuthedRequest, res) => {
  const body = (req.body ?? {}) as Record<string, unknown>;
  const month = parseMonth(body.month);
  const { skuId, targetUnits } = body;
  const territoryId = body.territoryId ?? null;
  const outletId = body.outletId ?? null;

  if (typeof skuId !== 'string' || skuId.length === 0 || month === undefined) {
    res.status(400).json({ error: 'skuId and month (YYYY-MM) are required' });
    return;
  }
  if (
    typeof targetUnits !== 'number' ||
    !Number.isInteger(targetUnits) ||
    targetUnits < 0 ||
    targetUnits > MAX_TARGET_UNITS
  ) {
    res.status(400).json({ error: `targetUnits must be a whole number from 0 to ${MAX_TARGET_UNITS}` });
    return;
  }
  const validScopeId = (value: unknown) => value === null || (typeof value === 'string' && value.length > 0);
  if (!validScopeId(territoryId) || !validScopeId(outletId)) {
    res.status(400).json({ error: 'territoryId and outletId must be non-empty strings or null' });
    return;
  }

  const { target, created } = await upsertSalesTarget({
    clientId: req.user!.clientId,
    userId: req.user!.userId,
    skuId,
    month,
    territoryId: territoryId as string | null,
    outletId: outletId as string | null,
    targetUnits,
  });
  res.status(created ? 201 : 200).json(target);
});

salesTargetsRouter.post('/import', async (req: AuthedRequest, res) => {
  const body = (req.body ?? {}) as Record<string, unknown>;
  if (typeof body.csv !== 'string') {
    res.status(400).json({ error: 'csv is required as the file contents in a string' });
    return;
  }
  if (body.dryRun !== undefined && typeof body.dryRun !== 'boolean') {
    res.status(400).json({ error: 'dryRun must be a boolean' });
    return;
  }
  // A preview is asked for either way; the query form suits a quick curl.
  const dryRun = body.dryRun === true || req.query.dryRun === 'true';

  const result = await importSalesTargets({
    clientId: req.user!.clientId,
    userId: req.user!.userId,
    csv: body.csv,
    dryRun,
  });
  res.status(200).json(result);
});

salesTargetsRouter.delete('/:id', async (req: AuthedRequest, res) => {
  const { id } = req.params as { id: string };
  await deleteSalesTarget(id, req.user!.clientId);
  res.status(204).end();
});
