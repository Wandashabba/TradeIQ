import { Router } from 'express';
import { AuthedRequest, requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/roleGuard';
import { listStockForVisit, recordStock, StockItemInput } from './stock.service';

export const stockRouter = Router();
stockRouter.use(requireAuth);

const REQUIRED_NUMERIC: Array<keyof StockItemInput> = [
  'unitsAvailable',
  'daysOutOfStock',
  'velocityAvg',
  'salesActual',
  'salesTarget',
];

function isValidItem(item: unknown): item is StockItemInput {
  if (typeof item !== 'object' || item === null) return false;
  const i = item as Record<string, unknown>;
  if (typeof i.skuId !== 'string' || typeof i.lastStockinDate !== 'string') return false;
  return REQUIRED_NUMERIC.every((k) => typeof i[k] === 'number');
}

stockRouter.post('/', requireRole('field_agent'), async (req: AuthedRequest, res) => {
  const { visitId, items } = req.body as { visitId?: string; items?: unknown[] };

  if (!visitId || !Array.isArray(items) || items.length === 0 || !items.every(isValidItem)) {
    res.status(400).json({ error: 'visitId and a non-empty items[] with all required fields are required' });
    return;
  }

  const rows = await recordStock({ visitId, clientId: req.user!.clientId, items });
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
