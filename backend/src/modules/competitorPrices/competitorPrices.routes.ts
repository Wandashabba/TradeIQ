import { Router } from 'express';
import { z } from 'zod';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { RETAILER_ADAPTERS } from './adapters';
import {
  createMapping,
  disableCollection,
  enableCollection,
  getCollectionSettings,
  listCollectionAudit,
  listMappings,
  updateMapping,
} from './competitorPrices.service';

/**
 * Competitor shelf-price administration. **Admin only, every route.**
 *
 * The switch is a legal gate, not a preference: enabling needs the name of
 * whoever signed off the legal review and when, and writes an audit row in the
 * same transaction. The global kill switch (`COMPETITOR_PRICE_COLLECTION`)
 * still overrides it — the response says whether collection is actually live.
 *
 * See docs/operations/competitor-price-collection.md.
 */
export const competitorPricesRouter = Router();
competitorPricesRouter.use(requireAuth, requireRole('admin'));

function issues(error: z.ZodError) {
  return error.issues.map((i) => `${i.path.join('.') || '<root>'}: ${i.message}`);
}

competitorPricesRouter.get('/settings', async (req: AuthedRequest, res) => {
  res.status(200).json(await getCollectionSettings(req.user!.clientId));
});

const enableBody = z
  .object({
    approvedBy: z.string().trim().min(2).max(200),
    approvedAt: z
      .string()
      .datetime({ offset: true })
      .or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
    note: z.string().trim().max(1000).optional(),
  })
  .strict();

competitorPricesRouter.post('/settings/enable', async (req: AuthedRequest, res) => {
  const parsed = enableBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({
      error: 'approvedBy and approvedAt are both required to enable competitor price collection',
      issues: issues(parsed.error),
    });
    return;
  }
  const approvedAt = new Date(parsed.data.approvedAt);
  if (Number.isNaN(approvedAt.getTime()) || approvedAt.getTime() > Date.now() + 5 * 60_000) {
    res.status(400).json({ error: 'approvedAt must be a real date that is not in the future' });
    return;
  }
  const settings = await enableCollection({
    clientId: req.user!.clientId,
    userId: req.user!.userId,
    approvedBy: parsed.data.approvedBy,
    approvedAt,
    note: parsed.data.note,
  });
  res.status(200).json(settings);
});

competitorPricesRouter.post('/settings/disable', async (req: AuthedRequest, res) => {
  const parsed = z.object({ note: z.string().trim().max(1000).optional() }).strict().safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: 'Invalid request', issues: issues(parsed.error) });
    return;
  }
  res.status(200).json(
    await disableCollection({ clientId: req.user!.clientId, userId: req.user!.userId, note: parsed.data.note }),
  );
});

competitorPricesRouter.get('/audit', async (req: AuthedRequest, res) => {
  res.status(200).json({ items: await listCollectionAudit(req.user!.clientId) });
});

competitorPricesRouter.get('/retailers', (_req, res) => {
  res.status(200).json({
    items: RETAILER_ADAPTERS.filter((a) => !a.fixtureOnly).map((a) => ({
      id: a.id,
      displayName: a.displayName,
      status: a.status,
      baseUrl: a.baseUrl,
      officialFeed: a.officialFeed?.description ?? null,
    })),
  });
});

// The fixture-only example is not mappable through the API: it points at a
// reserved domain and exists for the test suite.
const retailerIds = RETAILER_ADAPTERS.filter((a) => !a.fixtureOnly).map((a) => a.id) as [string, ...string[]];

const createBody = z
  .object({
    competitorSku: z.string().trim().min(1).max(120),
    competitorBrand: z.string().trim().max(120).nullish(),
    retailer: z.enum(retailerIds),
    productUrl: z.string().trim().min(1).max(2000),
    packSize: z.string().trim().max(40).nullish(),
    ourSkuId: z.string().min(1).nullish(),
  })
  .strict();

competitorPricesRouter.get('/mappings', async (req: AuthedRequest, res) => {
  const includeInactive = req.query.includeInactive === 'true';
  res.status(200).json({ items: await listMappings(req.user!.clientId, { includeInactive }) });
});

competitorPricesRouter.post('/mappings', async (req: AuthedRequest, res) => {
  const parsed = createBody.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ error: 'Invalid request', issues: issues(parsed.error) });
    return;
  }
  res.status(201).json(await createMapping(req.user!.clientId, req.user!.userId, parsed.data));
});

const updateBody = z
  .object({
    competitorSku: z.string().trim().min(1).max(120).optional(),
    competitorBrand: z.string().trim().max(120).nullish(),
    packSize: z.string().trim().max(40).nullish(),
    ourSkuId: z.string().min(1).nullable().optional(),
    active: z.boolean().optional(),
  })
  .strict();

competitorPricesRouter.patch('/mappings/:id', async (req: AuthedRequest, res) => {
  const parsed = updateBody.safeParse(req.body ?? {});
  if (!parsed.success || Object.keys(parsed.data).length === 0) {
    res.status(400).json({
      error: 'Invalid request',
      issues: parsed.success ? ['<root>: nothing to change'] : issues(parsed.error),
    });
    return;
  }
  res.status(200).json(await updateMapping(req.user!.clientId, String(req.params.id), parsed.data));
});
