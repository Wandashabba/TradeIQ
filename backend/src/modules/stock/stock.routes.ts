import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import {
  DUPLICATE_SKU_ID_MESSAGE,
  hasDuplicateSkuIds,
  listStockForVisit,
  recordStock,
  StockItemInput,
} from './stock.service';

export const stockRouter = Router();
stockRouter.use(requireAuth);

function isValidItem(item: unknown): item is StockItemInput {
  if (typeof item !== 'object' || item === null) return false;
  const i = item as Record<string, unknown>;
  if (typeof i.skuId !== 'string' || typeof i.lastStockinDate !== 'string') return false;
  if (typeof i.unitsAvailable !== 'number') return false;
  if (i.salesActual !== undefined && i.salesActual !== null && typeof i.salesActual !== 'number') return false;
  if (i.salesTarget !== undefined && i.salesTarget !== null && typeof i.salesTarget !== 'number') return false;
  return true;
}

stockRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  // Fast-fail before touching the DB at all. recordStock enforces this same
  // invariant independently (via the same hasDuplicateSkuIds check) for
  // callers that bypass this route entirely — this is just a cheap,
  // immediate 400 for the common HTTP path.
  if (hasDuplicateSkuIds(items)) {
    res.status(400).json({ error: DUPLICATE_SKU_ID_MESSAGE });
    return;
  }

  const rows = await recordStock({ visitId, clientId: req.user!.clientId, agentId: req.user!.userId, items });
  res.status(201).json(rows);
});

stockRouter.get('/', async (req: AuthedRequest, res) => {
  const { visitId } = req.query;
  if (typeof visitId !== 'string') {
    res.status(400).json({ error: 'visitId query param is required' });
    return;
  }

  const rows = await listStockForVisit(visitId, req.user!.clientId);
  res.status(200).json(rows);
});
